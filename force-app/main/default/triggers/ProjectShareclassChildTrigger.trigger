trigger ProjectShareclassChildTrigger on ProjectShareclassChild__c (before insert, after insert, before update, after update , after delete , before delete) {
    
    if(Trigger.isBefore) {
        if (Trigger.isInsert /*&& PAD.canTrigger('ProjectShareclassChildBeforeInsert')*/) {
            ProjectShareclassChildTriggerHandler.handleBeforeInsert(Trigger.new);
        }
         if (Trigger.isUpdate /*&& PAD.canTrigger('ProjectShareclassChildBeforeUpdate')*/) {
            ProjectShareclassChildTriggerHandler.handleBeforeUpdate(Trigger.newMap, Trigger.oldMap);
        }
        if (Trigger.isDelete ) {
            ProjectShareclassChildTriggerHandler.handleBeforeDelete(Trigger.oldMap);
        }
    }
     if (Trigger.isAfter) {
        if (Trigger.isInsert /*&& PAD.canTrigger('ProjectShareclassChildAfterInsert')*/) {
            ProjectShareclassChildTriggerHandler.handleAfterInsert(Trigger.newMap);
        }
        if (Trigger.isUpdate /*&& PAD.canTrigger('ProjectShareclassChildAfterUpdate')*/) {
            ProjectShareclassChildTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
       
    }
}

/** PAD TO DO **/