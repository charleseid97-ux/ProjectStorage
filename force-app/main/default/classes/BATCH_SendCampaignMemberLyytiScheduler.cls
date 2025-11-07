global class BATCH_SendCampaignMemberLyytiScheduler implements Schedulable {
    
    global void execute(SchedulableContext SC) {
        BATCH_SendCampaignMemberLyyti b = new BATCH_SendCampaignMemberLyyti();
        Database.executebatch(b, 50);
     }
    
}