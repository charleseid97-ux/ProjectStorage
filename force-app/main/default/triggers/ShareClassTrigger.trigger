trigger ShareClassTrigger on Share_Class__c (before insert) {
    
	if(Trigger.isBefore && Trigger.isInsert) {
    	ShareClassTriggerHandler.handleBeforeInsert(Trigger.new);
    }
}