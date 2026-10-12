public class ShareClassTriggerHandler {
    
    // Initializes the related fund and formats the Share Class name before insert.
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

    // Logs the new Share Class and recalculates any existing Country Registrations.
    public static void handleAfterInsert(List<Share_Class__c> newShareClasses) {
        FieldHistoryLogger.log(newShareClasses, null, 'Share_Class__c');
        MainShareClassService.recalculateAfterShareClassInsert(newShareClasses);
    }

    // Rebuilds the formatted Share Class name when relevant fields change.
    public static void handleBeforeUpdate(List<Share_Class__c> newShareClasses , Map<Id,Share_Class__c> oldShareClassesMap){
        ShareClassHandler.updateFormattedName(newShareClasses, oldShareClassesMap);
    }
    
    // Executes existing update logic and recalculates Main Share Classes when required.
    public static void handleAfterUpdate(List<Share_Class__c> newShareClasses , Map<Id,Share_Class__c> oldShareClassesMap){
        FieldHistoryLogger.log( newShareClasses ,  oldShareClassesMap , 'Share_Class__c');
    	FieldHistoryLogger.logAllFields( newShareClasses ,  oldShareClassesMap , 'Share_Class__c');
        
        // START GRID RELATED CHANGES
        Set<Id> changedEMFIds = new Set<Id>();
        for (Share_Class__c sc : newShareClasses) {
            if (sc.EffectiveManagementFees__c != oldShareClassesMap.get(sc.Id).EffectiveManagementFees__c) {
                changedEMFIds.add(sc.Id);
            }
        }
        if (!changedEMFIds.isEmpty()) {
            GridUtility.refreshGridDetailsForShareClasses(changedEMFIds);
        }
        // END GRID RELATED CHANGES

        TaxEmailService.sendATMergerLiquidationEmails(newShareClasses, oldShareClassesMap);
        ShareClassHandler.closeTaxDataOnShareClassClosure(newShareClasses, oldShareClassesMap);
        MainShareClassService.recalculateAfterShareClassUpdate(newShareClasses, oldShareClassesMap);

    }
}