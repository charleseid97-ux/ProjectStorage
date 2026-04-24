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
    public static final String GRID_STATUS_PENDING_APPROVAL  = 'Pending Approval';
    public static final String GRID_STATUS_APPROVED          = 'Approved';
    public static final String GRID_STATUS_REJECTED          = 'Rejected';

    public static final String FIELD_EFF_MGT_FEES = 'EffectiveManagementFees__c';
    private static final String RULE_PERCENTAGE_LABEL = 'Percentage of Fees';

    /** ──────────────────────────────────────
     * @description Single loop over agreements: classifies each into a transition bucket,
     *              performs Agreement field swaps, collects Grid__c approval updates,
     *              then delegates timeline updates to AgreementGridTimelineUtility.
     *              A) First Grid intermediate → Grid Pending Approval
     *              B) First Grid approved     → field swap + Grid Approved
     *              C) Amendment submitted     → Grid Pending Approval
     *              D) Amendment approved      → field swap + Grid Approved
     *              E) Amendment rejected      → Grid Rejected
     ────────────────────────────────────── */
    public static void handleAgreementGridTransitions(List<Convention__c> newAgreements, Map<Id, Convention__c> oldAgreements) {
        Map<Id, String>   gridApprovalUpdates         = new Map<Id, String>();
        Map<Id, Date>     requestStartDateByAgreement = new Map<Id, Date>();
        Map<Id, List<Id>> submittedAgrToGridIds       = new Map<Id, List<Id>>();
        Map<Id, List<Id>> approvedAgrToGridIds        = new Map<Id, List<Id>>();
        Map<Id, List<Id>> rejectedAgrToGridIds        = new Map<Id, List<Id>>();

        List<String> firstGridTerminalStatuses  = new List<String>{AGR_STATUS_PRE_APPROVAL, AGR_STATUS_APPROVAL_COMPLETE, AGR_STATUS_APPROVAL_REJECTED}; // A: excluded from "intermediate"
        List<String> amendmentNonSubmitStatuses = new List<String>{AGR_AMDMT_NEED_SUBMISSION, AGR_AMDMT_APPROVAL_REJECTED, AGR_AMDMT_APPROVED};          // C: excluded from "submitted"

        String oldStatus, newStatus, oldAmdmt, newAmdmt;
        Boolean isFirstGrid, isA, isB, isC, isD, isE;

        for (Convention__c agr : newAgreements) {
            Convention__c oldAgr = oldAgreements.get(agr.Id);
            oldStatus = oldAgr.Approval_Status__c;
            newStatus = agr.Approval_Status__c;
            oldAmdmt  = oldAgr.Amendment_Approval_Status__c;
            newAmdmt  = agr.Amendment_Approval_Status__c;

            // Classify the transition (conditions only — actions below)
            isFirstGrid = (agr.Grid__c == null && agr.Grid_Request__c != null);
            isA = isFirstGrid  && oldStatus != newStatus && String.isNotBlank(newStatus) && !firstGridTerminalStatuses.contains(newStatus);                                                   // A: First-grid intermediate
            isB = isFirstGrid  && oldStatus != AGR_STATUS_APPROVAL_COMPLETE && newStatus == AGR_STATUS_APPROVAL_COMPLETE;                                                                     // B: First-grid approved
            isC = !isFirstGrid && oldAmdmt  != newAmdmt  && String.isNotEmpty(newAmdmt)  && !amendmentNonSubmitStatuses.contains(newAmdmt) && agr.Grid_Request__c != null;                   // C: Amendment submitted
            isD = !isFirstGrid && newAmdmt  == AGR_AMDMT_APPROVED && agr.Grid_Request_Approved__c;                                                                                           // D: Amendment approved
            isE = !isFirstGrid && newAmdmt  == AGR_AMDMT_APPROVAL_REJECTED && oldAmdmt != AGR_AMDMT_APPROVAL_REJECTED && agr.Grid_Request__c != null;                                       // E: Amendment rejected

            // Pending Approval (A or C) — grid + AGT → Pending Approval
            if (isA || isC) {
                submittedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
                gridApprovalUpdates.put(agr.Grid_Request__c, GRID_STATUS_PENDING_APPROVAL);
            }
            // Approved (B or D) — swap Agreement fields, grid + AGT → Approved / Active
            if (isB || isD) {
                List<Id> gridIds = new List<Id>{ agr.Grid_Request__c }; // new grid, captured before swap
                if (agr.Grid__c != null) gridIds.add(agr.Grid__c);      // old grid (amendment only), captured before swap
                approvedAgrToGridIds.put(agr.Id, gridIds);
                requestStartDateByAgreement.put(agr.Id, agr.Grid_Request_Start_Date__c); // captured before swap
                gridApprovalUpdates.put(agr.Grid_Request__c, GRID_STATUS_APPROVED);      // captured before swap
                setGridOnAgreement(agr);
            }
            // Rejected (E) — grid + AGT → Rejected
            if (isE) {
                rejectedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
                gridApprovalUpdates.put(agr.Grid_Request__c, GRID_STATUS_REJECTED);
            }
        }

        updateGridApprovalStatuses(gridApprovalUpdates);
        AgreementGridTimelineUtility.updateTimelines(submittedAgrToGridIds, approvedAgrToGridIds, rejectedAgrToGridIds, requestStartDateByAgreement);
    }

    public static void updateGridApprovalStatuses(Map<Id, String> gridIdToApprovalStatus) {
        if (gridIdToApprovalStatus == null || gridIdToApprovalStatus.isEmpty()) return;
        List<Grid__c> gridsToUpdate = new List<Grid__c>();
        for (Id gridId : gridIdToApprovalStatus.keySet()) {
            gridsToUpdate.add(new Grid__c(Id = gridId, ApprovalStatus__c = gridIdToApprovalStatus.get(gridId)));
        }
        isUpdatingGridsFromAgreementTrigger = true;
        try {
            update gridsToUpdate;
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
     * @description Builds historical GridDetail__c records (past EffMgtFees periods) for the given base details.
     *              Queries ALL Fund_Field_ApplicabilityHistory__c periods per share class, validates continuity,
     *              then creates one closed-period record per valid historical window that overlaps the grid's lifetime.
     *              The active (End_Date = null) period is skipped — the base detail covers it.
     *              Pre-sets EffectiveManagementFees__c so the BeforeInsert trigger does not overwrite it.
     *
     * @param baseDetails       Already-inserted/upserted base GridDetail__c records (one per share class / current period).
     * @param gridStartDateMap  Grid__c.StartDate__c by Grid Id.
     * @param scCreatedDateMap  Share_Class__c.CreatedDate (as Date) by Share Class Id.
     * @param gridRuleById      GridRule__c by Id for RULE_PERCENTAGE rebate recalculation. Pass null for custom details.
     * @param errors            Accumulated error strings — continuity violations are appended here.
     ────────────────────────────────────── */
    public static List<GridDetail__c> buildHistoricalDetailsFromFieldHistory(List<GridDetail__c> baseDetails, Map<Id, Date> gridStartDateMap, Map<Id, Date> scCreatedDateMap, Map<Id, GridRule__c> gridRuleById, List<String> errors) {
        Set<Id> shareClassIds = new Set<Id>();
        for (GridDetail__c d : baseDetails) {
            if (d.ShareClass__c != null) shareClassIds.add(d.ShareClass__c);
        }
        if (shareClassIds.isEmpty()) return new List<GridDetail__c>();

        Map<Id, List<Fund_Field_ApplicabilityHistory__c>> allHistByShareClass = new Map<Id, List<Fund_Field_ApplicabilityHistory__c>>();
        for (Fund_Field_ApplicabilityHistory__c h : [SELECT Share_Class_Reference__c, Start_Date__c, End_Date__c, New_Value__c
                                                     FROM Fund_Field_ApplicabilityHistory__c
                                                     WHERE Share_Class_Reference__c IN :shareClassIds
                                                     AND FieldAPIName__c = :FIELD_EFF_MGT_FEES
                                                     ORDER BY Share_Class_Reference__c, Start_Date__c ASC]) {
            if (!allHistByShareClass.containsKey(h.Share_Class_Reference__c)) {
                allHistByShareClass.put(h.Share_Class_Reference__c, new List<Fund_Field_ApplicabilityHistory__c>());
            }
            allHistByShareClass.get(h.Share_Class_Reference__c).add(h);
        }
        if (allHistByShareClass.isEmpty()) return new List<GridDetail__c>();

        Set<Id> validShareClassIds = new Set<Id>();
        for (Id scId : allHistByShareClass.keySet()) {
            String err = validateHistoryContinuity(allHistByShareClass.get(scId));
            if (err != null) {
                errors.add('Share class ' + scId + ' has discontinuous EffMgtFees history: ' + err);
            } else {
                validShareClassIds.add(scId);
            }
        }
        if (validShareClassIds.isEmpty()) return new List<GridDetail__c>();

        List<GridDetail__c> historicalDetails = new List<GridDetail__c>();
        for (GridDetail__c base : baseDetails) {
            if (base.ShareClass__c == null || !validShareClassIds.contains(base.ShareClass__c)) continue;
            List<Fund_Field_ApplicabilityHistory__c> allPeriods = allHistByShareClass.get(base.ShareClass__c);

            Date gridStart = gridStartDateMap?.get(base.Grid__c);
            Date scCreated = scCreatedDateMap?.get(base.ShareClass__c);
            Date effGridStart = effectiveStart(gridStart, scCreated);

            GridRule__c rule = (gridRuleById != null && base.GridRule__c != null) ? gridRuleById.get(base.GridRule__c) : null;

            for (Fund_Field_ApplicabilityHistory__c hist : allPeriods) {
                if (hist.End_Date__c == null) continue;
                if (effGridStart != null && hist.End_Date__c < effGridStart) continue;

                Decimal histEffMgtFees = String.isNotBlank(hist.New_Value__c) ? Decimal.valueOf(hist.New_Value__c) : null;

                Decimal historicalRebate = base.RebateRate__c;
                if (rule != null && rule.RuleToApply__c == RULE_PERCENTAGE_LABEL && histEffMgtFees != null && rule.GridRate__c != null) {
                    historicalRebate = (histEffMgtFees * rule.GridRate__c / 100).setScale(2, System.RoundingMode.HALF_UP);
                }

                Date detailStart = (effGridStart != null && hist.Start_Date__c < effGridStart) ? effGridStart : hist.Start_Date__c;

                GridDetail__c clone = new GridDetail__c();
                clone.RecordTypeId                    = base.RecordTypeId;
                clone.Grid__c                         = base.Grid__c;
                clone.GridRule__c                     = base.GridRule__c;
                clone.GridCriteria__c                 = base.GridCriteria__c;
                clone.ShareClass__c                   = base.ShareClass__c;
                clone.StandardGridDetail__c           = base.StandardGridDetail__c;
                clone.RebateRate__c                   = historicalRebate;
                clone.EffectiveManagementFees__c      = histEffMgtFees;
                clone.StartDate__c                    = detailStart;
                clone.EndDate__c                      = hist.End_Date__c;
                clone.TECH_EffMgtFeesAuditHistory__c  = hist.Id;
                historicalDetails.add(clone);
            }
        }
        return historicalDetails;
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
                                                 AND (EndDate__c = null OR EndDate__c >= :Date.today())];
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
                                                    AND (EndDate__c = null OR EndDate__c >= :Date.today())];
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

    private static void setGridOnAgreement(Convention__c agr) {
        agr.Grid__c                      = agr.Grid_Request__c;
        agr.Grid_Request__c              = null;
        agr.Grid_Start_Date__c           = agr.Grid_Request_Start_Date__c;
        agr.Grid_Request_Start_Date__c   = null;
        agr.Amendment_Approval_Status__c = '';
        agr.Grid_Request_Approved__c     = false;
    }
    
    /** ──────────────────────────────────────
     * @description Validates that a list of Fund_Field_ApplicabilityHistory__c records (sorted ASC by Start_Date__c)
     *              forms a continuous, non-overlapping sequence ending with exactly one active record (End_Date__c = null).
     * @return Error message string, or null if the sequence is valid.
     ────────────────────────────────────── */
    private static String validateHistoryContinuity(List<Fund_Field_ApplicabilityHistory__c> allPeriods) {
        Integer nullEndCount = 0;
        for (Fund_Field_ApplicabilityHistory__c h : allPeriods) {
            if (h.End_Date__c == null) nullEndCount++;
        }
        if (nullEndCount != 1) {
            return 'Expected exactly 1 active (End_Date = null) record, found ' + nullEndCount + '.';
        }
        Fund_Field_ApplicabilityHistory__c last = allPeriods[allPeriods.size() - 1];
        if (last.End_Date__c != null) {
            return 'The last period must be the active one (End_Date = null).';
        }
        for (Integer i = 0; i < allPeriods.size() - 1; i++) {
            Fund_Field_ApplicabilityHistory__c curr = allPeriods[i];
            Fund_Field_ApplicabilityHistory__c next = allPeriods[i + 1];
            if (curr.End_Date__c == null) {
                return 'An active (End_Date = null) record was found before the last position (index ' + i + ').';
            }
            if (curr.Start_Date__c > curr.End_Date__c) {
                return 'Invalid period at index ' + i + ': Start_Date (' + curr.Start_Date__c + ') is after End_Date (' + curr.End_Date__c + ').';
            }
            Date expectedNextStart = curr.End_Date__c.addDays(1);
            if (next.Start_Date__c != expectedNextStart) {
                return 'Gap or overlap detected: period ending ' + curr.End_Date__c +
                       ' is followed by a period starting ' + next.Start_Date__c +
                       ' (expected ' + expectedNextStart + ').';
            }
        }
        return null;
    }
}