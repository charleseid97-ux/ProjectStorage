trigger CountryTrigger on Country__c (before insert, before update, after update, after insert, after delete) {
    
	if(Trigger.isBefore && Trigger.isInsert) {
    	CountryTriggerHandler.handleBeforeInsert(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isInsert) {
    	CountryTriggerHandler.handleAfterInsert(Trigger.new);
    }

    if(Trigger.isBefore && Trigger.isUpdate) {
    	CountryTriggerHandler.handleBeforeUpdate(Trigger.new  ,  Trigger.oldMap);
    }
    
    if(Trigger.isAfter && Trigger.isUpdate) {
    	CountryTriggerHandler.handleAfterUpdate(Trigger.new  ,  Trigger.oldMap);
    }

    if(Trigger.isAfter && Trigger.isDelete) {
        CountryTriggerHandler.handleAfterDelete(Trigger.old);
    }
}