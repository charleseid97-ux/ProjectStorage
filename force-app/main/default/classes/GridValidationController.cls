/**
 * @description Lightning Web Component controller for the Grid Validation interface. 
 *              Provides a method for retrieving products with AUM (Assets Under Management) aggregation by share class and agreement.
 *              Formats AUM amounts for display and integrates with GridBuilderHelper for product filtering.
 * @author Charles EID
 * @testClass GridValidationControllerTest
 * @coverage 95%
 */
public with sharing class GridValidationController {

    @AuraEnabled
    public static GridBuilderHelper.ProductSelectionResult getProducts(String gridBuilderSettingName, String countriesOfDistribution, List<Id> selectedShareClassIds, List<Id> agreementIds, Map<String, String> shareClassGridIdMap) {
        Map<Id, String> aumByShareClass = buildAumByShareClass(agreementIds);

        Set<Id> selectedShareClassIdsSet = new Set<Id>(selectedShareClassIds);
        Set<Id> allShareClassIdsSet = new Set<Id>();
        allShareClassIdsSet.addAll(selectedShareClassIdsSet);
        allShareClassIdsSet.addAll(aumByShareClass.keySet());
        Set<Id> productIds = new Set<Id>();
        for (Share_Class__c sc : [SELECT Id, Fund__c FROM Share_Class__c WHERE Id IN :allShareClassIdsSet AND Fund__c != null]) {
            productIds.add(sc.Fund__c);
        }

        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, null, false);
        return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, gridSettings, null, selectedShareClassIdsSet, buildValidationWhereClause(gridSettings, countriesOfDistribution, productIds), aumByShareClass, true, shareClassGridIdMap, true);
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

    private static String buildValidationWhereClause(GridBuilderHelper.GridSettings gridSettings, String countriesOfDistribution, Set<Id> productIds) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, countriesOfDistribution, gridSettings.shareTypeWrp, false);

        //Build productIds where
        whereFragments.add(' Fund__c IN '+ GridBuilderHelper.toSoqlInListLiteral(String.join(productIds, ','), ','));

        return String.join(whereFragments, ' AND ');
    }

    @AuraEnabled
    public static GridSaveResult saveGrid(String requestJson, Map<String, String> shareClassGridIdMap) {
        GridSaveResult result = new GridSaveResult();
        Savepoint sp = Database.setSavepoint();

        try {
            GridSaveRequest request = (GridSaveRequest)JSON.deserialize(requestJson, GridSaveRequest.class);

            // 1. Create GridScope__c for Custom Grid
            insertGridScope(request);

            // 2. Create Grid__c (with Custom record type)
            insertCustomGrid(request.grid, result);

            // 3. Create GridCriteria__c (store Map<criteriaRefId, Id>)
            Map<String, GridCriteria__c> criteriaRefToRecordMap = insertGridCriteria_getCriteriaRefToIdMap(request);

            // 4. Create GridCriteriaDetail__c
            insertGridCriteriaDetails(request.criteriaList, criteriaRefToRecordMap);

            // 5. Create GridDetail__c
            insertGridDetails(request, criteriaRefToRecordMap, shareClassGridIdMap);

            // 6. Update Convention__c with Grid__c
            updateAgreements(request);
        }
        catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.errors.add(e.getMessage());
        }

        return result;
    }

    private static void insertGridScope(GridSaveRequest request) {
        GridScope__c scope = new GridScope__c();
        scope.Name = 'Grid Scope for ' + request.grid.Name;
        scope.GridName__c = request.grid.Name;
        if (request.agreementIds != null && !request.agreementIds.isEmpty()) {
            List<String> agreementNames = new List<String>();
            for (Convention__c agmt : [SELECT Id, Name FROM Convention__c WHERE Id IN :request.agreementIds]) {
                agreementNames.add(agmt.Name);
            }
            scope.Agreement__c = String.join(agreementNames, ', ');
        }
        scope.Country__c = 'ALL';
        insert scope;
        request.grid.GridScope__c = scope.Id;
    }

    private static void insertCustomGrid(Grid__c grid, GridSaveResult result) {
        grid.RecordTypeId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();
        insert grid;
        result.gridId = grid.Id;
        result.gridName = grid.Name;
    }

    private static Map<String, GridCriteria__c> insertGridCriteria_getCriteriaRefToIdMap(GridSaveRequest request) {
        List<CriteriaWrapper> criteriaList = request.criteriaList;
        List<GridCriteria__c> criteriaToInsert = new List<GridCriteria__c>();
        Integer criteriaCount = 1;
        for (CriteriaWrapper cw : criteriaList) {
            cw.criteria.Grid__c = request.grid.Id;
            cw.criteria.Name = 'CRIT-' + request.grid.Name + '-' + criteriaCount++;
            criteriaToInsert.add(cw.criteria);
        }

        Map<String, GridCriteria__c> criteriaRefToRecordMap = new Map<String, GridCriteria__c>();
        if (!criteriaToInsert.isEmpty()) {
            insert criteriaToInsert;
            for (Integer i = 0; i < criteriaList.size(); i++) {
                criteriaRefToRecordMap.put(criteriaList[i].criteriaRefId, criteriaToInsert[i]);
            }
        }
        return criteriaRefToRecordMap;
    }

    private static void insertGridCriteriaDetails(List<CriteriaWrapper> criteriaList, Map<String, GridCriteria__c> criteriaRefToRecordMap) {
        List<GridCriteriaDetail__c> detailsToInsert = new List<GridCriteriaDetail__c>();
        for (CriteriaWrapper cw : criteriaList) {
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
        System.debug('@@@shareClassGridIdMap: '+shareClassGridIdMap);
        Map<Id, Map<String, Object>> rebateByShareClass = (shareClassGridIdMap != null && !shareClassGridIdMap.isEmpty()) ? GridBuilderHelper.buildRebateRateByShareClass(shareClassGridIdMap) : new Map<Id, Map<String, Object>>();
        System.debug('@@@rebateByShareClass: '+ rebateByShareClass);
        List<GridDetail__c> gridDetailsToInsert = new List<GridDetail__c>();
        for (CriteriaWrapper cw : request.criteriaList) {
            if (cw.shareClassIds != null) {
                GridCriteria__c criteriaRecord = criteriaRefToRecordMap.get(cw.criteriaRefId);
                for (Id scId : cw.shareClassIds) {
                    GridDetail__c detail = new GridDetail__c(
                        Grid__c = request.grid.Id,
                        ShareClass__c = scId,
                        StandardGrid__c = criteriaRecord.StandardGrid__c,
                        GridCriteria__c = criteriaRecord.Id,
                        StartDate__c = cw.criteria != null ? cw.criteria.StartDate__c : null
                    );
                    if (rebateByShareClass.containsKey(scId)) {
                        detail.Rebate__c = (Decimal)rebateByShareClass.get(scId).get('value');
                    }
                    gridDetailsToInsert.add(detail);
                }
            }
        }
        System.debug('@@@gridDetailsToInsert: '+ gridDetailsToInsert);
        if (!gridDetailsToInsert.isEmpty()) {
            insert gridDetailsToInsert;
        }
    }

    private static void updateAgreements(GridSaveRequest request) {
        if (request.agreementIds != null && !request.agreementIds.isEmpty()) {
            List<Convention__c> agreementsToUpdate = new List<Convention__c>();
            for (Id agmtId : request.agreementIds) {
                agreementsToUpdate.add(new Convention__c(Id = agmtId, Grid__c = request.grid.Id));
            }
            update agreementsToUpdate;
        }
    }

    // ------------------------------------ WRAPPERS ------------------------------------
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