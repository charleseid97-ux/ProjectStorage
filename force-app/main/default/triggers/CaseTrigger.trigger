trigger CaseTrigger on Case (after insert, after update) {
    TriggerDispatcher.run(new CaseTriggerHandler());
}