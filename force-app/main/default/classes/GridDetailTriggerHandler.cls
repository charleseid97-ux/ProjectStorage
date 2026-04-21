public with sharing class GridDetailTriggerHandler implements ITriggerHandler {

    public void BeforeInsert(List<SObject> newItems) {
        List<GridDetail__c> details = (List<GridDetail__c>) newItems;
        populateFromStandardDetail(details, null);
        populateEffectiveMgtFees(details, null);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        List<GridDetail__c> details = (List<GridDetail__c>) newItems.values();
        Map<Id, GridDetail__c> oldMap = (Map<Id, GridDetail__c>) oldItems;
        populateFromStandardDetail(details, oldMap);
        populateEffectiveMgtFees(details, oldMap);
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) { }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) { }

    public void AfterDelete(Map<Id, SObject> oldItems) { }

    public void AfterUndelete(Map<Id, SObject> oldItems) { }

    public Boolean IsDisabled() { return false; }

    // ── When StandardGridDetail__c is set on a Custom Grid Detail → copy ShareClass + RebateRate ──
    private static void populateFromStandardDetail(List<GridDetail__c> details, Map<Id, GridDetail__c> oldMap) {
        Set<Id> gridIds = new Set<Id>(); Set<Id> stdDetIds = new Set<Id>();
        List<GridDetail__c> gdToUpdate = new List<GridDetail__c>();
        for (GridDetail__c d : details) {
            if (d.StandardGridDetail__c == null) continue;
            if (oldMap != null && oldMap.get(d.Id).StandardGridDetail__c == d.StandardGridDetail__c) continue;
            if (d.Grid__c != null) gridIds.add(d.Grid__c);
            gdToUpdate.add(d);
            stdDetIds.add(d.StandardGridDetail__c);
        }
        if (gridIds.isEmpty()) return;

        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();
        Set<Id> customGridIds = new Map<Id, Grid__c>([SELECT Id FROM Grid__c WHERE Id IN :gridIds AND RecordTypeId = :customGridRtId]).keySet();
        if (customGridIds.isEmpty()) return;

        Map<Id, GridDetail__c> sourceMap = new Map<Id, GridDetail__c>([SELECT Id, ShareClass__c, RebateRate__c FROM GridDetail__c WHERE Id IN :stdDetIds]);

        for (GridDetail__c d : gdToUpdate) {
            if (!customGridIds.contains(d.Grid__c)) continue;
            GridDetail__c src = sourceMap.get(d.StandardGridDetail__c);
            if (src != null) {
                d.ShareClass__c = src.ShareClass__c;
                d.RebateRate__c = src.RebateRate__c;
            }
        }
    }

    // ── When ShareClass__c is set on any Grid Detail → copy EffectiveManagementFees ──
    private static void populateEffectiveMgtFees(List<GridDetail__c> details, Map<Id, GridDetail__c> oldMap) {
        Set<Id> scIds = new Set<Id>();
        List<GridDetail__c> gdToUpdate = new List<GridDetail__c>();
        for (GridDetail__c d : details) {
            if (d.ShareClass__c == null) continue;
            if (oldMap != null && oldMap.get(d.Id).ShareClass__c == d.ShareClass__c) continue;
            gdToUpdate.add(d);
            scIds.add(d.ShareClass__c);
        }
        if (scIds.isEmpty()) return;

        Map<Id, Share_Class__c> scMap = new Map<Id, Share_Class__c>([SELECT Id, EffectiveManagementFees__c FROM Share_Class__c WHERE Id IN :scIds]);

        for (GridDetail__c d : gdToUpdate) {
            Share_Class__c sc = scMap.get(d.ShareClass__c);
            if (sc != null) {
                d.EffectiveManagementFees__c = sc.EffectiveManagementFees__c;
            }
        }
    }
}