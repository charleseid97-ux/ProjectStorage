/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 27-12-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
global class BATCH_CloseCampaignLyytiScheduler implements Schedulable {
    
    global void execute(SchedulableContext SC) {
        BATCH_CloseCampaignLyyti b = new BATCH_CloseCampaignLyyti();
        Database.executebatch(b, 50);
     }
    
}