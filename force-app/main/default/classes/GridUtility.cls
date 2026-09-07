/** ──────────────────────────────────────
 * @description Utility class for Agreement lifecycle transitions involving Grid__c.
 *              Single entry point: handles Agreement field swaps, Grid__c approval status updates,
 *              and delegates AgreementGridTimeline__c updates to AgreementGridTimelineUtility.
 * @author Charles EID
 * @testClass GridLifecycleTest
 * @coverage 100%   [19-03-26]
────────────────────────────────────── */
public with sharing class GridUtility {

    public static Boolean isUpdatingGridsFromAgreementTrigger = false; // True while handleAgreementGridTransitions is executing — prevents GridTrigger from looping back to update the Agreement that is already in its BeforeUpdate context.

    // Agreement Approval_Status__c values
    public static final String AGR_STATUS_PRE_APPROVAL       = 'Pre-Approval';
    public static final String AGR_STATUS_APPROVAL_COMPLETE  = 'Approval Complete';
    public static final String AGR_STATUS_APPROVAL_REJECTED  = 'Approval Rejected';

    // Agreement Amendment_Approval_Status__c values
    public static final String AGR_AMDMT_NEED_SUBMISSION     = 'Need Submission';
    public static final String AGR_AMDMT_APPROVAL_REQUIRED   = 'Approval Required';
    public static final String AGR_AMDMT_APPROVAL_REJECTED   = 'Approval Rejected';
    public static final String AGR_AMDMT_APPROVED            = 'Approved';

    // Grid__c ApprovalStatus__c values
    public static final String GRID_STATUS_DRAFT             = 'Draft';
    public static final String GRID_STATUS_PENDING_APPROVAL  = 'Pending Approval';
    public static final String GRID_STATUS_APPROVED          = 'Approved';
    public static final String GRID_STATUS_REJECTED          = 'Rejected';

    public static final String FIELD_EFF_MGT_FEES = 'EffectiveManagementFees__c';

    public static final Integer BATCH_SIZE_GRID_DETAIL_REFRESH = 200;
    /** ──────────────────────────────────────
     * @description Single loop over agreements: classifies each into a transition bucket,
     *              performs Agreement field swaps, collects Grid__c approval updates,
     *              then delegates timeline updates to AgreementGridTimelineUtility.
     *              A) First Grid intermediate → Grid Pending Approval
     *              B) First Grid approved     → field swap + Grid Approved
     *              C) Amendment submitted     → Grid Pending Approval
     *              D) Amendment approved      → field swap + Grid Approved
     *              E) Grid rejected (first or amendment) → Grid Rejected
     *              F) Grid recalled           → AGT → Draft
     ────────────────────────────────────── */
    public static void handleAgreementGridTransitions(List<Convention__c> newAgreements, Map<Id, Convention__c> oldAgreements) {
        Map<Id, String>   gridApprovalUpdates    = new Map<Id, String>();
        Map<Id, List<Id>> submittedAgrToGridIds  = new Map<Id, List<Id>>();
        Map<Id, List<Id>> approvedAgrToGridIds   = new Map<Id, List<Id>>();
        Map<Id, List<Id>> rejectedAgrToGridIds   = new Map<Id, List<Id>>();
        Map<Id, List<Id>> recalledAgrToGridIds   = new Map<Id, List<Id>>();
        Map<Id, List<Id>> historicalAgrToGridIds = new Map<Id, List<Id>>(); // Scenario 3: approved but predates active — new AGT → Inactive
        Map<Id, Date>     oldGridEndDates       = new Map<Id, Date>();      // old Grid EndDate set at approval for both Scenario 1 and 2
        Set<Id>           immediateOldGridIds   = new Set<Id>();             // Scenario 2: old Active AGT → Inactive immediately in updateTimelines

        Map<Id, Id>     firstGridProgressMap = new Map<Id, Id>();    // agrId → Grid_Request__c (isA — standard AP in progress)
        Map<Id, String> progressStepLabels   = new Map<Id, String>(); // agrId → Approval_Status__c (label for the pending step)
        Map<Id, Id>     firstGridFinalMap    = new Map<Id, Id>();    // agrId → Grid_Request__c (isB — standard AP approved)

        List<String> firstGridTerminalStatuses  = new List<String>{AGR_STATUS_PRE_APPROVAL, AGR_STATUS_APPROVAL_COMPLETE, AGR_STATUS_APPROVAL_REJECTED}; // A: excluded from "intermediate"
        List<String> amendmentNonSubmitStatuses = new List<String>{AGR_AMDMT_NEED_SUBMISSION, AGR_AMDMT_APPROVAL_REJECTED, AGR_AMDMT_APPROVED};          // C: excluded from "submitted"

        Set<Id> allAgreementIds = new Set<Id>();
        for (Convention__c agr : newAgreements) allAgreementIds.add(agr.Id);

        Map<Id, Date> activeAgtStartByAgreement  = new Map<Id, Date>();
        Map<Id, Date> requestAgtStartByAgreement = new Map<Id, Date>();
        for (AgreementGridTimeline__c agt : [SELECT Agreement__c, Status__c, GridStartDate__c
                                             FROM AgreementGridTimeline__c
                                             WHERE Agreement__c IN :allAgreementIds
                                             AND Status__c IN (:AgreementGridTimelineUtility.AGT_ACTIVE, :AgreementGridTimelineUtility.AGT_PENDINGAPPROVAL, :AgreementGridTimelineUtility.AGT_DRAFT)]) {
            if (agt.Status__c == AgreementGridTimelineUtility.AGT_ACTIVE) {
                activeAgtStartByAgreement.put(agt.Agreement__c, agt.GridStartDate__c);
            } else {
                requestAgtStartByAgreement.put(agt.Agreement__c, agt.GridStartDate__c);
            }
        }

        String oldStatus, newStatus, oldAmdmt, newAmdmt;
        Boolean isFirstGrid, isA, isB, isC, isD, isE, isF;

        for (Convention__c agr : newAgreements) {
            Convention__c oldAgr = oldAgreements.get(agr.Id);
            oldStatus = oldAgr.Approval_Status__c;
            newStatus = agr.Approval_Status__c;
            oldAmdmt  = oldAgr.Amendment_Approval_Status__c;
            newAmdmt  = agr.Amendment_Approval_Status__c;

            // Classify the transition (conditions only — actions below)
            isFirstGrid = (agr.Grid__c == null && agr.Grid_Request__c != null);
            isA = isFirstGrid  && oldStatus != newStatus && String.isNotBlank(newStatus) && !firstGridTerminalStatuses.contains(newStatus);                                 // A: First-grid intermediate
            isB = isFirstGrid  && oldStatus != AGR_STATUS_APPROVAL_COMPLETE && newStatus == AGR_STATUS_APPROVAL_COMPLETE;                                                   // B: First-grid approved
            isC = !isFirstGrid && oldAmdmt  != newAmdmt  && String.isNotEmpty(newAmdmt)  && !amendmentNonSubmitStatuses.contains(newAmdmt) && agr.Grid_Request__c != null;  // C: Amendment submitted
            isD = !isFirstGrid && newAmdmt  == AGR_AMDMT_APPROVED && agr.Grid_Request_Approved__c && !oldAgr.Grid_Request_Approved__c;                                      // D: Amendment approved (transition false → true only)
            isE = newAmdmt  == AGR_AMDMT_APPROVAL_REJECTED && oldAmdmt != AGR_AMDMT_APPROVAL_REJECTED && agr.Grid_Request__c != null;                                       // E: Grid rejected (first or amendment)
            isF = !isFirstGrid && oldAmdmt == AGR_AMDMT_APPROVAL_REQUIRED && newAmdmt == AGR_AMDMT_NEED_SUBMISSION && agr.Grid_Request__c != null;                        // F: Grid recalled

            // Pending Approval (A or C) — grid + AGT → Pending Approval
            if (isA || isC) {
                submittedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
                gridApprovalUpdates.put(agr.Grid_Request__c, GRID_STATUS_PENDING_APPROVAL);
            }
            if (isA) {
                firstGridProgressMap.put(agr.Id, agr.Grid_Request__c);
                progressStepLabels.put(agr.Id, agr.Approval_Status__c);
            }
            // Approved (B or D) — three scenarios based on chronology and start date
            if (isB) firstGridFinalMap.put(agr.Id, agr.Grid_Request__c);
            if (isB || isD) {
                handleApprovalTransition(agr, activeAgtStartByAgreement, requestAgtStartByAgreement, gridApprovalUpdates, approvedAgrToGridIds, historicalAgrToGridIds, oldGridEndDates, immediateOldGridIds);
            }
            // Rejected (E) — grid + AGT → Rejected
            if (isE) {
                rejectedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
                gridApprovalUpdates.put(agr.Grid_Request__c, GRID_STATUS_REJECTED);
            }
            // Recalled (F) — AGT → Draft (Grid is already Draft from the recall action)
            if (isF) {
                recalledAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
            }
        }

        updateGrids(gridApprovalUpdates, oldGridEndDates);
        AgreementGridTimelineUtility.updateTimelines(submittedAgrToGridIds, approvedAgrToGridIds, rejectedAgrToGridIds, recalledAgrToGridIds, historicalAgrToGridIds, immediateOldGridIds);
        if (!firstGridProgressMap.isEmpty() || !firstGridFinalMap.isEmpty()) {
            System.enqueueJob(new GridStandardApprovalMirrorQueueable(firstGridProgressMap, progressStepLabels, firstGridFinalMap));
        }
    }

    private static void handleApprovalTransition(Convention__c agr,
        Map<Id, Date> activeAgtStartByAgreement, Map<Id, Date> requestAgtStartByAgreement,
        Map<Id, String> gridApprovalUpdates, Map<Id, List<Id>> approvedAgrToGridIds,
        Map<Id, List<Id>> historicalAgrToGridIds, Map<Id, Date> oldGridEndDates, Set<Id> immediateOldGridIds) {

        Date activeAgtStart  = activeAgtStartByAgreement.get(agr.Id);
        Date requestAgtStart = requestAgtStartByAgreement.get(agr.Id);
        Boolean isChronologicallyValid = activeAgtStart == null || requestAgtStart == null || requestAgtStart > activeAgtStart;
        Boolean isImmediate            = requestAgtStart == null || requestAgtStart <= Date.today();

        gridApprovalUpdates.put(agr.Grid_Request__c, GRID_STATUS_APPROVED);

        if (isChronologicallyValid) {
            approvedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
            if (agr.Grid__c != null) {
                Date endDate = requestAgtStart != null ? requestAgtStart.addDays(-1) : Date.today().addDays(-1);
                oldGridEndDates.put(agr.Grid__c, endDate);
                if (isImmediate) immediateOldGridIds.add(agr.Grid__c); // Scenario 2: updateTimelines sets old Active AGT → Inactive
            }
            if (isImmediate) {
                setGridOnAgreement(agr); // Scenario 2: swap Agreement fields immediately; new AGT → Active
            }
            // else Scenario 1: start > today — Agreement keeps Grid_Request__c; new AGT → Approved; batch activates later
        } else {
            // Scenario 3: approved Grid predates active AGT — new AGT → Inactive; no Agreement or old Grid change
            historicalAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
        }
    }

    private static void updateGrids(Map<Id, String> approvalUpdates, Map<Id, Date> endDateUpdates) {
        Map<Id, Grid__c> gridsById = new Map<Id, Grid__c>();
        for (Id gridId : approvalUpdates.keySet()) {
            gridsById.put(gridId, new Grid__c(Id = gridId, ApprovalStatus__c = approvalUpdates.get(gridId)));
        }
        for (Id gridId : endDateUpdates.keySet()) {
            if (!gridsById.containsKey(gridId)) gridsById.put(gridId, new Grid__c(Id = gridId));
            gridsById.get(gridId).EndDate__c = endDateUpdates.get(gridId);
        }
        if (gridsById.isEmpty()) return;
        isUpdatingGridsFromAgreementTrigger = true;
        try {
            update gridsById.values();
        } finally {
            isUpdatingGridsFromAgreementTrigger = false;
        }
    }

    public static Date effectiveStart(Date gridStart, Date scCreated) {
        if (gridStart == null) return scCreated;
        if (scCreated == null) return gridStart;
        return gridStart > scCreated ? gridStart : scCreated;
    }

    /** ──────────────────────────────────────
     * @description When a ShareClass EffectiveManagementFees__c changes, expire all active Standard Grid Details for those share classes and insert updated clones
     *              (clone-and-expire pattern). Then do the same for any Custom Grid Details that point to the expired Standard Grid Details.
     *
     *              Standard Grid Details: rebate rate recalculated via GridDetailBuilder.
     *              Custom Grid Details: rate and share class copied from the new Standard Grid Detail by GridDetailTriggerHandler on insert.
     *              EffectiveManagementFees__c on all new details is auto-populated by the GridDetailTriggerHandler.BeforeInsert via populateEffectiveMgtFees().
     ────────────────────────────────────── */
    public static void refreshGridDetailsForShareClasses(Set<Id> changedShareClassIds) {
        if (changedShareClassIds == null || changedShareClassIds.isEmpty()) return;

        // ── Step 1: Standard Grid Details ────────────────────────────────────────────────
        List<GridDetail__c> currentStdDetails = [SELECT Id, Grid__c, GridRule__c, GridCriteria__c, ShareClass__c, RebateRate__c, StartDate__c, RecordTypeId
                                                 FROM GridDetail__c
                                                 WHERE ShareClass__c IN :changedShareClassIds
                                                 AND Grid__r.RecordType.DeveloperName = 'StandardGrid'
                                                 AND TECH_EffMgtFeesAuditHistory__c = null];
        if (currentStdDetails.isEmpty()) return;

        Set<Id> gridIds = new Set<Id>();
        for (GridDetail__c d : currentStdDetails) { gridIds.add(d.Grid__c); }

        Map<String, Decimal> newRates = GridDetailBuilder.computeRebatesForGrids(gridIds);

        List<GridDetail__c> oldStdToUpdate   = new List<GridDetail__c>();
        List<GridDetail__c> newStdToInsert   = new List<GridDetail__c>();
        List<Id> oldStdDetailIds  = new List<Id>(); // parallel to newStdToInsert

        Date today = Date.today();
        for (GridDetail__c old : currentStdDetails) {
            String key    = String.valueOf(old.Grid__c) + ':' + String.valueOf(old.ShareClass__c);
            Decimal rate  = newRates.containsKey(key) ? newRates.get(key) : 0;

            old.EndDate__c = today.addDays(-1);
            oldStdToUpdate.add(old);

            GridDetail__c clone      = new GridDetail__c();
            clone.RecordTypeId       = old.RecordTypeId;
            clone.Grid__c            = old.Grid__c;
            clone.GridRule__c        = old.GridRule__c;
            clone.GridCriteria__c    = old.GridCriteria__c;
            clone.ShareClass__c      = old.ShareClass__c;
            clone.RebateRate__c      = rate;
            clone.StartDate__c       = today;
            newStdToInsert.add(clone);
            oldStdDetailIds.add(old.Id);
        }

        update oldStdToUpdate;
        insert newStdToInsert;

        // Build old → new standard detail Id map for the custom grid step
        Map<Id, Id> oldStdDetailIdToNewStdDetailId = new Map<Id, Id>();
        for (Integer i = 0; i < oldStdDetailIds.size(); i++) {
            oldStdDetailIdToNewStdDetailId.put(oldStdDetailIds[i], newStdToInsert[i].Id);
        }

        // ── Step 2: Custom Grid Details ───────────────────────────────────────────────────
        if (oldStdDetailIdToNewStdDetailId.isEmpty()) return;

        List<GridDetail__c> currentCustomDetails = [SELECT Id, Grid__c, GridCriteria__c, StandardGridDetail__c, StartDate__c, RecordTypeId
                                                    FROM GridDetail__c
                                                    WHERE StandardGridDetail__c IN :oldStdDetailIdToNewStdDetailId.keySet()
                                                    AND StandardGridDetail__r.TECH_EffMgtFeesAuditHistory__c = null];
        if (currentCustomDetails.isEmpty()) return;

        List<GridDetail__c> oldCustomToUpdate = new List<GridDetail__c>();
        List<GridDetail__c> newCustomToInsert = new List<GridDetail__c>();

        for (GridDetail__c old : currentCustomDetails) {
            Id newStdDetailId = oldStdDetailIdToNewStdDetailId.get(old.StandardGridDetail__c);

            old.EndDate__c = today.addDays(-1);
            oldCustomToUpdate.add(old);

            GridDetail__c clone         = new GridDetail__c();
            clone.RecordTypeId          = old.RecordTypeId;
            clone.Grid__c               = old.Grid__c;
            clone.GridCriteria__c       = old.GridCriteria__c;
            clone.StandardGridDetail__c = newStdDetailId;
            clone.StartDate__c          = today;
            newCustomToInsert.add(clone);
        }

        update oldCustomToUpdate;
        insert newCustomToInsert;
    }

    /** ──────────────────────────────────────
     * @description Called from AgreementTriggerHandler on AfterUpdate.
     *              Queries all CustomGrid records linked to the updated agreements
     *              and mirrors TECH_Business_Region__c → TECH_BusinessRegion__c
     *              and TECH_All_concerned_Business_Regions__c → TECH_AllConcernedBusinessRegions__c.
     ────────────────────────────────────── */
    public static void syncInformationFromAgreements(Map<Id, Convention__c> newAgreements, Map<Id, Convention__c> oldAgreements) {
        Set<Id> changedAgreementIds = new Set<Id>();
        for (Convention__c agr : newAgreements.values()) {
            Convention__c oldAgr = oldAgreements.get(agr.Id);
            if (agr.TECH_Business_Region__c != oldAgr.TECH_Business_Region__c || agr.TECH_All_concerned_Business_Regions__c != oldAgr.TECH_All_concerned_Business_Regions__c || agr.Carmignac_Legal_Entity__c != oldAgr.Carmignac_Legal_Entity__c) {
                changedAgreementIds.add(agr.Id);
            }
        }
        if (changedAgreementIds.isEmpty()) return;

        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();

        List<Grid__c> toUpdate = new List<Grid__c>();
        for (Grid__c grid : [SELECT Id, Agreement__c
                             FROM Grid__c
                             WHERE Agreement__c IN :changedAgreementIds
                             AND RecordTypeId = :customGridRtId]) {
            Convention__c agr = newAgreements.get(grid.Agreement__c);
            toUpdate.add(new Grid__c(Id = grid.Id, TECH_BusinessRegion__c = agr.TECH_Business_Region__c, TECH_AllConcernedBusinessRegions__c = agr.TECH_All_concerned_Business_Regions__c, TECH_CarmignacLegalEntity__c = agr.Carmignac_Legal_Entity__c));
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public static String getGridAgreementRegion(Id gridId) {
        if (gridId == null) return null;
        List<Grid__c> grids = [SELECT Agreement__r.Business_Region__c FROM Grid__c WHERE Id = :gridId LIMIT 1];
        return grids.isEmpty() ? null : grids[0].Agreement__r.Business_Region__c;
    }

    public static void setGridOnAgreement(Convention__c agr) {
        agr.Grid__c                      = agr.Grid_Request__c;
        agr.Grid_Request__c              = null;
        agr.Grid_Start_Date__c           = agr.Grid_Request_Start_Date__c;
        agr.Grid_Request_Start_Date__c   = null;
        agr.Amendment_Approval_Status__c = '';
        agr.Grid_Request_Approved__c     = false;
    }

    // ── When a Custom Grid's EndDate__c changes, mirror it onto all active custom grid details (non-historical ones) ──
    public static void syncGridEndDateToDetails(List<Grid__c> newGrids, Map<Id, Grid__c> oldGrids) {
        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();

        Map<Id, Date> gridEndDateById = new Map<Id, Date>();
        for (Grid__c g : newGrids) {
            if (g.RecordTypeId != customGridRtId) continue;
            if (g.EndDate__c == oldGrids.get(g.Id).EndDate__c) continue;
            gridEndDateById.put(g.Id, g.EndDate__c);
        }
        if (gridEndDateById.isEmpty()) return;

        List<GridDetail__c> toUpdate = new List<GridDetail__c>();
        for (GridDetail__c gd : [SELECT Id, Grid__c
                                  FROM GridDetail__c
                                  WHERE Grid__c IN :gridEndDateById.keySet()
                                  AND StandardGridDetail__r.TECH_EffMgtFeesAuditHistory__c = null]) {
            toUpdate.add(new GridDetail__c(Id = gd.Id, EndDate__c = gridEndDateById.get(gd.Grid__c)));
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ── Recomputes SelectedStandardGrids__c: comma-separated names of the standard grids referenced by each grid's criteria ──
    public static void updateSelectedStandardGrids(List<Id> gridIds) {
        if (gridIds == null || gridIds.isEmpty()) return;

        List<Grid__c> gridsToUpdate = new List<Grid__c>();
        for (Grid__c grid : [SELECT Id, SelectedStandardGrids__c,
                                (SELECT StandardGrid__r.Name, StandardGrid__r.Tech_SpecificStandardGrid__c 
                                FROM GridCriteria__r 
                                WHERE StandardGrid__c != null 
                                ORDER BY StandardGrid__r.Tech_SpecificStandardGrid__c ASC, StandardGrid__r.Name ASC)
                             FROM Grid__c
                             WHERE Id IN :gridIds]) {
            List<String> names = new List<String>();
            Set<String> seenNames = new Set<String>();
            for (GridCriteria__c gc : grid.GridCriteria__r) {
                if (String.isNotBlank(gc.StandardGrid__r.Name) && seenNames.add(gc.StandardGrid__r.Name)) {
                    names.add(gc.StandardGrid__r.Name);
                }
            }

            String selectedStandardGrids = names.isEmpty() ? null : String.join(names, ', ').abbreviate(255);
            if (selectedStandardGrids != grid.SelectedStandardGrids__c) {
                gridsToUpdate.add(new Grid__c(Id = grid.Id, SelectedStandardGrids__c = selectedStandardGrids));
            }
        }

        if (!gridsToUpdate.isEmpty()) update gridsToUpdate;
    }
}