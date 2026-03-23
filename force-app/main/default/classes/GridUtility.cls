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

    private static void setGridOnAgreement(Convention__c agr) {
        agr.Grid__c                      = agr.Grid_Request__c;
        agr.Grid_Request__c              = null;
        agr.Grid_Start_Date__c           = agr.Grid_Request_Start_Date__c;
        agr.Grid_Request_Start_Date__c   = null;
        agr.Amendment_Approval_Status__c = '';
        agr.Grid_Request_Approved__c     = false;
    }
}