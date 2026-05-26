public with sharing class SCH_RecalculateCampaignMemberKPI implements Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BATCH_RecalculateContactParticipationKPI(), 50);
    }
}