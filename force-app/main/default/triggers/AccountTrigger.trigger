trigger AccountTrigger on Account (before delete, after undelete) {

    if (Trigger.isBefore && Trigger.isDelete) {
        if (PAD.canTrigger('AccountBeforeDelete')) {
            AccountTriggerHandler.handleBeforeDelete(Trigger.oldMap);
        }
    }
}