trigger CampaignMemberTrigger on CampaignMember (before insert, after insert, before update, after update, before delete, after delete, after undelete) {

	TriggerDispatcher.run(new SM016_CampaignMemberTriggerHandler());


}