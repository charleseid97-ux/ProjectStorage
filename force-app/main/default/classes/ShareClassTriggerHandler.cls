public class ShareClassTriggerHandler {
    
    public static void handleBeforeInsert(List<Share_Class__c> newShareClasses) {
		Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        
        MAP<String, Id> fundMap = new Map<String, Id>();
        
        for(Product__c pF : [SELECT Id, Name FROM Product__c WHERE RecordTypeId =: fundRecordTypeId]) {
            fundMap.put(pF.Name, pF.Id);
        }
        
        for(Share_Class__c fM : newShareClasses) {
            if(fundMap.get(fM.Fund_Code__c)!=null) {
                fM.Fund__c = fundMap.get(fM.Fund_Code__c);
            }
        }
        
    }
}