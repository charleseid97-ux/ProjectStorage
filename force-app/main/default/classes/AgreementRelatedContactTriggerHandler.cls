/**
 * @author JLC
 *
 * @date
 *
 */
public class AgreementRelatedContactTriggerHandler  extends TH_TriggerHandler implements ITriggerHandler{

    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public Boolean IsDisabled() {
        if(PAD.canTrigger('AgreementRelatedContactTrigger')) return triggerDisabled;
        else return true;
    }

    public void BeforeInsert(List<SObject> newItems) {}

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}

    public void BeforeDelete(Map<Id, SObject> oldItems) {

        AgreementRelatedContact_SM01.removeRelatedContactOnAgreement((Map<Id, ConventionRelatedContact__c>) oldItems);
    }

    public void AfterInsert(Map<Id, SObject> newItems) {

        AgreementRelatedContact_SM01.updateContactOnAgreement((Map<Id, ConventionRelatedContact__c>) newItems);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        AgreementRelatedContact_SM01.updateContactOnAgreement((Map<Id, ConventionRelatedContact__c>) newItems);
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
        //AgreementRelatedContact_SM01.removeRelatedContactOnAgreement((Map<Id, ConventionRelatedContact__c>) oldItems);
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {}

}