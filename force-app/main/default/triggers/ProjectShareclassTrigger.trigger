trigger ProjectShareclassTrigger on ProjectShareclass__c (after undelete, before delete, before insert, after insert, before update, after update) {
    if(Trigger.isBefore) {
        if (Trigger.isInsert ) {
            ProjectShareclassTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate ) {
            ProjectShareclassTriggerHandler.handleBeforeUpdate(Trigger.newMap, Trigger.oldMap);
        }
        else if (Trigger.isDelete ) {
            ProjectShareclassTriggerHandler.handleBeforeDelete(Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter) {
        if (Trigger.isInsert ) {
            ProjectShareclassTriggerHandler.handleAfterInsert(Trigger.newMap);
        }
        else if (Trigger.isUpdate ) {
            ProjectShareclassTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);   
        }
    }
}