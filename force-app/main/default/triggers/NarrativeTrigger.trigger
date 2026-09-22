rigger NarrativeTrigger on Narrative__c ( before insert, before update) {
    TriggerDispatcher.Run(new NarrativeTriggerHandler());
}