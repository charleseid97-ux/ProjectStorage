/**
 * Created by Saad on 02/05/2022.
 */
public class CaseTriggerHandler implements ITriggerHandler{
    
    
    public void BeforeInsert(List<SObject> newItems) {
    }

    public void BeforeUpdate( Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Case> newCases =(Map<Id, Case>) newItems;
        Map<Id, Case> oldCases = (Map<Id, Case>) oldItems;
        List<Case> closedCase = new List<Case>();
        CaseTranslationProcess.switchTranslationToPublication(newCases, oldCases) ;

    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterInsert(Map<Id, SObject> newItems) {
        
        Map<Id, Case> caseMap = (Map<Id, Case>) newItems;
        List<Id> caseWithNDA = new List<Id>();
        List<Case> translationCases = new List<Case>();
        List<Case> subTranslationCases = new List<Case>();
        Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();
        Id subTranslationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId();

        for (Case c : caseMap.values()) {
            if (c.NDA__c != null) {
                caseWithNDA.add(c.id);
            }
            
            if(c.RecordTypeId == translationRecordTypeId) {
                translationCases.add(c);
            }

            if(c.RecordTypeId == subTranslationRecordTypeId && c.Translation_mode__c == 'Translation Agencies' ) {
                subTranslationCases.add(c);
            }
        }

        if(translationCases.size() > 0) {
            CaseTranslationProcess.createChildCases(translationCases);
        }
        
        caseAP01.addCompanyToNDA(caseMap);
        caseAP01.addProductsToNDA(caseWithNDA);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Case> newCases = (Map<Id, Case>) newItems;
        Map<Id, Case> oldCases = (Map<Id, Case>) oldItems;
        List<Id> caseWithNDA = new List<Id>();
        List<Case> closedCase = new List<Case>();
        Id subTranslationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId();

        for (Case c : newCases.values()) {
            if (c.NDA__c != null && c.NDA__c != oldCases.get(c.id).NDA__c) {
                caseWithNDA.add(c.id);
            }
            if(c.Status =='Closed' && c.Status != oldCases.get(c.id).Status && c.RecordTypeId == subTranslationRecordTypeId && c.Translation_Request_Type__c !='Translation Only') {
                closedCase.add(c);
            }
        }
        if(closedCase.size() > 0) {
            CaseTranslationProcess.createChildCases(closedCase);
        }
        caseAP01.addCompanyToNDA(newCases, oldCases);
        caseAP01.addProductsToNDA(caseWithNDA);
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        
            return false;
        
    }

}