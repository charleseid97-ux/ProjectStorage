trigger customEventTrigger on Event__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    before delete,
    after undelete
) {
    TriggerDispatcher.Run(new customEventHandler());
}