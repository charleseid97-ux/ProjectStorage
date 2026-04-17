public class ProductTriggerHandler {
    
    public static void handleBeforeInsert(List<Product__c> newProducts) {
        processProducts(newProducts);
    }

    public static void handleAfterInsert(List<Product__c> newProducts) {
    FieldHistoryLogger.log(newProducts, null, 'Product__c');
}

    public static void handleBeforeUpdate(List<Product__c> newProducts) {
        processProducts(newProducts);
    }
    public static void handleAfterUpdate(List<Product__c> newProducts , Map<Id,Product__c > oldProductsMap ) {
    FieldHistoryLogger.log( newProducts ,  oldProductsMap , 'Product__c');
    FieldHistoryLogger.logAllFields( newProducts ,  oldProductsMap , 'Product__c');
    }
    
    private static void processProducts(List<Product__c> newProducts) {
        Id AssetClassRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Asset_Class').getRecordTypeId();
        Id SubAssetClassRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Sub_Asset_Class').getRecordTypeId();
        Id StrategyRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
        
        Map<String, Id> assetClassIdMap = new Map<String, Id>();
        For(Product__c AC : [SELECT Id, Asset_Class_Code__c FROM Product__c WHERE RecordType.Name = 'Asset Class']) {
            assetClassIdMap.put(AC.Asset_Class_Code__c, AC.Id);
        }
        Map<String, Id> regionalFocusIdMap = new Map<String, Id>();
        For(Product__c RF : [SELECT Id, Sub_Asset_Class_Code__c FROM Product__c WHERE RecordType.Name = 'Regional Focus']) {
            regionalFocusIdMap.put(RF.Sub_Asset_Class_Code__c, RF.Id);
        }

        MAP<String, Id> strategyMap = new Map<String, Id>();
        
        for(Product__c pS : [SELECT Id, Name FROM Product__c WHERE RecordTypeId =: strategyRecordTypeId]) {
            strategyMap.put(pS.Name, pS.Id);
        }
        
        for(Product__c p : newProducts) {
            if(p.Record_Type_Name__c == 'Asset Class') {
                p.RecordTypeId = AssetClassRecordTypeId;
            } else if(p.Record_Type_Name__c == 'Regional Focus') {
                p.RecordTypeId = SubAssetClassRecordTypeId;
            } else if(p.Record_Type_Name__c == 'Strategy') {
                p.RecordTypeId = StrategyRecordTypeId;
                if(assetClassIdMap.get(p.Asset_Class_Code__c) != null)
                    p.Asset_Class__c = assetClassIdMap.get(p.Asset_Class_Code__c);
                if(regionalFocusIdMap.get(p.Sub_Asset_Class_Code__c) != null)
                    p.Sub_Asset_Class__c = regionalFocusIdMap.get(p.Sub_Asset_Class_Code__c);
                p.Asset_Class_Code__c = '';
                p.Sub_Asset_Class_Code__c = '';
            } else if(p.Record_Type_Name__c == 'Fund') {
                if(strategyMap.get(p.Strategy_Code__c)!=null)
                    p.Strategy__c = strategyMap.get(p.Strategy_Code__c);
                p.Asset_Class_Code__c = '';
                p.Sub_Asset_Class_Code__c = '';
            }
        }        
    }
}