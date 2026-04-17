trigger ProductTrigger on Product__c (before insert, before update , after update, after insert) {

	if(Trigger.isBefore && Trigger.isInsert) {

    	ProductTriggerHandler.handleBeforeInsert(Trigger.new);
    
    }
	if(Trigger.isBefore && Trigger.isUpdate) {

    	ProductTriggerHandler.handleBeforeUpdate(Trigger.new);
    
    }
    if(Trigger.isAfter && Trigger.isInsert) {
    	
        ProductTriggerHandler.handleAfterInsert( Trigger.new  );
    
    }
    if(Trigger.isAfter && Trigger.isUpdate) {

    	
        ProductTriggerHandler.handleAfterUpdate( Trigger.new  ,  Trigger.oldMap );
    
    }
}