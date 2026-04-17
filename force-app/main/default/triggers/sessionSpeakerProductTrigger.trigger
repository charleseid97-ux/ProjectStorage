trigger sessionSpeakerProductTrigger on SessionSpeakerProduct__c (before insert, before update, after insert, after update, after delete, before delete, after undelete) {
    TriggerDispatcher.Run(new SessionSpeakerProductHandler());
}