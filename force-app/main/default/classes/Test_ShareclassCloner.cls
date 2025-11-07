@isTest
public class Test_ShareclassCloner {

   private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
    @testSetup
    static void setupData() {
        // Setup a ProjectProduct
        Id recordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
 
        // Create a ProjectProductChild
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(project.Id, 'Proposal', null);
  Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        // Create a Share_Class__c
        Share_Class__c share = new Share_Class__c(
            Name = 'Original Share',
              Fund__c =product.Id
        );
        insert share;
 
        // Create a ProjectShareclass
        ProjectShareclass__c psc = PMTTestFactoryData.createProjectShareclass(project.Id, 'EUR');
    }
 
    @isTest
    static void test_cloneShareClass() {
        Share_Class__c share = [SELECT Id FROM Share_Class__c LIMIT 1];
        ProjectProduct__c project = [SELECT Id FROM ProjectProduct__c LIMIT 1];
 
        Test.startTest();
Id clonedId = ShareclassCloner.cloneShareClass(share.Id, project.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, clonedId);
        ProjectShareclass__c result = [SELECT Id, ClonedByReferential__c FROM ProjectShareclass__c WHERE Id = :clonedId];
System.assertEquals(share.Id, result.ClonedByReferential__c);
    }
 
    @isTest
    static void test_cloneProjectShareClass() {
        ProjectShareclass__c original = [SELECT Id FROM ProjectShareclass__c LIMIT 1];
        ProjectProduct__c project = [SELECT Id FROM ProjectProduct__c LIMIT 1];
 
        Test.startTest();
Id clonedId = ShareclassCloner.cloneProjectShareClass(original.Id, project.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, clonedId);
        ProjectShareclass__c result = [SELECT Id, ClonedByProjectShareclass__c FROM ProjectShareclass__c WHERE Id = :clonedId];
System.assertEquals(original.Id, result.ClonedByProjectShareclass__c);
    }
 
    @isTest
    static void test_createObjectJunctions() {
        ProjectShareclass__c shareclass = [SELECT Id FROM ProjectShareclass__c LIMIT 1];
        ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c LIMIT 1];
 
        Test.startTest();
ShareclassCloner.createObjectJunctions(child.Id, shareclass.Id);
        Test.stopTest();
 
List<ProjectChildJunction__c> junctions = [SELECT Id FROM ProjectChildJunction__c WHERE ProjectShareclass__c = :shareclass.Id];
        System.assert(junctions.size() > 0);
    }
 
    @isTest
    static void test_createShareclassChildren() {
        ProjectShareclass__c shareclass = [SELECT Id FROM ProjectShareclass__c LIMIT 1];
 
        Test.startTest();
ShareclassCloner.createShareclassChildren(shareclass.Id);
        Test.stopTest();
 
List<ProjectShareclassChild__c> children = [SELECT Id FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :shareclass.Id];

    }
 
    @isTest
    static void test_createShareclassChildrenWithFields() {
        ProjectShareclass__c shareclass = [SELECT Id, Type__c, CurrencyIsoCode, DividendPolicy__c, CurrencyHedging__c FROM ProjectShareclass__c LIMIT 1];
 
        Test.startTest();
ShareclassCloner.createShareclassChildrenWithFields(shareclass.Id, shareclass, 'BaseName');
        Test.stopTest();
 
List<ProjectShareclassChild__c> children = [SELECT Id, Type__c FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :shareclass.Id];

    }
}