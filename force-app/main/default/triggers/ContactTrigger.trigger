trigger ContactTrigger on Contact (after insert, after update, after undelete, before delete, before insert, before update, after delete) {
    TriggerDispatcher.run(new ContactTriggerHandler());
}