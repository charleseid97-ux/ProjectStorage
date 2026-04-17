/**
 * Created by Saad LOZZI on 07/12/2021.
 */

public with sharing class WTPSelectorController
{
    public class Share
    {
        public String id;
        public String name;
        public String fundName;
        public String strategyName;
        public String codeISIN;
        public Boolean checked;
    }
    @AuraEnabled
    public static String getRelatedShares(List<Id> productsIds, Id recordId)
    {
        System.debug('SLI products >> ' + productsIds);
        System.debug('SLI recordId >> ' + recordId);

        Set<Id> existingSharesIds = getExistingSharesIds(recordId);

        List<Share> shares = new List<Share>();

        List<Share_Class__c> relatedShares = [
                SELECT Id, ISIN_Code__c, Name, Fund__r.Strategy__r.Name, Fund__r.Name
                FROM Share_Class__c
                WHERE (
                        Fund__r.Strategy__c IN : productsIds
                        OR
                        Fund__c IN : productsIds
                )
        ];

        for(Share_Class__c share : relatedShares)
        {
            Share aShare = new Share();
            aShare.name = share.Name;
            aShare.codeISIN = share.ISIN_Code__c;
            aShare.strategyName = share.Fund__r.Strategy__r.Name;
            aShare.fundName = share.Fund__r.Name;
            aShare.id = share.Id;
            aShare.checked = existingSharesIds.contains(share.Id) ? true : false;

            shares.add(aShare);
        }

        return JSON.serialize(shares);
    }
    /*@AuraEnabled
    public static void saveProducts(List<Object> products, Id workTogetherProcessId)
    {
        List<Map<String, String>> productsList = (List<Map<String, String>>) products;
        Set<String> productNames = getProductNames(productsList);
        Set<String> existingProductNames = getExistingProductNames(workTogetherProcessId);
        deleteProducts(existingProductNames, productNames);
        insertProducts(productsList, workTogetherProcessId);
    }
    @AuraEnabled
    public static void saveShares(List<Id> shareIds, Id workTogetherProcessId)
    {
        Set<Id> shareIdSet = new Set<Id>(shareIds);
        Set<Id> existingShareIds = getExistingShareSet(workTogetherProcessId);
        deleteCaseShares(shareIdSet, existingShareIds);
        insertCaseShares(shareIdSet, existingShareIds, workTogetherProcessId);
    }

    private static Set<String> getProductNames(List<Map<String, String>> productsList)
    {
        Set<String> productsNames = new Set<String>();

        for(Map<String, String> product : productsList)
        {
            productsNames.add(product.get('Name'));
        }

        return productsNames;
    }

    private static Set<String> getExistingProductNames(Id workTogetherProcessId)
    {
        Set<String> existingNames = new Set<String>();

        List<Work_Together_Process_Product__c> products = [
                SELECT Id, Name
                FROM Work_Together_Process_Product__c
                WHERE Work_Together_Process__c = : workTogetherProcessId
        ];

        for(Work_Together_Process_Product__c product : products)
        {
            existingNames.add(product.Name);
        }

        return existingNames;
    }

    private static void deleteProducts(Set<String> productNames, Set<String> existingProductNames)
    {
        Set<String> deletedNames = new Set<String>();

        for(String existingProductName : existingProductNames)
        {
            if(!productNames.contains(existingProductName))
            {
                deletedNames.add(existingProductName);
            }
        }

        delete [SELECT Id FROM Work_Together_Process_Product__c WHERE Name IN : deletedNames];
    }

    private static void insertProducts(List<Map<String, String>> productsList, Id workTogetherProcessId)
    {
        List<Work_Together_Process_Product__c> productsToCreate = new List<Work_Together_Process_Product__c>();

        for(Map<String, String> product : productsList)
        {
            if(product.get('Id') != null)
            {
                Work_Together_Process_Product__c aProduct = new Work_Together_Process_Product__c();

                aProduct.Product__c = product.get('Id');
                aProduct.Name = product.get('Name');
                aProduct.Work_Together_Process__c = workTogetherProcessId;

                productsToCreate.add(aProduct);
            }
        }
        insert productsToCreate;
    }

    private static Set<Id> getExistingShareSet(Id workTogetherProcessId)
    {
        Set<Id> shareSet = new Set<Id>();

        List<Case_Share__c> existingCaseShares = [
                SELECT Id
                FROM Case_Share__c
                WHERE Work_Together_Process__c = :workTogetherProcessId
        ];

        for(Case_Share__c existingCaseShare : existingCaseShares)
        {
            shareSet.add(existingCaseShare.Share_Class__c);
        }

        return shareSet;
    }

    public static void deleteCaseShares(Set<Id> caseShareSet, Set<Id> existingCaseSharesId)
    {
        Set<Id> caseSharesToDelete = new Set<Id>();

        for(Id existingCaseShareId : existingCaseSharesId)
        {
            if(!caseShareSet.contains(existingCaseShareId))
            {
                caseSharesToDelete.add(existingCaseShareId);
            }
        }

        Database.delete(new List<Id>(caseSharesToDelete));
    }

    public static void insertCaseShares(Set<Id> caseShareSet, Set<Id> existingCaseSharesId, Id workTogetherProcessId)
    {
        List<Case_Share__c> caseSharesToCreate = new List<Case_Share__c>();

        for(Id caseShareId : caseShareSet)
        {
            if(!existingCaseSharesId.contains(caseShareId))
            {
                Case_Share__c caseShare = new Case_Share__c();
                caseShare.Work_Together_Process__c = workTogetherProcessId;
                caseShare.Share_Class__c = caseShareId;

                caseSharesToCreate.add(caseShare);
            }
        }

        insert caseSharesToCreate;
    }*/

    public static Set<Id> getExistingSharesIds(Id recordId)
    {
        Set<Id> shareSet = new Set<Id>();

        List<Case_Share__c> existingSharesIds = [
            SELECT Share_Class__c
            FROM Case_Share__c
            WHERE Work_Together_Process__c = : recordId
        ];

        for(Case_Share__c wtpShare : existingSharesIds)
        {
            shareSet.add(wtpShare.Share_Class__c);
        }

        System.debug(shareSet);

        return shareSet;
    }
}