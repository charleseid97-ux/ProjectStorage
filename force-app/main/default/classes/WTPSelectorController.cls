/**
 * Created by Saad LOZZI on 07/12/2021.
 */

public with sharing class WTPSelectorController {

    @AuraEnabled
    public static String getRelatedShares(List<Id> productsIds, Id recordId) {
        List<Share_Class__c> relatedShares = [SELECT Id, ISIN_Code__c, Name, Fund__r.FundStrategy__r.Name, Fund__r.Name
                                              FROM Share_Class__c
                                              WHERE Fund__c IN : productsIds];

        Set<Id> existingSharesIds = getExistingSharesIds(recordId);
        List<Share> shares = new List<Share>();
        for(Share_Class__c share : relatedShares) {
            Share aShare = new Share();
            aShare.name = share.Name;
            aShare.codeISIN = share.ISIN_Code__c;
            aShare.strategyName = share.Fund__r.FundStrategy__r.Name;
            aShare.fundName = share.Fund__r.Name;
            aShare.id = share.Id;
            aShare.checked = existingSharesIds.contains(share.Id) ? true : false;

            shares.add(aShare);
        }

        return JSON.serialize(shares);
    }

    public static Set<Id> getExistingSharesIds(Id recordId) {
        List<Case_Share__c> existingSharesIds = [SELECT Share_Class__c
                                                 FROM Case_Share__c
                                                 WHERE Work_Together_Process__c = :recordId];

        Set<Id> shareSet = new Set<Id>();
        for(Case_Share__c wtpShare : existingSharesIds) {
            shareSet.add(wtpShare.Share_Class__c);
        }

        return shareSet;
    }

    public class Share {
        public String id;
        public String name;
        public String fundName;
        public String strategyName;
        public String codeISIN;
        public Boolean checked;
    }
}