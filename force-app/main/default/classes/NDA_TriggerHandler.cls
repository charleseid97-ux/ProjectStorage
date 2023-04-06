/**
* @author MNFR
* @date Creation 07/04/2022
* @group TriggerHandler
* @description Trigger Handler NDA
*/

public class NDA_TriggerHandler implements ITriggerHandler{
    
    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {

    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        if(PAD.canTrigger('NDATrigger')) {return triggerDisabled;}
        else {return true;}
    }

}