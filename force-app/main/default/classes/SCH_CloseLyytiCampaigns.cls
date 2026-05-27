public with sharing class SCH_CloseLyytiCampaigns implements Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BATCH_FindCampaignsToCloseLyyti(), 10);
    }
}