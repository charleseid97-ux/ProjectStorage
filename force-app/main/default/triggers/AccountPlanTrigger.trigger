trigger AccountPlanTrigger on Account_Plan__c (before insert) {

    if(Trigger.isBefore && Trigger.isInsert) {
        AccountPlanTriggerHandler.beforeInsert(Trigger.New);
    }
}