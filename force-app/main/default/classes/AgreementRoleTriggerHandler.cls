/**
 * Created by noorgoolamnabee on 17/12/2021.
 */

public with sharing class AgreementRoleTriggerHandler implements ITriggerHandler {


    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        AgreementRoleService.checkUniqueness((List<Agreement_Role__c>) newItems);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}

    public void BeforeDelete(Map<Id, SObject> oldItems) {}

    public void AfterInsert(Map<Id, SObject> newItems) {}

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}

    public void AfterDelete(Map<Id, SObject> oldItems) {}

    public void AfterUndelete(Map<Id, SObject> oldItems) {}

    public Boolean isDisabled() {
        if(PAD.canTrigger('AgreementTriggerHandler')) {return triggerDisabled;}
        else {return true;}
    }
}