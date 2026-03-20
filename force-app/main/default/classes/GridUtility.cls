/** ──────────────────────────────────────
 * @description Utility class for Agreement lifecycle transitions involving Grid__c.
 *              Single entry point: handles Agreement field swaps, Grid__c approval status updates,
 *              and delegates AgreementGridTimeline__c updates to AgreementGridTimelineUtility.
 * @author Charles EID
 * @testClass GridLifecycleTest
 * @coverage 100%   [19-03-26]
────────────────────────────────────── */
public with sharing class GridUtility {

    /** True while handleAgreementGridTransitions is executing — prevents GridTrigger from
     *  looping back to update the Agreement that is already in its BeforeUpdate context. */
    public static Boolean isUpdatingGridsFromAgreementTrigger = false;

    /** ──────────────────────────────────────
     * @description Single loop over agreements: classifies each into a transition bucket,
     *              performs Agreement field swaps, collects Grid__c approval updates,
     *              then delegates timeline updates to AgreementGridTimelineUtility.
     *              A) First Grid → field swap + Grid Approved
     *              B) Submitted  → Grid Pending Approval
     *              C) Approved   → field swap + Grid Approved
     *              D) Rejected   → Grid Rejected
     ────────────────────────────────────── */
    public static void handleAgreementGridTransitions(List<Convention__c> newAgreements, Map<Id, Convention__c> oldAgreements) {
        Map<Id, String>   gridApprovalUpdates         = new Map<Id, String>();
        Map<Id, Date>     requestStartDateByAgreement = new Map<Id, Date>();
        Map<Id, List<Id>> submittedAgrToGridIds       = new Map<Id, List<Id>>();
        Map<Id, List<Id>> approvedAgrToGridIds        = new Map<Id, List<Id>>();
        Map<Id, List<Id>> rejectedAgrToGridIds        = new Map<Id, List<Id>>();

        for (Convention__c agr : newAgreements) {
            Convention__c oldAgr = oldAgreements.get(agr.Id);
            String oldApprovalStatus = oldAgr.Approval_Status__c;
            String newApprovalStatus = agr.Approval_Status__c;
            String oldAmdmtStatus = oldAgr.Amendment_Approval_Status__c;
            String newAmdmtStatus = agr.Amendment_Approval_Status__c;

            // A and C: First-grid approved OR Amendment approved
            if ((agr.Grid_Request__c != null && agr.Grid__c == null && oldApprovalStatus != 'Approval Complete' && newApprovalStatus == 'Approval Complete') // A: First-grid approved — swap fields, mark grid Approved
                || (newAmdmtStatus == 'Approved' && agr.Grid_Request_Approved__c)) {                                                                         // C: Amendment approved — swap fields, mark grid Approved
                List<Id> gridIds = new List<Id>{ agr.Grid_Request__c };                 // new grid (Pending Approval → Active), captured before swap
                if (agr.Grid__c != null) gridIds.add(agr.Grid__c);                      // old grid (Active → Inactive), amendment case only, captured before swap
                approvedAgrToGridIds.put(agr.Id, gridIds);
                requestStartDateByAgreement.put(agr.Id, agr.Grid_Request_Start_Date__c); // captured before swap
                gridApprovalUpdates.put(agr.Grid_Request__c, 'Approved');                // captured before swap
                setGridOnAgreement(agr);
            }
            // B: Amendment submitted
            if ((String.isEmpty(oldAmdmtStatus) || oldAmdmtStatus == 'Need Submission') && String.isNotEmpty(newAmdmtStatus) && newAmdmtStatus != 'Need Submission' && newAmdmtStatus != 'Approval Rejected' && newAmdmtStatus != 'Approved' && agr.Grid_Request__c != null) {
                submittedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
                gridApprovalUpdates.put(agr.Grid_Request__c, 'Pending Approval');
            }
            // D: Amendment rejected
            if (newAmdmtStatus == 'Approval Rejected' && oldAmdmtStatus != 'Approval Rejected' && agr.Grid_Request__c != null) {
                rejectedAgrToGridIds.put(agr.Id, new List<Id>{ agr.Grid_Request__c });
                gridApprovalUpdates.put(agr.Grid_Request__c, 'Rejected');
            }
        }

        isUpdatingGridsFromAgreementTrigger = true;
        try {
            updateGridApprovalStatuses(gridApprovalUpdates);
        } finally {
            isUpdatingGridsFromAgreementTrigger = false;
        }
        AgreementGridTimelineUtility.updateTimelines(submittedAgrToGridIds, approvedAgrToGridIds, rejectedAgrToGridIds, requestStartDateByAgreement);
    }

    public static void updateGridApprovalStatuses(Map<Id, String> gridIdToApprovalStatus) {
        if (gridIdToApprovalStatus == null || gridIdToApprovalStatus.isEmpty()) return;
        List<Grid__c> gridsToUpdate = new List<Grid__c>();
        for (Id gridId : gridIdToApprovalStatus.keySet()) {
            gridsToUpdate.add(new Grid__c(Id = gridId, ApprovalStatus__c = gridIdToApprovalStatus.get(gridId)));
        }
        update gridsToUpdate;
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