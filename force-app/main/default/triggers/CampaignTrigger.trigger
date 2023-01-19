trigger CampaignTrigger on Campaign (after insert, after update, after undelete, before delete, before insert, before update) {

    TriggerDispatcher.run(new CampaignTriggerHandler());
}