/**
 * Created by noorg on 04/06/2021.
 */

public with sharing class SM033_KYD_DD_OversightTriggerHandler implements  ITriggerHandler{
    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {  }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) { }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) { }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        System.debug('//NGO SM033_KYD_DD_OversightTriggerHandler  AfterUpdate'+newItems);
        SM033_KYD_DD_OversightService.updateKYDDocumentsLevel((Map<Id, KYD_Due_Diligence_Oversight__c>) newItems, (Map<Id, KYD_Due_Diligence_Oversight__c>)oldItems);

    }

    public void AfterDelete(Map<Id, SObject> oldItems) {  }

    public void AfterUndelete(Map<Id, SObject> oldItems) {  }

    public Boolean IsDisabled() {
        return triggerDisabled;
    }
}