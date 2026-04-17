trigger ClientInterestTrigger on ClientInterest__c (before insert, before update, after insert, after update, after delete,before delete, after undelete) {
    TriggerDispatcher.run(new ClientInterestTriggerHandler());
}