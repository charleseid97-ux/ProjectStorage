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

        ShareClassHandler.updateFormattedName(newShareClasses, null);
        
    }

    public static void handleAfterInsert(List<Share_Class__c> newShareClasses) {
        FieldHistoryLogger.log(newShareClasses, null, 'Share_Class__c');
}

    public static void handleBeforeUpdate(List<Share_Class__c> newShareClasses , Map<Id,Share_Class__c> oldShareClassesMap){
        ShareClassHandler.updateFormattedName(newShareClasses, oldShareClassesMap);
    }
    
    public static void handleAfterUpdate(List<Share_Class__c> newShareClasses , Map<Id,Share_Class__c> oldShareClassesMap){
        FieldHistoryLogger.log( newShareClasses ,  oldShareClassesMap , 'Share_Class__c');
    	FieldHistoryLogger.logAllFields( newShareClasses ,  oldShareClassesMap , 'Share_Class__c');
    }
}