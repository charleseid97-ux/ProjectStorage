trigger OpportunityTrigger on Opportunity (after undelete, before delete, before insert, after insert, before update, after update) {

    if(Trigger.isBefore) {
        if (Trigger.isInsert && PAD.canTrigger('OpportunityBeforeInsert')) {
            OpportunityTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate && PAD.canTrigger('OpportunityBeforeUpdate')) {
            OpportunityTriggerHandler.handleBeforeUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter) {
        if (Trigger.isInsert && PAD.canTrigger('OpportunityAfterInsert')) {
            OpportunityTriggerHandler.handleAfterInsert(Trigger.newMap);
        }
        else if (Trigger.isUpdate && PAD.canTrigger('OpportunityAfterUpdate')) {
            OpportunityTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.OldMap);
        }
    }
}