/** ──────────────────────────────────────
 * @description Daily reconciliation batch for Custom Grid Details, chained from ShareClassStandardGridBatch.finish().
 *              Processes ONE Custom Grid per execute() (batch size = 1).
 *
 *              For each GridCriteria, calls GridBuilderController.getProductsAndShareClasses with
 *              getAllProductsWithSelection=true and availableGridIds=[StandardGrid__c] to obtain the share
 *              classes that match the criteria AND already have an active StandardGridDetail in the referenced
 *              standard grid. Those not yet covered by an active CustomGridDetail are inserted via
 *              GridValidationController.insertGridDetails — the same path used by the Grid Builder UI.
 *
 * @author Charles EID
 ────────────────────────────────────── */
public class ShareClassCustomGridBatch implements Database.Batchable<SObject> {

    private static final String GRID_BUILDER_SETTING = 'CustomGridBuilderSetting';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, AutomaticGridUpdate__c, Agreement__r.Countries_of_Distribution__c
                                         FROM Grid__c
                                         WHERE RecordType.DeveloperName = 'CustomGrid']);
    }

    public void execute(Database.BatchableContext bc, List<Grid__c> scope) {
        Grid__c grid = scope[0];
        if (grid.AutomaticGridUpdate__c) {
            processAutomaticGrid(grid);
        } else {
            // V2 — send email notifications to relevant people when AutomaticGridUpdate__c = false
            // sendGridUpdateNotification(grid);
        }
    }

    private void processAutomaticGrid(Grid__c grid) {
        String countriesOfDistribution = grid.Agreement__r?.Countries_of_Distribution__c;

        // ── 1. Query GridCriteria and their details ───────────────────────────────────────
        List<GridCriteria__c> criteriaList = [SELECT Id, Grid__c, StandardGrid__c, FilterLogic__c, FilterLogicExpression__c, SelectedShareTypes__c
                                              FROM GridCriteria__c
                                              WHERE Grid__c = :grid.Id];
        if (criteriaList.isEmpty()) return;

        Set<Id> criteriaIds = new Set<Id>();
        for (GridCriteria__c gc : criteriaList) criteriaIds.add(gc.Id);

        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId = new Map<Id, List<GridCriteriaDetail__c>>();
        for (GridCriteriaDetail__c d : [SELECT Id, GridCriteria__c, FilterNumber__c, Logic__c, Value__c, Object__c, Field__c, TECHOrigin__c
                                        FROM GridCriteriaDetail__c
                                        WHERE GridCriteria__c IN :criteriaIds
                                        ORDER BY FilterNumber__c ASC]) {
            if (!detailsByCriteriaId.containsKey(d.GridCriteria__c)) {
                detailsByCriteriaId.put(d.GridCriteria__c, new List<GridCriteriaDetail__c>());
            }
            detailsByCriteriaId.get(d.GridCriteria__c).add(d);
        }

        // ── 2. Existing active CustomGridDetails — prevent duplicates ─────────────────────
        Id customRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID_DETAIL).getRecordTypeId();
        Map<Id, Set<Id>> existingScIdsByCriteria = new Map<Id, Set<Id>>();
        for (GridDetail__c gd : [SELECT GridCriteria__c, ShareClass__c
                                 FROM GridDetail__c
                                 WHERE GridCriteria__c IN :criteriaIds
                                 AND RecordTypeId = :customRtId
                                 AND EndDate__c = null]) {
            if (!existingScIdsByCriteria.containsKey(gd.GridCriteria__c)) {
                existingScIdsByCriteria.put(gd.GridCriteria__c, new Set<Id>());
            }
            existingScIdsByCriteria.get(gd.GridCriteria__c).add(gd.ShareClass__c);
        }

        // ── 3. Per criteria: get eligible share classes, subtract existing, collect missing ─
        GridValidationController.GridSaveRequest saveRequest = new GridValidationController.GridSaveRequest();
        saveRequest.grid        = grid;
        saveRequest.criteriaList = new List<GridValidationController.CriteriaWrapper>();
        Map<String, GridCriteria__c> criteriaRefMap     = new Map<String, GridCriteria__c>();
        Map<String, String>          shareClassGridIdMap = new Map<String, String>();

        for (GridCriteria__c gc : criteriaList) {
            if (gc.StandardGrid__c == null) continue;

            List<GridCriteriaDetail__c> details = detailsByCriteriaId.containsKey(gc.Id) ? detailsByCriteriaId.get(gc.Id) : new List<GridCriteriaDetail__c>();

            // availableGridIds = [StandardGrid__c] → getGridDetailShareClassCondition filters to SCs
            // that already have an active StandardGridDetail in that grid, so isSelected=true means
            // the SC matches the criteria AND has a StandardGridDetail ready to link to.
            GridBuilderHelper.ProductSelectionResult result = GridBuilderController.getProductsAndShareClasses(GRID_BUILDER_SETTING, countriesOfDistribution, JSON.serialize(gc), JSON.serialize(details), true, new List<String>{ String.valueOf(gc.StandardGrid__c) });

            Set<Id> alreadyExists = existingScIdsByCriteria.get(gc.Id);
            List<Id> missingScIds = new List<Id>();
            for (GridBuilderHelper.ProductWrapper pw : result.products) {
                for (GridBuilderHelper.ShareClassWrapper scw : pw.shareClasses) {
                    if (scw.isSelected && (alreadyExists == null || !alreadyExists.contains(scw.shareClassId))) {
                        missingScIds.add(scw.shareClassId);
                        shareClassGridIdMap.put(String.valueOf(scw.shareClassId), String.valueOf(gc.StandardGrid__c));
                    }
                }
            }

            if (!missingScIds.isEmpty()) {
                GridValidationController.CriteriaWrapper cw = new GridValidationController.CriteriaWrapper();
                cw.criteriaRefId = String.valueOf(gc.Id);
                cw.shareClassIds = missingScIds;
                saveRequest.criteriaList.add(cw);
                criteriaRefMap.put(String.valueOf(gc.Id), gc);
            }
        }

        // ── 4. Insert missing CustomGridDetails via the same path as the Grid Builder UI ───
        if (!saveRequest.criteriaList.isEmpty()) {
            GridValidationController.insertGridDetails(saveRequest, criteriaRefMap, shareClassGridIdMap);
        }
    }

    // private void sendGridUpdateNotification(Grid__c grid) { /* V2 */ }

    public void finish(Database.BatchableContext bc) {}
}