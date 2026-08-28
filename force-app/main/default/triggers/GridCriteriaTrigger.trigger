trigger GridCriteriaTrigger on GridCriteria__c (before insert, after insert, before update, after update, after delete, before delete, after undelete) {
    TriggerDispatcher.Run(new GridCriteriaTriggerHandler());
}
