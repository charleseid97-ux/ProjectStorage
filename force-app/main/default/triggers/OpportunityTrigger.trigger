trigger OpportunityTrigger on Opportunity (after undelete, before delete, before insert) {

    if(Trigger.isBefore && Trigger.isInsert) {
        if (PAD.canTrigger('OpportunityBeforeInsert')) {
            OpportunityTriggerHandler.handleBeforeInsert(Trigger.new);
        }
    }
}