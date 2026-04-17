trigger MilestoneTrigger on Milestone__c (after undelete, before delete, before insert, after insert, before update, after update) {
    if(Trigger.isBefore) {
        if (Trigger.isInsert /*&& PAD.canTrigger('MilestoneBeforeInsert')*/) {
            MilestoneTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate /*&& PAD.canTrigger('MilestoneBeforeUpdate')*/) {
            MilestoneTriggerHandler.handleBeforeUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter) {
        if (Trigger.isInsert /*&& PAD.canTrigger('MilestoneAfterInsert')*/) {
            MilestoneTriggerHandler.handleAfterInsert(Trigger.newMap);
        }
        else if (Trigger.isUpdate /*&& PAD.canTrigger('MilestoneAfterUpdate')*/) {
            MilestoneTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}