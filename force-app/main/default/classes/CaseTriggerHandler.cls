/**
 * Created by Saad on 02/05/2022.
 */
public class CaseTriggerHandler implements ITriggerHandler{
    
    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
        Map<Id, Case> caseMap = (Map<Id, Case>) newItems;
        List<Id> caseWithNDA = new List<Id>();
        
        for (Case c : caseMap.values()) {
            if (c.NDA__c != null) {
                caseWithNDA.add(c.id);
            }
        }
        
        caseAP01.addCompanyToNDA(caseMap);
        caseAP01.addProductsToNDA(caseWithNDA);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Case> newCases = (Map<Id, Case>) newItems;
        Map<Id, Case> oldCases = (Map<Id, Case>) oldItems;
        List<Id> caseWithNDA = new List<Id>();
        
        for (Case c : newCases.values()) {
            if (c.NDA__c != null && c.NDA__c != oldCases.get(c.id).NDA__c) {
                caseWithNDA.add(c.id);
            }
        }
        
        caseAP01.addCompanyToNDA(newCases, oldCases);
        caseAP01.addProductsToNDA(caseWithNDA);
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        if (PAD.canTrigger('NDATrigger')) {
            return triggerDisabled;
        }
        else {
            return true;
        }
    }

}