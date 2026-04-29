public with sharing class TaxDataTriggerHandler {

    public static void handleBeforeInsert(List<TaxData__c> newRecords) {
        TaxTriggerHandler.populateTaxDataName(newRecords);
        TaxTriggerHandler.preventDuplicates(newRecords, null);
        TaxTriggerHandler.validateBelgiumSimulator(newRecords, null);
    }

    public static void handleBeforeUpdate(
        List<TaxData__c> newRecords,
        Map<Id, TaxData__c> oldMap
    ) {
        TaxTriggerHandler.handleDates(newRecords, oldMap);
        TaxTriggerHandler.preventDuplicates(newRecords, oldMap);
        TaxTriggerHandler.validateBelgiumSimulator(newRecords, oldMap);
    }

    public static void handleAfterInsert(List<TaxData__c> newRecords) {
        TaxEmailService.sendATTransparencyEmails(newRecords);
        TaxEmailService.sendCHTransparencyEmails(newRecords);
    }

    public static void handleAfterUpdate(
        List<TaxData__c> newRecords,
        Map<Id, TaxData__c> oldMap
    ) {
        TaxTriggerHandler.archiveHistory(newRecords, oldMap);
        //TaxTriggerHandler.sendDeletionRequestedNotification(newRecords, oldMap);
    }
}