/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 04-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public  class DigitalInteractionDetailsTriggerHandler  implements ITriggerHandler{

    public void BeforeInsert(List<SObject> newItems) {
        DigitalInteractionDetailsTriggerService.extractFundName(newItems,null);
    }

    public void BeforeUpdate( Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Digital_Interaction_Details__c> newDID =(Map<Id, Digital_Interaction_Details__c>) newItems;
        Map<Id, Digital_Interaction_Details__c> oldDID = (Map<Id, Digital_Interaction_Details__c>) oldItems;
        DigitalInteractionDetailsTriggerService.extractFundName(newDID.values(),oldDID);
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
        return false;
    }

}