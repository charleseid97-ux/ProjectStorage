trigger ShareClassTrigger on Share_Class__c (before insert, before update, after update, after insert) {
    
	if(Trigger.isBefore && Trigger.isInsert) {
    	ShareClassTriggerHandler.handleBeforeInsert(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isInsert) {
    	ShareClassTriggerHandler.handleAfterInsert(Trigger.new);
    }

    if(Trigger.isBefore && Trigger.isUpdate) {
    	ShareClassTriggerHandler.handleBeforeUpdate(Trigger.new  ,  Trigger.oldMap);
    }
    
    if(Trigger.isAfter && Trigger.isUpdate) {
    	ShareClassTriggerHandler.handleAfterUpdate(Trigger.new  ,  Trigger.oldMap);
    }
}