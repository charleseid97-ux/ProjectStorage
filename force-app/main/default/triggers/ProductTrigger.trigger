trigger ProductTrigger on Product__c (before insert, before update) {

	if(Trigger.isBefore && Trigger.isInsert) {

    	ProductTriggerHandler.handleBeforeInsert(Trigger.new);
    
    }
	if(Trigger.isBefore && Trigger.isUpdate) {

    	ProductTriggerHandler.handleBeforeUpdate(Trigger.new);
    
    }
}