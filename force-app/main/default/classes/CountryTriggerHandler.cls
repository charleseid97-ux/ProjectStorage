public with sharing class CountryTriggerHandler {

    public static void handleBeforeInsert(List<Country__c> newShareClasses) {
        CountryHandler.syncItalianTaxData(newShareClasses, null);
    }

    public static void handleAfterInsert(List<Country__c> newShareClasses) {
    }

    public static void handleBeforeUpdate(List<Country__c> newShareClasses , Map<Id,Country__c> oldShareClassesMap){
    }
    
    public static void handleAfterUpdate(List<Country__c> newShareClasses , Map<Id,Country__c> oldShareClassesMap){
        CountryHandler.syncItalianTaxData(newShareClasses, oldShareClassesMap);

    }
}