trigger AgreementTrigger on Convention__c (after insert, before insert, before update,after update, before delete, after delete) {
    TriggerDispatcher.Run(new AgreementTriggerHandler());
}