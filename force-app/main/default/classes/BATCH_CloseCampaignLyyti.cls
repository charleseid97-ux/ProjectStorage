/**
* @description       : 
* @author            : Khadija EL GDAOUNI
* @group             : 
* @last modified on  : 30-12-2024
* @last modified by  : Khadija EL GDAOUNI
**/
public class BATCH_CloseCampaignLyyti implements Database.Batchable<sObject>, Database.AllowsCallouts{
    
    public Database.QueryLocator start(Database.BatchableContext BC) {

        String todayStr = formatDate(Date.today()); // YYYY/MM/DD
        
        return Database.getQueryLocator([ 
            SELECT Id, Name, Event_Local_End_Time__c, Status, (
                SELECT Id, Status, Cancelled__c 
                FROM CampaignMembers 
                WHERE Cancelled__c = true) 
            FROM Campaign 
            WHERE Status != 'Closed' 
            AND LyytiId__c!=null 
            AND Event_Local_End_Time__c LIKE :todayStr + '%'
            ORDER BY Event_Local_End_Time__c ASC ]);
    }
    
    
    public void execute(Database.BatchableContext BC, List<Campaign> campaigns) {
        List<Campaign> campaignsToUpdate = new List<Campaign>();
        List<CampaignMember> membersToUpdate = new List<CampaignMember>();

        String todayStr = formatDate(Date.today());
        
        for (Campaign campaign : campaigns) {
            if (String.isBlank(campaign.Event_Local_End_Time__c)) continue;
                        
            String campaignDateStr = campaign.Event_Local_End_Time__c.substringBefore(' ');

                if (campaignDateStr == todayStr) {
                    campaign.Status = 'Closed';
                    campaignsToUpdate.add(campaign);
                    
                    for (CampaignMember member : campaign.CampaignMembers) {
                        member.Status = 'Cancelled';
                        membersToUpdate.add(member);
                    }
                }
            
            
        }

        if (!membersToUpdate.isEmpty()) {
            Database.SaveResult[] srMembers = Database.update(membersToUpdate, false);
        }
        
        if (!campaignsToUpdate.isEmpty()) {
            Database.SaveResult[] srCampaigns = Database.update(campaignsToUpdate, false);
        }
        
    }
    
    public void finish(Database.BatchableContext BC) {
        
    }
    
    public  String formatDate(Date d) { 
        String year = String.valueOf(d.year()); 
        String month = (d.month() < 10 ? '0' : '') + String.valueOf(d.month()); 
        String day = (d.day() < 10 ? '0' : '') + String.valueOf(d.day()); 
        return year + '/' + month + '/' + day; 
    }
    
    
}