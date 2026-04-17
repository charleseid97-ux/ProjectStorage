public class StrategyOnFund {

    public static void processFunds() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        Id strategyRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
        List<Product__c> fundsToUpdate = new List<Product__c>();
        
        MAP<String, Id> strategyMap = new Map<String, Id>();
        for(Product__c pS : [SELECT Id, Name FROM Product__c WHERE RecordTypeId =: strategyRecordTypeId]) {
            strategyMap.put(pS.Name, pS.Id);
        }
        
        for(Product__c pF : [SELECT Strategy__c, Strategy_Code__c FROM Product__c WHERE RecordTypeId =: fundRecordTypeId]) {
            if(strategyMap.get(pF.Strategy_Code__c)!=null) {
                pF.Strategy__c = strategyMap.get(pF.Strategy_Code__c);
                fundsToUpdate.add(pF);
            }
        }
        
        update fundsToUpdate;
    }

    public static void processShareClasses() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        List<Share_Class__c> shareClassesToUpdate = new List<Share_Class__c>();
        
        MAP<String, Id> fundMap = new Map<String, Id>();
        for(Product__c pF : [SELECT Id, Name FROM Product__c WHERE RecordTypeId =: fundRecordTypeId]) {
            fundMap.put(pF.Name, pF.Id);
        }
        
        for(Share_Class__c sC : [SELECT Fund__c, Fund_Code__c FROM Share_Class__c]) {
            if(fundMap.get(sC.Fund_Code__c)!=null) {
                sC.Fund__c = fundMap.get(sC.Fund_Code__c);
                shareClassesToUpdate.add(sC);
            }
        }
        
        update shareClassesToUpdate;
    }

}