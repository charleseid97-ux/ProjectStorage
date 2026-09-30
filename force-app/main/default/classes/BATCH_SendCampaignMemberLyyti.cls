/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 30-SEP-2026
 * @last modified by  : Charles EID
**/
public class BATCH_SendCampaignMemberLyyti implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {

    public void execute(SchedulableContext SC) {
        Database.executebatch(new BATCH_SendCampaignMemberLyyti(), 1);
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, CampaignId, FirstName, Campaign.Tech_ParticipantType__c, Cancelled__c, Category_Event_lookup__r.Name, Campaign.LyytiId__c,
                                                LastName, Email, Status, LyytiId__c, Contact.Owner.Name, Lead.Owner.Name, Language__c, CompanyOrAccount, LastModifiedBy.Username, Category_name__c  
                                            FROM CampaignMember  
                                            WHERE LyytiId__c = null 
                                            AND Campaign.LyytiId__c != null 
                                            AND Campaign.Tech_ParticipantType__c!= null 
                                            AND Campaign.Status != 'Closed']);
    }

    public void execute(Database.BatchableContext BC, List<CampaignMember> scope) {
        List<CampaignMember> cmToUpdate = new List<CampaignMember>();
        for (CampaignMember cm : scope) {
            String lyytiId;
            if (cm.Status == 'Invited') {
                WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'notreacted', null, null);            
                sender.sendInDataToExternalService();
                lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;
            }
            else if (cm.Status == 'Declined') {
                WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'reactedno', null, null);            
                sender.sendInDataToExternalService();
                lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;
            }
            else if (cm.Status == 'Attended') {
                WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'show', null, null);            
                sender.sendInDataToExternalService();
                lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;
            }
            else if (cm.Status == 'No Show') {
                WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'noshow', null, null);            
                sender.sendInDataToExternalService();
                lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;
            } 
            else if (cm.Status == 'Confirmed') {
                if(cm.LastModifiedBy.Username != System.label.Username_Lyyti){
                    if(cm.LyytiId__c == null){
                        WS_SendCampaignMembers sender1 = new WS_SendCampaignMembers(cm, 'notreacted', null, null);            
                        sender1.sendInDataToExternalService();
                        lyytiId = sender1.uid !=null ? String.valueOf(sender1.uid):null;

                        if (lyytiId != null) {
                            WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'reactedyes', lyytiId);            
                            sender.sendInDataToExternalService();

                            WS_SendConfirmationLyyti sendConfirm = new WS_SendConfirmationLyyti(lyytiId);            
                            sendConfirm.sendInDataToExternalService();
                        }
                    }
                }
            }

            if(lyytiId!=null){
                cm.LyytiId__c = lyytiId;
                cmToUpdate.add(cm);
            }
        }
        if(cmToUpdate.size()>0){
            update cmToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC) { }

}