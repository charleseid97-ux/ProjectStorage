/** ──────────────────────────────────────
 * @description Trigger handler for Grid__c.
 *              On ApprovalStatus__c changes, mirrors the new status onto the linked Agreement's
 *              Amendment_Approval_Status__c (+ Grid_Request_Approved__c for final approval),
 *              which fires the Agreement trigger → handleTimelineTransitions Branches A/B/C.
 * @author Charles EID
 * @testClass GridLifecycleTest
 * @coverage 90%   [19-03-26]
────────────────────────────────────── */
public with sharing class GridTriggerHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        syncReviewedFlag((List<Grid__c>) newItems, null);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        syncReviewedFlag((List<Grid__c>) newItems.values(), (Map<Id, Grid__c>) oldItems);
    }
    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) {
        if (PAD.canTrigger('GridAGTCreation')) {
            AgreementGridTimelineUtility.handleGridInsert((List<Grid__c>) newItems.values());
        }
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        if (PAD.canTrigger('GridAGTCreation')) {
            AgreementGridTimelineUtility.handleGridUpdate((List<Grid__c>) newItems.values(), (Map<Id, Grid__c>) oldItems);
        }
        if (PAD.canTrigger('GridApprovalTransitions')) {
            syncGridApprovalStatusToAgreement((List<Grid__c>) newItems.values(), (Map<Id, Grid__c>) oldItems);
        }
    }

    public void AfterDelete(Map<Id, SObject> oldItems) { }
    public void AfterUndelete(Map<Id, SObject> oldItems) { }

    public Boolean isDisabled() {
        if (PAD.canTrigger('GridTrigger')) {
            return triggerDisabled;
        }
        return true;
    }

    private static void syncGridApprovalStatusToAgreement(List<Grid__c> newGrids, Map<Id, Grid__c> oldGrids) {
        if (GridUtility.isUpdatingGridsFromAgreementTrigger) return; // grid update was driven by the Agreement trigger — skip to avoid SELF_REFERENCE and first-grid false-positive
        Set<Id> pendingGridIds  = new Set<Id>();
        Set<Id> approvedGridIds = new Set<Id>();
        Set<Id> rejectedGridIds = new Set<Id>();

        for (Grid__c grid : newGrids) {
            String oldStatus = oldGrids.get(grid.Id).ApprovalStatus__c;
            String newStatus = grid.ApprovalStatus__c;
            if      (newStatus == 'Pending Approval' && oldStatus != 'Pending Approval') pendingGridIds.add(grid.Id);
            else if (newStatus == 'Approved'         && oldStatus != 'Approved')         approvedGridIds.add(grid.Id);
            else if (newStatus == 'Rejected'         && oldStatus != 'Rejected')         rejectedGridIds.add(grid.Id);
        }

        if (pendingGridIds.isEmpty() && approvedGridIds.isEmpty() && rejectedGridIds.isEmpty()) return;

        Set<Id> allGridIds = new Set<Id>();
        allGridIds.addAll(pendingGridIds);
        allGridIds.addAll(approvedGridIds);
        allGridIds.addAll(rejectedGridIds);

        List<Convention__c> agreementsToUpdate = new List<Convention__c>();
        for (Convention__c agr : [SELECT Id, Grid_Request__c FROM Convention__c WHERE Grid_Request__c IN :allGridIds]) {
            if      (pendingGridIds.contains(agr.Grid_Request__c))  agreementsToUpdate.add(new Convention__c(Id = agr.Id, Amendment_Approval_Status__c = GridUtility.AGR_AMDMT_APPROVAL_REQUIRED));
            else if (approvedGridIds.contains(agr.Grid_Request__c)) agreementsToUpdate.add(new Convention__c(Id = agr.Id, Amendment_Approval_Status__c = GridUtility.AGR_AMDMT_APPROVED, Grid_Request_Approved__c = true));
            else if (rejectedGridIds.contains(agr.Grid_Request__c)) agreementsToUpdate.add(new Convention__c(Id = agr.Id, Amendment_Approval_Status__c = GridUtility.AGR_AMDMT_APPROVAL_REJECTED));
        }

        if (!agreementsToUpdate.isEmpty()) update agreementsToUpdate;
    }

    private static void syncReviewedFlag(List<Grid__c> newGrids, Map<Id, Grid__c> oldGrids) {
        for (Grid__c grid : newGrids) {
            Boolean reviewedChanged = oldGrids == null || grid.IsReviewed__c != oldGrids.get(grid.Id).IsReviewed__c;
            Boolean dateChanged     = oldGrids == null || grid.NextReviewDate__c != oldGrids.get(grid.Id).NextReviewDate__c;

            if (grid.IsReviewed__c && reviewedChanged) {
                grid.NextReviewDate__c = null;
            } else if (grid.NextReviewDate__c != null && dateChanged) {
                grid.IsReviewed__c = false;
            }
        }
    }
}