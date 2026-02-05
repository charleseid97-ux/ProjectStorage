/**
 * @description Lightning Web Component controller for the Grid Validation interface. 
 *              Provides a method for retrieving products with AUM (Assets Under Management) aggregation by share class and agreement.
 *              Formats AUM amounts for display and integrates with GridBuilderHelper for product filtering.
 * @author Charles EID
 * @testClass GridValidationControllerTest
 * @coverage 100%
 */
public with sharing class GridValidationController {

    @AuraEnabled
    public static GridBuilderHelper.ProductSelectionResult getProducts(String gridBuilderSettingName, String selectedTeam, List<Id> selectedShareClassIds, List<Id> agreementIds, Map<String, String> shareClassGridIdMap) {
        Map<Id, String> aumByShareClass = buildAumByShareClass(agreementIds);

        Set<Id> selectedShareClassIdsSet = new Set<Id>(selectedShareClassIds);
        Set<Id> allShareClassIdsSet = new Set<Id>();
        allShareClassIdsSet.addAll(selectedShareClassIdsSet);
        allShareClassIdsSet.addAll(aumByShareClass.keySet());
        Set<Id> productIds = new Set<Id>();
        for (Share_Class__c sc : [SELECT Id, Fund__c FROM Share_Class__c WHERE Id IN :allShareClassIdsSet AND Fund__c != null]) {
            productIds.add(sc.Fund__c);
        }

        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, selectedTeam, false);
        return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, selectedTeam, gridSettings, null, selectedShareClassIdsSet, buildValidationWhereClause(gridSettings, selectedTeam, productIds), aumByShareClass, true, shareClassGridIdMap, true);
    }

    private static Map<Id, String> buildAumByShareClass(List<Id> agreementIds) {
        Map<Id, String> aumByShareClass = new Map<Id, String>();
        Decimal totalAum;
        if (agreementIds != null && !agreementIds.isEmpty()) {
            for (AggregateResult ar : [SELECT ShareClass__c scId, SUM(AmountEUR__c) totalAmount
                                       FROM AUM__c
                                       WHERE Convention__c IN :agreementIds
                                       GROUP BY ShareClass__c]) {
                totalAum = (Decimal)ar.get('totalAmount');
                totalAum = totalAum == null? 0 : totalAum >= 100000? totalAum.setScale(0) : totalAum;
                aumByShareClass.put((Id)ar.get('scId'), GridBuilderHelper.formatDecimal(totalAum));
            }
        }
        return aumByShareClass;
    }

    private static String buildValidationWhereClause(GridBuilderHelper.GridSettings gridSettings, String selectedTeam, Set<Id> productIds) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, selectedTeam, gridSettings.shareTypeWrp, false);

        //Build productIds where
        whereFragments.add(' Fund__c IN '+ GridBuilderHelper.toSoqlInListLiteral(String.join(productIds, ','), ','));

        return String.join(whereFragments, ' AND ');
    }

    @AuraEnabled
    public static GridSaveResult saveGrid(String requestJson) {
        GridSaveResult result = new GridSaveResult();
        Savepoint sp = Database.setSavepoint();

        try {
            GridSaveRequest request = (GridSaveRequest)JSON.deserialize(requestJson, GridSaveRequest.class);

            // 1. Create Grid__c
            insertCustomGrid(request.grid, result);

            // 2. Create GridCriteria__c (store Map<criteriaRefId, Id>)
            Map<String, GridCriteria__c> criteriaRefToRecordMap = insertGridCriteria_getCriteriaRefToIdMap(request.criteriaList);

            // 3. Create GridCriteriaDetail__c
            insertGridCriteriaDetails(request.criteriaList, criteriaRefToRecordMap);

            // 4. Create GridDetail__c
            insertGridDetails(request, criteriaRefToRecordMap);

            // 5. Update Convention__c with Grid__c
            updateAgreements(request);
        }
        catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.errors.add(e.getMessage());
        }

        return result;
    }

    private static void insertCustomGrid(Grid__c grid, GridSaveResult result) {
        insert grid;
        result.gridId = grid.Id;
        result.gridName = grid.Name;
    }

    private static Map<String, GridCriteria__c> insertGridCriteria_getCriteriaRefToIdMap(List<CriteriaWrapper> criteriaList) {
        Map<String, GridCriteria__c> criteriaRefToRecordMap = new Map<String, GridCriteria__c>();
        List<GridCriteria__c> criteriaToInsert = new List<GridCriteria__c>();
        for (CriteriaWrapper cw : criteriaList) {
            criteriaToInsert.add(cw.criteria);
        }
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

    private static void insertGridDetails(GridSaveRequest request, Map<String, GridCriteria__c> criteriaRefToRecordMap) {
        List<GridDetail__c> gridDetailsToInsert = new List<GridDetail__c>();
        for (CriteriaWrapper cw : request.criteriaList) {
            if (cw.shareClassIds != null) {
                for (Id scId : cw.shareClassIds) {
                    gridDetailsToInsert.add(new GridDetail__c(
                        Grid__c = request.grid.Id,
                        ShareClass__c = scId,
                        GridCriteria__c = criteriaRefToRecordMap.get(cw.criteriaRefId).Id,
                        StartDate__c = cw.criteria != null ? cw.criteria.StartDate__c : null
                    ));
                }
            }
        }
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