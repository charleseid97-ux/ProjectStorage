trigger ProjectProductTrigger on ProjectProduct__c (after undelete, before delete, before insert, after insert, before update, after update) {

    if(Trigger.isBefore) {
        if (Trigger.isInsert /*&& PAD.canTrigger('ProjectProductBeforeInsert')*/) {
            ProjectProductTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate /*&& PAD.canTrigger('ProjectProductBeforeUpdate')*/) {
                
            if(ProjectProductChildTriggerHandler.isBlankingFields){
                return;
            }

            ProjectProductTriggerHandler.handleBeforeUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter) {
        if (Trigger.isInsert /*&& PAD.canTrigger('ProjectProductAfterInsert')*/) {
            ProjectProductTriggerHandler.handleAfterInsert(Trigger.newMap);
        }
        else if (Trigger.isUpdate /*&& PAD.canTrigger('ProjectProductAfterUpdate')*/) {

            ProjectProductTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}

/** PAD TO DO **/