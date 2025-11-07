/**
* @author Abderrahmane TRIA
* @date Creation 07/04/2020
* @group TriggerHandler
* @description Trigger Handler Legal Entity
*/
public class LegalEntityTriggerHandler implements ITriggerHandler{

    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        //check here for uppercase name
        UTIL_LegalEntity.toUppercaseName((List<Legal_Entity__c>) newItems);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        //check here for uppercase name
        UTIL_LegalEntity.toUppercaseName((List<Legal_Entity__c>) newItems.values());
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
        //Call webservice UME and GLEIF to retrieve info by LEIs
        if (!System.isBatch()) {
            LegalEntityAP01.callLegalEntityWebservices((List<Legal_Entity__c>) newItems.values());
        }
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        if(PAD.canTrigger('LegalEntityTrigger')) {return triggerDisabled;}
        else {return true;}
    }
}