trigger ProjectProductChildTrigger on ProjectProductChild__c (after undelete, before delete, before insert, after insert, before update, after update) {
    if(Trigger.isBefore) {
        if (Trigger.isInsert /*&& PAD.canTrigger('ProjectProductBeforeInsert')*/) {
            ProjectProductChildTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate /*&& PAD.canTrigger('ProjectProductBeforeUpdate')*/) {
            ProjectProductChildTriggerHandler.handleBeforeUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter) {
        if (Trigger.isInsert /*&& PAD.canTrigger('ProjectProductAfterInsert')*/) {
            ProjectProductChildTriggerHandler.handleAfterInsert(Trigger.newMap);
        }
        else if (Trigger.isUpdate /*&& PAD.canTrigger('ProjectProductAfterUpdate')*/) {
            ProjectProductChildTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}

/** PAD TO DO **/