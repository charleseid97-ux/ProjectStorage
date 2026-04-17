/** 
* @author: Adolphe SONKO
* @date : Creation 14/03/2017
* @date : Modification 13/07/2017 (Bug Fix Category)
* @description : This Class allows to handle trigger events in campaign member entity.
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 08-AVR-2019  JLC         1.1    #15844 prevent recursive update on contact when updating a campaign member
* -- 16-MAY-2019  JLC         1.2    #15844 prevent sending campaign member when campaign is closed
*
*/

public class SM016_CampaignMemberTriggerHandler implements ITriggerHandler {

    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    private static String  CLASS_NAME = SM016_CampaignMemberTriggerHandler.class.getName();    


    public void BeforeInsert(List<SObject> newItems) {
        if(PAD.canTrigger('CampaignMemberBeforeInsert')){

            SM016_CampaignMemberService.checkUnicity((List<CampaignMember>) newItems);
			SM016_CampaignMemberService.blockOptOutEvent((List<CampaignMember>) newItems);
            //TODO delete workflow CampaignMember_WF002_EventOptOutatCreation
            //SM016_CampaignMemberService.intializeCampaignMember((List<CampaignMember>) newItems);
            //SM016_CampaignMemberService.flagCampaignMemberAsSubscriber((List<CampaignMember>) newItems);

        }
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        //if (PAD.canTrigger('CampaignMemberBeforeUpdate')) { }
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
        //call WS Lyyti to send campaign members
        SM016_CampaignMemberService.sendCallWSLyyti((List<CampaignMember>) newItems.values(), null);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        if(PAD.canTrigger('CampaignMemberAfterUpdate')) {
            String methodName = 'onAfterUpdate';
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campMembers] : ' + newItems);

            List<CampaignMember> membersWithOtherFields = [SELECT Id, Subscriber__c,Status, Category_Event_lookup__c, Event_Email__c, FirstName,
                    LastName, Salutation, Job_Title__c, Company_T__c, Address_Line_1__c, City__c, Country__c, Zip__c,
                    Phone__c, Mobile__c, Language__c, Contact_Owner__c, Owner_email__c, Last_Etouches_action_synchronized__c, TECH_ID_Subscriber__c,
                    Campaign.Event_code_Etouches__c, Campaign.TECH_Mailing_List_ID_Etouches__c,  Campaign.Status, Contact.Subscriber__c,
                    Lead.HasOptedOutOfEmail, Campaign.Type, Campaign.End_Date_Time__c,TECH_IS_MEMBER_TO_BE_DELETED__c
            FROM CampaignMember WHERE Id IN : (List<CampaignMember>) newItems.values()];

            //Update lead and Contact EventOptOut from CampaignMember Event OptOut
            SM016_CampaignMemberService.updateEventOptOut((List<CampaignMember>) newItems.values(), (Map<Id, CampaignMember>) oldItems);

            //Update Contact fields lastEvent from Campaign
            SM016_CampaignMemberService.updateLastFieldEvent( membersWithOtherFields,(Map<Id, CampaignMember>) oldItems);

            //call WS Lyyti to send campaign members
            SM016_CampaignMemberService.sendCallWSLyyti((List<CampaignMember>) newItems.values(), (Map<Id, CampaignMember>) oldItems);
            
            //Send update to Aventri
            //SM016_CampaignMemberService.callUpdateSubscriber( (List<CampaignMember>) newItems.values(),(Map<Id, CampaignMember>) oldItems);
        }
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {

       /* if(PAD.canTrigger('CampaignMemberAfterDelete')) {
            String methodName = 'onAfterDelete';
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [campMembers] : ' + oldItems);
            List<String> campaign_member_to_delete = new List<String>();

            for (CampaignMember cm : (List<CampaignMember>) oldItems.values()) {
                if ( cm.TECH_ID_Subscriber__c != null) {
                    if (cm.TECH_ID_Subscriber__c != null) {
                        campaign_member_to_delete.add(cm.TECH_ID_Subscriber__c);
                    }
                }
            }
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [campaign_member_to_delete] : ' + campaign_member_to_delete);

            if (campaign_member_to_delete.size() > 0) System.enqueueJob(new SM016_CallDeleteSubscriberEtouchesAsync(campaign_member_to_delete, 0, 99));
        }*/
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        if(!PAD.byPassCampaignMemberTriggerHandler) return triggerDisabled;
        else return true;
    }
}