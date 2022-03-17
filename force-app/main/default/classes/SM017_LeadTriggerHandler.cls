/** 
* @author: Briag Guemard
* @date : Creation 04/04/2017
* @date : Modification 04/04/2017
* @description : This Class allows to handle trigger events in contact entity.
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-OCT-2019  Noor         1.0    Update handler to cater for website prospace V2
*
*/
public class SM017_LeadTriggerHandler implements ITriggerHandler{

    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {

        if (PAD.canTrigger('LeadBeforeInsert')) {

            boolean isWebsiteUser = UserInfo.getUserId() == Label.WebsiteProspaceId;

            if(!Pad.SKIP_STRIGGER_MAP.containsKey('initializeNewLeadFromWebSite') && isWebsiteUser) SM026_Lead_Website.initializeNewLeadFromWebSite((List<Lead>) newItems);

            if(!Pad.SKIP_STRIGGER_MAP.containsKey('updateTechnicalId')) updateTechnicalId((List<Lead>) newItems);
        }
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        if (PAD.canTrigger('LeadBeforeUpdate')) {
            boolean isWebsiteUser = UserInfo.getUserId() == Label.WebsiteProspaceId;
            if(!Pad.SKIP_STRIGGER_MAP.containsKey('updateLeadOwner') && !isWebsiteUser) SM026_Lead_Website.updateLeadOwner((Map<Id, Lead>) newItems, (Map<Id, Lead>) oldItems);
            if(!Pad.SKIP_STRIGGER_MAP.containsKey('initializeExistingLeadFromWebSite') && isWebsiteUser) SM026_Lead_Website.initializeExistingLeadFromWebSite((Map<Id, Lead>) newItems, (Map<Id, Lead>) oldItems);
        }
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
    }



    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        if (PAD.canTrigger('LeadAfterUpdate')) {

            boolean isNotWebsiteUser = UserInfo.getUserId() != Label.WebsiteProspaceId;

            if(!Pad.SKIP_STRIGGER_MAP.containsKey('sendAsyncWebsiteLead') && isNotWebsiteUser) SM026_Lead_Website.sendAsyncWebsiteLead((Map<Id, Lead>) newItems, (Map<Id, Lead>) oldItems);

            if(!Pad.SKIP_STRIGGER_MAP.containsKey('processConvertedLead')) SM026_Lead_Website.processConvertedLead((Map<Id, Lead>) newItems);

            //if(!Pad.SKIP_STRIGGER_MAP.containsKey('updateCampaignMembersForLead')) updateCampaignMembersForLead((List<Lead>) newItems.values());

            if(!Pad.SKIP_STRIGGER_MAP.containsKey('deleteLeadAlerts')) SM026_Lead_Website.deleteLeadAlerts((List<Lead>) newItems.values(), (Map<Id, Lead>) oldItems);

        }
    }


    public void AfterDelete(Map<Id, SObject> oldItems) {
    }


    public void AfterUndelete(Map<Id, SObject> newItems) {
    }

    public Boolean IsDisabled() {
        if(PAD.canTrigger('LeadTrigger')) return triggerDisabled;
        else return true;
    }

    /*
    * Old code to be analysed and moved from the handler
    */
    public static void updateCampaignMembersForLead(List<Lead> leads) {

        List<String> LeadIds = new List<String>();
        list<CampaignMember> listCMToUpdate = new list<CampaignMember>();

        //Check if interface user
        if (!ObjectUtil.isAccountServiceUser()) {
            for (Lead l : leads) {
                LeadIds.add(l.Id);
            }
        }

        listCMToUpdate = EM015_CampaignMember.getListByLeadIds(LeadIds);
        if (listCMToUpdate != null && listCMToUpdate.size() > 0) {
            update listCMToUpdate;
        }
        Pad.SKIP_STRIGGER_MAP.put('updateCampaignMembersForLead', 'prevent double execution');
    }



    /*
    *  Method to update the technical Id of lead each time it is created
    */
    public static void updateTechnicalId(List<Lead> newItems) {
        //Get custom settings which store the last Technical id for Lead/Contact
        Id_Tech_Sun_Legacy__c setting = Id_Tech_Sun_Legacy__c.getAll().get('Sun_ID');
        system.debug('Id_Tech_Sun_Legacy__c = ' + Id_Tech_Sun_Legacy__c.getAll().get('Sun_ID'));

        for (Lead l : newItems) {
            if (l.Technical_ID__c == null && setting != null) {
                l.Technical_ID__c = setting.Sun_ID__c;
                system.debug(setting.Sun_ID__c);
                setting.Sun_ID__c = setting.Sun_ID__c + 1;
            }
        }
        //Update incremental value in custom settings
        if(setting != null){
            update setting;
        }
    }

}