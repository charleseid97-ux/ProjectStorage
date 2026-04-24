public with sharing class GridDetailTriggerHandler implements ITriggerHandler {

    private static Boolean isInsertingHistoricalDetails = false;

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

    public void AfterInsert(Map<Id, SObject> newItems) {
        if (!isInsertingHistoricalDetails) {
            createHistoricalCustomGridDetails((List<GridDetail__c>) newItems.values());
        }
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) { }

    public void AfterDelete(Map<Id, SObject> oldItems) { }

    public void AfterUndelete(Map<Id, SObject> oldItems) { }

    public Boolean IsDisabled() { return false; }

    // ── When StandardGridDetail__c is set on a Custom Grid Detail → copy ShareClass, RebateRate, EffMgtFees, StartDate, EndDate ──
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

        Map<Id, GridDetail__c> sourceMap = new Map<Id, GridDetail__c>([SELECT Id, ShareClass__c, RebateRate__c, EffectiveManagementFees__c, StartDate__c, EndDate__c 
                                                                       FROM GridDetail__c 
                                                                       WHERE Id IN :stdDetIds]);

        for (GridDetail__c d : gdToUpdate) {
            if (!customGridIds.contains(d.Grid__c)) continue;
            GridDetail__c src = sourceMap.get(d.StandardGridDetail__c);
            if (src != null) {
                d.ShareClass__c              = src.ShareClass__c;
                d.RebateRate__c              = src.RebateRate__c;
                d.EffectiveManagementFees__c = src.EffectiveManagementFees__c;
                d.StartDate__c               = src.StartDate__c;
                d.EndDate__c                 = src.EndDate__c;
            }
        }
    }

    // ── When ShareClass__c is set on any Grid Detail → copy EffectiveManagementFees (skip if already set) ──
    private static void populateEffectiveMgtFees(List<GridDetail__c> details, Map<Id, GridDetail__c> oldMap) {
        Set<Id> scIds = new Set<Id>();
        List<GridDetail__c> gdToUpdate = new List<GridDetail__c>();
        for (GridDetail__c d : details) {
            if (d.ShareClass__c == null) continue;
            if (d.EffectiveManagementFees__c != null) continue; // already set (copied from standard detail) — do not overwrite
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

    // ── For each inserted Custom Grid Detail referencing a Standard Grid Detail, insert sibling records for all other Standard Grid Details of the same (Grid, ShareClass) ──
    private static void createHistoricalCustomGridDetails(List<GridDetail__c> newDetails) {
        Set<Id> stdDetIds = new Set<Id>();
        List<GridDetail__c> toProcess = new List<GridDetail__c>();
        for (GridDetail__c d : newDetails) {
            if (d.StandardGridDetail__c == null || d.Grid__c == null) continue;
            stdDetIds.add(d.StandardGridDetail__c);
            toProcess.add(d);
        }
        if (toProcess.isEmpty()) return;

        Set<Id> gridIds = new Set<Id>();
        for (GridDetail__c d : toProcess) gridIds.add(d.Grid__c);
        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();
        Set<Id> customGridIds = new Map<Id, Grid__c>([SELECT Id FROM Grid__c WHERE Id IN :gridIds AND RecordTypeId = :customGridRtId]).keySet();

        List<GridDetail__c> customDetails = new List<GridDetail__c>();
        for (GridDetail__c d : toProcess) {
            if (customGridIds.contains(d.Grid__c)) customDetails.add(d);
        }
        if (customDetails.isEmpty()) return;

        // Resolve standard Grid__c and ShareClass__c for each referenced Standard Grid Detail
        Map<Id, GridDetail__c> stdDetMap = new Map<Id, GridDetail__c>([SELECT Id, Grid__c, ShareClass__c FROM GridDetail__c WHERE Id IN :stdDetIds]);

        Set<Id> standardGridIds = new Set<Id>();
        Set<Id> shareClassIds   = new Set<Id>();
        for (GridDetail__c d : customDetails) {
            GridDetail__c ref = stdDetMap.get(d.StandardGridDetail__c);
            if (ref == null) continue;
            standardGridIds.add(ref.Grid__c);
            shareClassIds.add(ref.ShareClass__c);
        }
        if (standardGridIds.isEmpty()) return;

        // Query all Standard Grid Details for those (Grid, ShareClass) pairs
        Map<String, List<Id>> stdIdsByKey = new Map<String, List<Id>>();
        for (GridDetail__c std : [SELECT Id, Grid__c, ShareClass__c
                                  FROM GridDetail__c
                                  WHERE Grid__c IN :standardGridIds AND ShareClass__c IN :shareClassIds
                                  ORDER BY StartDate__c ASC NULLS LAST]) {
            String key = std.Grid__c + '_' + std.ShareClass__c;
            if (!stdIdsByKey.containsKey(key)) stdIdsByKey.put(key, new List<Id>());
            stdIdsByKey.get(key).add(std.Id);
        }

        // Seed covered keys with base records (already inserted) — keyed by CustomGrid__c + StandardGridDetail__c
        Set<String> coveredKeys = new Set<String>();
        Set<Id> customGridIdsForQuery = new Set<Id>();
        for (GridDetail__c d : customDetails) {
            coveredKeys.add(d.Grid__c + '_' + d.StandardGridDetail__c);
            customGridIdsForQuery.add(d.Grid__c);
        }

        // Exclude (Grid, StandardGridDetail) pairs that already exist to make the insert idempotent
        for (GridDetail__c existing : [SELECT Grid__c, StandardGridDetail__c
                                       FROM GridDetail__c
                                       WHERE Grid__c IN :customGridIdsForQuery AND StandardGridDetail__c IN :stdDetIds]) {
            coveredKeys.add(existing.Grid__c + '_' + existing.StandardGridDetail__c);
        }

        Id customGridDetailRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID_DETAIL).getRecordTypeId();
        List<GridDetail__c> historicalToInsert = new List<GridDetail__c>();
        for (GridDetail__c d : customDetails) {
            GridDetail__c ref = stdDetMap.get(d.StandardGridDetail__c);
            if (ref == null) continue;
            String key = ref.Grid__c + '_' + ref.ShareClass__c;
            List<Id> allStdIds = stdIdsByKey.get(key);
            if (allStdIds == null) continue;
            for (Id stdId : allStdIds) {
                String coveredKey = d.Grid__c + '_' + stdId;
                if (coveredKeys.contains(coveredKey)) continue; // already exists or already queued
                coveredKeys.add(coveredKey); // prevent intra-batch duplicates
                historicalToInsert.add(new GridDetail__c(
                    RecordTypeId = customGridDetailRtId,
                    Grid__c = d.Grid__c,
                    StandardGridDetail__c = stdId,
                    GridCriteria__c = d.GridCriteria__c
                ));
            }
        }
        if (historicalToInsert.isEmpty()) return;

        isInsertingHistoricalDetails = true;
        try {
            insert historicalToInsert;
        } finally {
            isInsertingHistoricalDetails = false;
        }
    }
}