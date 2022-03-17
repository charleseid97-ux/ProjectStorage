/**
 * Created by Otman on 28/12/2021.
 */

@IsTest
private class WTPSelectorControllerTest
{
    @IsTest
    static void testBehavior()
    {
        String StratProdRTId= Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
        String FundProdRTId= Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

        Product__c testStratProd = new Product__c(Name='testStratProd', Product_Name__c = 'testStratProd',
                RecordTypeId=StratProdRTId, Validity__c=true, Dedicated_Fund__c=false);
        insert testStratProd;

        Product__c testFundProd = new Product__c(Name='testFundProd', Product_Name__c = 'testFundProd',
                RecordTypeId=FundProdRTId,
                Strategy__c=testStratProd.Id, Validity__c=true, Dedicated_Fund__c=false);
        insert testFundProd;

        Share_Class__c share = new Share_Class__c(Name = 'Test', Fund__c = testFundProd.Id);
        insert share;

        Case aCase = new Case(Fund__c = testFundProd.Id);
        insert aCase;

        WTPSelectorController.getRelatedShares(new List<Id>{testStratProd.Id}, aCase.Id);
    }
}