public with sharing class TaxDataTriggerHandler {

    public static void handleBeforeInsert(List<TaxData__c> newRecords) {
        TaxTriggerHandler.populateTaxDataName(newRecords);
        TaxTriggerHandler.preventDuplicates(newRecords, null);
        //TaxTriggerHandler.validateBelgiumSimulator(newRecords, null);
    }

    public static void handleBeforeUpdate(
        List<TaxData__c> newRecords,
        Map<Id, TaxData__c> oldMap
    ) {
        TaxTriggerHandler.handleDates(newRecords, oldMap);
        TaxTriggerHandler.preventDuplicates(newRecords, oldMap);
        //TaxTriggerHandler.validateBelgiumSimulator(newRecords, oldMap);
    }

    private static final String SOURCE_PMT = 'PMT';

    public static void handleAfterInsert(List<TaxData__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<TaxData__c> nonPmtTaxData = new List<TaxData__c>();

        for (TaxData__c td : newRecords) {
            if (td.Source__c != SOURCE_PMT) {
                nonPmtTaxData.add(td);
            }
        }

        if (!nonPmtTaxData.isEmpty()) {
            TaxEmailService.sendATTransparencyEmails(nonPmtTaxData);
            TaxEmailService.sendCHTransparencyEmails(nonPmtTaxData);
        }
    }

    public static void handleAfterUpdate(
        List<TaxData__c> newRecords,
        Map<Id, TaxData__c> oldMap
    ) {
        TaxTriggerHandler.archiveHistory(newRecords, oldMap);
        TaxTriggerHandler.createBeTisWhenAssetTestExceedsThreshold(newRecords, oldMap);
    }
}