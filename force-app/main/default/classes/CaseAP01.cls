/**
 * Created by Saad on 02/05/2022.
 */

public with sharing class CaseAP01
{
    public static void addProductsToNDA(List<Id> caseList) {
    	List<Case_Product__c> itemsList = [SELECT Share_Class__c, CurrencyIsoCode, Work_Together_Process__r.NDA__c, Work_Together_Process__r.NDA__r.Related_NDA__c, ShareClass__c
                                           FROM Case_Product__c
                                           WHERE Work_Together_Process__c in :caseList];
        CaseProductHelper.addCaseProductToNDA(itemsList);
    }
    
    public static void addCompanyToNDA(Map<Id, Case> newItems) {
        
        Map<Id, Id> ndaAccount = new Map<Id, Id>();
        for (Case c : newItems.values()) {
            if (c.NDA__c != null && c.AccountId != null) {
            	ndaAccount.put(c.NDA__c, c.AccountId);
            }
        }
        
        List<NDA__c> ndaList = [SELECT id, Company__c FROM NDA__c WHERE id in :ndaAccount.keySet()];
        List<NDA__c> ndaToUpdate = new List<NDA__c>();
        
        for (NDA__c nda : ndaList) {
            if (nda.Company__c != ndaAccount.get(nda.id)) {
                nda.Company__c = ndaAccount.get(nda.id);
                ndaToUpdate.add(nda);
            }
        }
        
        update ndaToUpdate;
    }
    
    public static void addCompanyToNDA(Map<Id, Case> newItems, Map<Id, Case> oldItems) {
        Map<Id, Case> caseWithNda = new Map<Id, Case>();
        for (Case c : newItems.values()) {
            if (c.NDA__c != oldItems.get(c.Id).NDA__c || c.AccountId != oldItems.get(c.Id).AccountId) {
                caseWithNda.put(c.Id, c);
            }
        }
        addCompanyToNDA(caseWithNDA);
    }
}