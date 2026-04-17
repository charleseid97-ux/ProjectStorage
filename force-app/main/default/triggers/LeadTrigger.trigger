trigger LeadTrigger on Lead (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    TriggerDispatcher.run(new SM017_LeadTriggerHandler());
}