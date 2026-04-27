/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Grid Validation interface. 
 *              Provides a method for retrieving products with AUM (Assets Under Management) aggregation by share class and agreement.
 *              Formats AUM amounts for display and integrates with GridBuilderHelper for product filtering.
 * @author Charles EID
 * @testClass GridValidationControllerTest
 * @coverage 96%   [19-03-26]
────────────────────────────────────── */
public with sharing class GridValidationController {

    @AuraEnabled
    public static GridBuilderHelper.ProductSelectionResult getProducts(String gridBuilderSettingName, String countriesOfDistribution, List<Id> selectedShareClassIds, List<Id> agreementIds, Map<String, String> shareClassGridIdMap, List<String> availableGridIds) {
        Map<Id, String> aumByShareClass = buildAumByShareClass(agreementIds);

        Set<Id> selectedShareClassIdsSet = new Set<Id>(selectedShareClassIds);
        Set<Id> allShareClassIdsSet = new Set<Id>();
        allShareClassIdsSet.addAll(selectedShareClassIdsSet);
        allShareClassIdsSet.addAll(aumByShareClass.keySet());
        Set<Id> productIds = new Set<Id>();
        for (Share_Class__c sc : [SELECT Id, Fund__c FROM Share_Class__c WHERE Id IN :allShareClassIdsSet AND Fund__c != null]) {
            productIds.add(sc.Fund__c);
        }

        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, null, false, new List<String>());
        return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, gridSettings, null, selectedShareClassIdsSet, buildValidationWhereClause(gridSettings, countriesOfDistribution, productIds, availableGridIds), aumByShareClass, true, shareClassGridIdMap, true, availableGridIds);
    }

    private static Map<Id, String> buildAumByShareClass(List<Id> agreementIds) {
        Map<Id, String> aumByShareClass = new Map<Id, String>();
        if (agreementIds != null && !agreementIds.isEmpty()) {
            for (AggregateResult ar : [SELECT ShareClass__c scId, SUM(AmountEUR__c) totalAmount
                                       FROM AUM__c
                                       WHERE Convention__c IN :agreementIds
                                       GROUP BY ShareClass__c]) {
                aumByShareClass.put((Id)ar.get('scId'), GridBuilderHelper.formatAum((Decimal)ar.get('totalAmount')));
            }
        }
        return aumByShareClass;
    }

    private static String buildValidationWhereClause(GridBuilderHelper.GridSettings gridSettings, String countriesOfDistribution, Set<Id> productIds, List<String> availableGridIds) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, countriesOfDistribution, gridSettings.shareTypeWrp, false, availableGridIds);

        //Build productIds where
        whereFragments.add(' Fund__c IN '+ GridBuilderHelper.toSoqlInListLiteral(String.join(productIds, ','), ','));

        return String.join(whereFragments, ' AND ');
    }

    @AuraEnabled
    public static GridSaveResult saveGrid(String requestJson, Map<String, String> shareClassGridIdMap, Id draftGridId) {
        GridSaveResult result = new GridSaveResult();
        Savepoint sp = Database.setSavepoint();

        try {
            GridSaveRequest request = (GridSaveRequest)JSON.deserialize(requestJson, GridSaveRequest.class);

            // 1. Create or update Grid__c
            upsertCustomGrid(request.grid, draftGridId, result, request.agreementIds);

            // 2. Create GridCriteria__c (store Map<criteriaRefId, Id>)
            Map<String, GridCriteria__c> criteriaRefToRecordMap = insertGridCriteria_getCriteriaRefToIdMap(request);

            // 3. Create GridCriteriaDetail__c
            insertGridCriteriaDetails(request.criteriaList, criteriaRefToRecordMap);

            // 4. Create GridDetail__c
            insertGridDetails(request, criteriaRefToRecordMap, shareClassGridIdMap);

            // 5. Update Convention__c with Grid_Request__c (new grid only — draft edit leaves agreement unchanged)
            if (draftGridId == null) updateAgreements(request);
        }
        catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.errors.add(e.getMessage());
        }

        return result;
    }

    private static void upsertCustomGrid(Grid__c grid, Id draftGridId, GridSaveResult result, List<Id> agreementIds) {
        if (draftGridId != null) grid.Id = draftGridId;
        if (draftGridId == null && agreementIds != null && !agreementIds.isEmpty()) {
            grid.Agreement__c = agreementIds[0];
        }
        grid.RecordTypeId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();
        upsert grid;
        result.gridId = grid.Id;
        result.gridName = grid.Name;
        // In case of draft grid update: Delete existing children so they can be reinserted (GridCriteriaDetail__c cascades with GridCriteria__c)
        if (draftGridId != null) {
            delete [SELECT Id FROM GridDetail__c   WHERE Grid__c = :draftGridId];
            delete [SELECT Id FROM GridCriteria__c WHERE Grid__c = :draftGridId];
        }
    }

    private static Map<String, GridCriteria__c> insertGridCriteria_getCriteriaRefToIdMap(GridSaveRequest request) {
        List<CriteriaWrapper> criteriaList = request.criteriaList;
        List<GridCriteria__c> criteriaToInsert = new List<GridCriteria__c>();
        List<String> insertedRefs = new List<String>(); // parallel list to preserve criteriaRefId after skipping orphans
        Integer criteriaCount = 1;
        for (CriteriaWrapper cw : criteriaList) {
            if (cw.shareClassIds == null || cw.shareClassIds.isEmpty()) continue; // skip criteria with no share classes
            cw.criteria.Grid__c = request.grid.Id;
            cw.criteria.Name = 'CRIT-' + request.grid.Name + '-' + criteriaCount++;
            if (cw.details == null || cw.details.size() <= 1) {
                cw.criteria.FilterLogic__c = null;
                cw.criteria.FilterLogicExpression__c = null;
            }
            criteriaToInsert.add(cw.criteria);
            insertedRefs.add(cw.criteriaRefId);
        }

        Map<String, GridCriteria__c> criteriaRefToRecordMap = new Map<String, GridCriteria__c>();
        if (!criteriaToInsert.isEmpty()) {
            insert criteriaToInsert;
            for (Integer i = 0; i < insertedRefs.size(); i++) {
                criteriaRefToRecordMap.put(insertedRefs[i], criteriaToInsert[i]);
            }
        }
        return criteriaRefToRecordMap;
    }

    private static void insertGridCriteriaDetails(List<CriteriaWrapper> criteriaList, Map<String, GridCriteria__c> criteriaRefToRecordMap) {
        List<GridCriteriaDetail__c> detailsToInsert = new List<GridCriteriaDetail__c>();
        for (CriteriaWrapper cw : criteriaList) {
            if (!criteriaRefToRecordMap.containsKey(cw.criteriaRefId)) continue; // skip orphaned criteria
            if (cw.details != null) {
                for (GridCriteriaDetail__c detail : cw.details) {
                    detail.GridCriteria__c = criteriaRefToRecordMap.get(cw.criteriaRefId).Id;
                    detailsToInsert.add(detail);
                }
            }
        }
        if (!detailsToInsert.isEmpty()) {
            insert detailsToInsert;
        }
    }

    private static void insertGridDetails(GridSaveRequest request, Map<String, GridCriteria__c> criteriaRefToRecordMap, Map<String, String> shareClassGridIdMap) {
        Map<Id, GridBuilderHelper.StandardGridDetailInfo> stdGridDetailInfoByShareClass = (shareClassGridIdMap != null && !shareClassGridIdMap.isEmpty()) ? GridBuilderHelper.buildStandardGridDetailInfoByShareClass(shareClassGridIdMap) : new Map<Id, GridBuilderHelper.StandardGridDetailInfo>();
        List<GridDetail__c> gridDetailsToInsert = new List<GridDetail__c>();
        Id customGridDetailRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID_DETAIL).getRecordTypeId();
        for (CriteriaWrapper cw : request.criteriaList) {
            if (cw.shareClassIds == null) continue;
            GridCriteria__c criteriaRecord = criteriaRefToRecordMap.get(cw.criteriaRefId);
            for (Id scId : cw.shareClassIds) {
                GridBuilderHelper.StandardGridDetailInfo info = stdGridDetailInfoByShareClass.get(scId);
                if (info == null) continue;
                gridDetailsToInsert.add(new GridDetail__c(
                    RecordTypeId = customGridDetailRtId,
                    Grid__c = request.grid.Id,
                    StandardGridDetail__c = info.gridDetailId,
                    GridCriteria__c = criteriaRecord != null ? criteriaRecord.Id : null
                ));
            }
        }
        if (!gridDetailsToInsert.isEmpty()) insert gridDetailsToInsert;
    }

    private static void updateAgreements(GridSaveRequest request) {
        if (request.agreementIds == null || request.agreementIds.isEmpty()) return;

        List<Convention__c> agreementsToUpdate = new List<Convention__c>();
        Grid__c gridToUpdate = new Grid__c(Id = request.grid.Id);
        for (Id agmtId : request.agreementIds) {
            agreementsToUpdate.add(new Convention__c(Id = agmtId, Grid_Request__c = request.grid.Id, Grid_Request_Start_Date__c = request.grid.StartDate__c));
        }

        Database.update(agreementsToUpdate, false); // allOrNone=false: org process builders may reject the update for certain record types; grid + AGT creation must not be blocked
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class GridSaveRequest {
        @AuraEnabled public Grid__c grid { get; set; }
        @AuraEnabled public List<CriteriaWrapper> criteriaList { get; set; }
        @AuraEnabled public List<Id> agreementIds { get; set; }
        @AuraEnabled public Map<String, String> shareClassGridIdMap { get; set; }
    }

    public class CriteriaWrapper {
        @AuraEnabled public String criteriaRefId { get; set; }
        @AuraEnabled public GridCriteria__c criteria { get; set; }
        @AuraEnabled public List<GridCriteriaDetail__c> details { get; set; }
        @AuraEnabled public List<Id> shareClassIds { get; set; }
    }


    public class GridSaveResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Id gridId { get; set; }
        @AuraEnabled public String gridName { get; set; }
        @AuraEnabled public List<String> errors { get; set; }

        public GridSaveResult() {
            this.success = true;
            this.errors = new List<String>();
        }
    }
}