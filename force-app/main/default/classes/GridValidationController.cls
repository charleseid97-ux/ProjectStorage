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
}