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

    // ── When ShareClass__c is set on any Grid Detail → copy EffectiveManagementFees (skip if already set) ──
    private static void populateEffectiveMgtFees(List<GridDetail__c> details, Map<Id, GridDetail__c> oldMap) {
        Set<Id> scIds = new Set<Id>();
        List<GridDetail__c> gdToUpdate = new List<GridDetail__c>();
        for (GridDetail__c d : details) {
            if (d.ShareClass__c == null) continue;
            if (d.EffectiveManagementFees__c != null) continue; // already set (historical record) — do not overwrite
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

    // ── For newly inserted Custom Grid Details: fix StartDate from history and create historical sibling records ──
    private static void createHistoricalCustomGridDetails(List<GridDetail__c> newDetails) {
        Set<Id> gridIdsToCheck = new Set<Id>();
        for (GridDetail__c d : newDetails) {
            if (d.Grid__c != null && d.ShareClass__c != null) gridIdsToCheck.add(d.Grid__c);
        }
        if (gridIdsToCheck.isEmpty()) return;

        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();

        Map<Id, Grid__c> customGridMap = new Map<Id, Grid__c>([SELECT Id, StartDate__c FROM Grid__c WHERE Id IN :gridIdsToCheck AND RecordTypeId = :customGridRtId]);
        if (customGridMap.isEmpty()) return;

        List<GridDetail__c> customDetails = new List<GridDetail__c>();
        for (GridDetail__c d : newDetails) {
            if (customGridMap.containsKey(d.Grid__c)) customDetails.add(d);
        }
        if (customDetails.isEmpty()) return;

        Set<Id> scIds = new Set<Id>();
        for (GridDetail__c d : customDetails) {
            if (d.ShareClass__c != null) scIds.add(d.ShareClass__c);
        }

        Map<Id, Date> gridStartDateMap = new Map<Id, Date>();
        for (Grid__c g : customGridMap.values()) gridStartDateMap.put(g.Id, g.StartDate__c);

        Map<Id, Date> scCreatedDateMap = new Map<Id, Date>();
        for (Share_Class__c sc : [SELECT Id, CreatedDate FROM Share_Class__c WHERE Id IN :scIds]) {
            scCreatedDateMap.put(sc.Id, sc.CreatedDate != null ? sc.CreatedDate.date() : null);
        }

        Map<Id, Date> currentHistStartByShareClass = new Map<Id, Date>();
        for (Fund_Field_ApplicabilityHistory__c h : [SELECT Share_Class_Reference__c, Start_Date__c
                                                     FROM Fund_Field_ApplicabilityHistory__c
                                                     WHERE Share_Class_Reference__c IN :scIds
                                                     AND FieldAPIName__c = :GridUtility.FIELD_EFF_MGT_FEES
                                                     AND End_Date__c = null]) {
            currentHistStartByShareClass.put(h.Share_Class_Reference__c, h.Start_Date__c);
        }

        // Update base records' StartDate where the history-derived start differs
        List<GridDetail__c> baseToUpdate = new List<GridDetail__c>();
        for (GridDetail__c d : customDetails) {
            if (d.ShareClass__c == null) continue;
            Date gridStart = gridStartDateMap.get(d.Grid__c);
            Date scCreated = scCreatedDateMap.get(d.ShareClass__c);
            Date effStart  = GridUtility.effectiveStart(gridStart, scCreated);
            Date histStart = currentHistStartByShareClass.get(d.ShareClass__c);
            Date newStart  = (histStart != null && (effStart == null || histStart > effStart)) ? histStart : effStart;
            if (newStart != null && newStart != d.StartDate__c) {
                baseToUpdate.add(new GridDetail__c(Id = d.Id, StartDate__c = newStart));
            }
        }
        if (!baseToUpdate.isEmpty()) update baseToUpdate;

        List<String> errors = new List<String>();
        List<GridDetail__c> historicalDetails = GridUtility.buildHistoricalDetailsFromFieldHistory(customDetails, gridStartDateMap, scCreatedDateMap, null, errors);
        if (!errors.isEmpty()) {
            throw new AuraHandledException('Historical grid detail creation failed: ' + String.join(errors, '; '));
        }
        if (historicalDetails.isEmpty()) return;

        isInsertingHistoricalDetails = true;
        try {
            insert historicalDetails;
        } finally {
            isInsertingHistoricalDetails = false;
        }
    }
}