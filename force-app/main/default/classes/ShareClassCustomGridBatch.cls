/** ──────────────────────────────────────
 * @description Batch triggered (via ShareClassStandardGridBatch.finish) after new Share_Class__c records are inserted.
 *              Iterates over Custom Grid records (50 per chunk), evaluates each GridCriteria against the
 *              newly inserted share classes, and creates CustomGridDetail records for matches.
 *
 *              A share class is eligible for a GridCriteria when ALL of the following hold:
 *                a1) GridCriteria.SelectedShareTypes__c contains the share class Type__c
 *                a2) GridCriteriaDetail filter conditions match the share class
 *                b)  The share class Fund__r.GridManualUpdate__c = false  (pre-filtered in start())
 *
 *              No SOQL inside any loop. Each execute() issues 3 SOQL queries:
 *              1) GridCriteria + GridCriteriaDetail  2) Share_Class__c (dynamic SELECT)  3) StandardGridDetail
 *
 * @author Charles EID
 ────────────────────────────────────── */
public class ShareClassCustomGridBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Set<Id> newShareClassIds;
    private Set<Id> eligibleScIds;

    public ShareClassCustomGridBatch(Set<Id> newShareClassIds) {
        this.newShareClassIds = newShareClassIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        eligibleScIds = new Set<Id>();
        for (Share_Class__c sc : [SELECT Id FROM Share_Class__c WHERE Id IN :newShareClassIds AND Fund__r.GridManualUpdate__c = false]) {
            eligibleScIds.add(sc.Id);
        }
        return Database.getQueryLocator([SELECT Id, AutomaticGridUpdate__c FROM Grid__c WHERE RecordType.DeveloperName = 'CustomGrid']);
    }

    public void execute(Database.BatchableContext bc, List<Grid__c> scope) {
        if (eligibleScIds == null || eligibleScIds.isEmpty()) return;

        List<Grid__c> automaticGrids = new List<Grid__c>();
        List<Grid__c> manualGrids    = new List<Grid__c>();
        for (Grid__c g : scope) {
            if (g.AutomaticGridUpdate__c) {
                automaticGrids.add(g);
            } else {
                manualGrids.add(g);
            }
        }

        if (!automaticGrids.isEmpty()) processAutomaticGrids(automaticGrids);
        if (!manualGrids.isEmpty()) {
            // V2 — send email notifications to relevant people when AutomaticGridUpdate__c = false
            // sendGridUpdateNotifications(manualGrids);
        }
    }

    private void processAutomaticGrids(List<Grid__c> grids) {
        Set<Id> scopeGridIds = new Set<Id>();
        for (Grid__c g : grids) scopeGridIds.add(g.Id);

        CriteriaData data = loadCriteriaData(scopeGridIds);
        if (data.criteriaList.isEmpty()) return;

        List<Share_Class__c> shareClasses = queryEligibleShareClasses(data.neededFieldPaths);
        if (shareClasses.isEmpty()) return;

        Map<String, Map<String, Set<Id>>> index = GridDetailBuilder.buildShareClassIndex(shareClasses, data.neededFieldPaths);

        Map<Id, Set<Id>> matchedScIdsByCriteria = evaluateCriteria(data.criteriaList, data.detailsByCriteriaId, index);
        if (matchedScIdsByCriteria.isEmpty()) return;

        Map<Id, Map<Id, GridDetail__c>> stdDetailByGridAndSc = loadStandardGridDetails(data.standardGridIds, matchedScIdsByCriteria);

        List<GridDetail__c> toInsert = buildCustomGridDetails(data.criteriaList, matchedScIdsByCriteria, stdDetailByGridAndSc);
        if (!toInsert.isEmpty()) insert toInsert;
    }

    private CriteriaData loadCriteriaData(Set<Id> scopeGridIds) {
        CriteriaData data = new CriteriaData();
        data.criteriaList = [SELECT Id, Grid__c, StandardGrid__c, FilterLogic__c, FilterLogicExpression__c, SelectedShareTypes__c
                             FROM GridCriteria__c
                             WHERE Grid__c IN :scopeGridIds];

        Set<Id> criteriaIds = new Set<Id>();
        for (GridCriteria__c gc : data.criteriaList) {
            criteriaIds.add(gc.Id);
            if (gc.StandardGrid__c != null) data.standardGridIds.add(gc.StandardGrid__c);
        }

        for (GridCriteriaDetail__c d : [SELECT Id, GridCriteria__c, FilterNumber__c, Logic__c, Value__c, Object__c, Field__c
                                        FROM GridCriteriaDetail__c
                                        WHERE GridCriteria__c IN :criteriaIds
                                        ORDER BY FilterNumber__c ASC]) {
            if (String.isNotBlank(d.Object__c) && String.isNotBlank(d.Field__c)) {
                data.neededFieldPaths.add(GridBuilderHelper.getRelationshipPath(d.Object__c) + d.Field__c);
            }
            if (!data.detailsByCriteriaId.containsKey(d.GridCriteria__c)) {
                data.detailsByCriteriaId.put(d.GridCriteria__c, new List<GridCriteriaDetail__c>());
            }
            data.detailsByCriteriaId.get(d.GridCriteria__c).add(d);
        }
        return data;
    }

    private List<Share_Class__c> queryEligibleShareClasses(Set<String> neededFieldPaths) {
        String soql = 'SELECT Id, ' + String.join(neededFieldPaths, ', ') + ' FROM Share_Class__c WHERE Id IN :eligibleScIds';
        return Database.query(soql);
    }

    private Map<Id, Set<Id>> evaluateCriteria(List<GridCriteria__c> criteriaList, Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId, Map<String, Map<String, Set<Id>>> index) {
        Map<Id, Set<Id>> matchedScIdsByCriteria = new Map<Id, Set<Id>>();
        Map<String, Set<Id>> typeIndex = index.get('Type__c');

        for (GridCriteria__c gc : criteriaList) {
            List<String> selectedTypes = String.isNotBlank(gc.SelectedShareTypes__c) ? gc.SelectedShareTypes__c.split(',') : new List<String>();
            if (selectedTypes.isEmpty()) continue;

            Set<Id> typeMatchedIds = new Set<Id>();
            if (typeIndex != null) {
                for (String t : selectedTypes) {
                    Set<Id> ids = typeIndex.get(t.trim());
                    if (ids != null) typeMatchedIds.addAll(ids);
                }
            }
            if (typeMatchedIds.isEmpty()) continue;

            List<GridCriteriaDetail__c> details = detailsByCriteriaId.containsKey(gc.Id) ? detailsByCriteriaId.get(gc.Id) : new List<GridCriteriaDetail__c>();
            Set<Id> matched = GridDetailBuilder.evaluateCriteriaDetails(details, gc.FilterLogicExpression__c, index, typeMatchedIds);
            if (!matched.isEmpty()) matchedScIdsByCriteria.put(gc.Id, matched);
        }
        return matchedScIdsByCriteria;
    }

    private Map<Id, Map<Id, GridDetail__c>> loadStandardGridDetails(Set<Id> standardGridIds, Map<Id, Set<Id>> matchedScIdsByCriteria) {
        Set<Id> allMatchedScIds = new Set<Id>();
        for (Set<Id> ids : matchedScIdsByCriteria.values()) allMatchedScIds.addAll(ids);

        Id standardRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_STANDARD_GRID_DETAIL).getRecordTypeId();

        Map<Id, Map<Id, GridDetail__c>> stdDetailByGridAndSc = new Map<Id, Map<Id, GridDetail__c>>();
        for (GridDetail__c gd : [SELECT Id, Grid__c, ShareClass__c
                                 FROM GridDetail__c
                                 WHERE Grid__c IN :standardGridIds
                                 AND ShareClass__c IN :allMatchedScIds
                                 AND RecordTypeId = :standardRtId
                                 AND (EndDate__c = null OR EndDate__c >= :Date.today())]) {
            if (!stdDetailByGridAndSc.containsKey(gd.Grid__c)) stdDetailByGridAndSc.put(gd.Grid__c, new Map<Id, GridDetail__c>());
            stdDetailByGridAndSc.get(gd.Grid__c).put(gd.ShareClass__c, gd);
        }
        return stdDetailByGridAndSc;
    }

    private List<GridDetail__c> buildCustomGridDetails(List<GridCriteria__c> criteriaList, Map<Id, Set<Id>> matchedScIdsByCriteria, Map<Id, Map<Id, GridDetail__c>> stdDetailByGridAndSc) {
        Id customRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID_DETAIL).getRecordTypeId();

        List<GridDetail__c> toInsert = new List<GridDetail__c>();
        for (GridCriteria__c gc : criteriaList) {
            Set<Id> matchedScIds = matchedScIdsByCriteria.get(gc.Id);
            if (matchedScIds == null || gc.StandardGrid__c == null) continue;
            Map<Id, GridDetail__c> stdDetailBySc = stdDetailByGridAndSc.get(gc.StandardGrid__c);
            if (stdDetailBySc == null) continue;

            for (Id scId : matchedScIds) {
                GridDetail__c stdDetail = stdDetailBySc.get(scId);
                if (stdDetail == null) continue;
                GridDetail__c cd         = new GridDetail__c();
                cd.RecordTypeId          = customRtId;
                cd.Grid__c               = gc.Grid__c;
                cd.GridCriteria__c       = gc.Id;
                cd.StandardGridDetail__c = stdDetail.Id;
                toInsert.add(cd);
            }
        }
        return toInsert;
    }

    private class CriteriaData {
        List<GridCriteria__c>                criteriaList          = new List<GridCriteria__c>();
        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId   = new Map<Id, List<GridCriteriaDetail__c>>();
        Set<Id>                              standardGridIds       = new Set<Id>();
        Set<String>                          neededFieldPaths      = new Set<String>{'Type__c'};
    }

    // private void sendGridUpdateNotifications(List<Grid__c> manualGrids) { /* V2 */ }

    public void finish(Database.BatchableContext bc) {}
}