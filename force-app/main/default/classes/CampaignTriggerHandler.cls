/**
 * Created by noorgoolamnabee on 08/11/2022.
 */

public with sharing class CampaignTriggerHandler implements ITriggerHandler{

    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        //Update campaign Name
        CampaignService.defineCampaignName((List<Campaign>) newItems);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        //Update campaign Name
        CampaignService.updateCampaignName((List<Campaign>) newItems.values(), (Map<Id, Campaign>) oldItems);

    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
        CampaignService.sendCampaignLyyti((List<Campaign>) newItems.values(), null);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        CampaignService.sendCampaignLyyti((List<Campaign>) newItems.values(), (Map<Id, Campaign>) oldItems);
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        if(PAD.canTrigger('CampaignTrigger')) {return triggerDisabled;}
        else {return true;}
    }
}