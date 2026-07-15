/** ──────────────────────────────────────
 * @description Trigger handler for GridCriteria__c.
 *              AfterInsert / AfterUpdate / AfterDelete / AfterUndelete: bundles the parent
 *              Grid Ids of the affected criteria and delegates to
 *              GridUtility.updateSelectedStandardGrids to recompute SelectedStandardGrids__c.
 * @author Charles EID
────────────────────────────────────── */
public without sharing class GridCriteriaTriggerHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) { }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) { }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) {
        refreshSelectedStandardGrids((List<GridCriteria__c>) newItems.values(), null);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        refreshSelectedStandardGrids((List<GridCriteria__c>) newItems.values(), (Map<Id, GridCriteria__c>) oldItems);
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
        refreshSelectedStandardGrids((List<GridCriteria__c>) oldItems.values(), null);
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
        refreshSelectedStandardGrids((List<GridCriteria__c>) oldItems.values(), null);
    }

    public Boolean isDisabled() {
        if (PAD.canTrigger('GridCriteriaTrigger')) {
            return triggerDisabled;
        }
        return true;
    }

    // ─── Private helpers ─────────────────────────────────────────────────────
    private static void refreshSelectedStandardGrids(List<GridCriteria__c> criteria, Map<Id, GridCriteria__c> oldCriteria) {
        Set<Id> gridIds = new Set<Id>();
        for (GridCriteria__c gc : criteria) {
            if (oldCriteria == null) {
                // Insert / Delete / Undelete: only criteria with a standard grid can affect the concatenation
                if (gc.Grid__c != null && gc.StandardGrid__c != null) gridIds.add(gc.Grid__c);
            } else {
                GridCriteria__c oldGc = oldCriteria.get(gc.Id);
                if (gc.StandardGrid__c == oldGc.StandardGrid__c && gc.Grid__c == oldGc.Grid__c) continue;
                if (gc.Grid__c != null)    gridIds.add(gc.Grid__c);
                if (oldGc.Grid__c != null) gridIds.add(oldGc.Grid__c); // criteria was reparented — refresh the previous grid too
            }
        }
        if (!gridIds.isEmpty()) {
            GridUtility.updateSelectedStandardGrids(new List<Id>(gridIds));
        }
    }
}
