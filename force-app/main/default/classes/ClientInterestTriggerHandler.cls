public with sharing class ClientInterestTriggerHandler implements ITriggerHandler {


    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {}

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}

    public void BeforeDelete(Map<Id, SObject> oldItems) {}

    public void AfterInsert(Map<Id, SObject> newItems) {
        ClientInterestToPreferenceCenter.updateContacts(newItems);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        ClientInterestToPreferenceCenter.updateContacts(newItems);
    }
    
    public void AfterDelete(Map<Id, SObject> oldItems) {}

    public void AfterUndelete(Map<Id, SObject> oldItems) {}

    public Boolean isDisabled() {
        return false;
    }
}