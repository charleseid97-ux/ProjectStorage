public without sharing class ProductTriggerHandler {
    
    public static void handleBeforeInsert(List<Product__c> newProducts) { }

    public static void handleAfterInsert(List<Product__c> newProducts) {
        FieldHistoryLogger.log(newProducts, null, 'Product__c');
    }

    public static void handleBeforeUpdate(List<Product__c> newProducts) { }

    public static void handleAfterUpdate(List<Product__c> newProducts , Map<Id,Product__c > oldProductsMap ) {
        FieldHistoryLogger.log( newProducts ,  oldProductsMap , 'Product__c');
        FieldHistoryLogger.logAllFields( newProducts ,  oldProductsMap , 'Product__c');
    }
}