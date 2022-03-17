trigger FundManagerTrigger on Fund_Manager__c (before insert) {
    
	if(Trigger.isBefore && Trigger.isInsert) {
		//If the Trigger is being fired by an Insert and we are before the database commit -> pass the trigger object list to the handler
    	FundManagerTriggerHandler.handleBeforeInsert(Trigger.new);
    
    }
}