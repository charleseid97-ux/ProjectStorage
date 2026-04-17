/***
*	Test class for STrategyOnFund class
*	19/02/2019 BP created
*
***/
@isTest
public with sharing class StrategyOnFundTest {

    public static List<Product__c> strategyProducts;
    public static List<Product__c> fundProducts;
    public static List<Share_Class__c> shareClasses;
    public static Map<String, Id> prodRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Product__c.SObjectType);

    public static void insertData() {
        strategyProducts = new List<Product__c>{
            new Product__c(Name='ST1', Product_Name__c='Strategy Test 1', Validity__c=true, Record_Type_Name__c='Strategy'),
            new Product__c(Name='ST2', Product_Name__c='Strategy Test 2', Validity__c=true, Record_Type_Name__c='Strategy')
        };
        insert strategyProducts;
        
        fundProducts = new List<Product__c>{
            new Product__c(Name='FT1', Product_Name__c='Fund Test 1', Strategy_Code__c='ST1', Validity__c=true),
            new Product__c(Name='FT2', Product_Name__c='Fund Test 2', Strategy_Code__c='ST2', Validity__c=true)
        };
        insert fundProducts;

        shareClasses = new List<Share_Class__c>{
            new Share_Class__c(Name='SC1', Fund__c=fundProducts[0].Id, Validity__c=true),
                new Share_Class__c(Name='SC2', Fund__c=fundProducts[1].Id, Validity__c=true)
        };
        insert shareClasses;
    }
    
    @isTest static void testProducts(){
        insertData();
        
        Product__c testStrat = [SELECT RecordTypeId, Id FROM Product__c WHERE Id =: strategyProducts[0].Id];
        system.assertEquals(testStrat.RecordTypeId, prodRtMap.get('Strategy'), 'Strategy has been updated to Strategy Record Type');
        
        StrategyOnFund.processFunds();
        Product__c testFund = [SELECT Strategy__c FROM Product__c WHERE Id =: fundProducts[0].Id];
        //system.assertEquals(testStrat.Id, testFund.Strategy__c, 'Strategy has been linked to Fund correctly');
        
    }

}