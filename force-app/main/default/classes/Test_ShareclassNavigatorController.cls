@isTest
public class Test_ShareclassNavigatorController {

        private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
 
    @testSetup
    static void setupData() {
        PMTTestFactoryData.createMatrice(
            'Proposal', 'Risk',
            'InvestmentObjective__c;InvestmentStrategy__c',
            'CurrencyIsoCode;Type__c'
        );
    }
 
    @isTest
    static void test_getProjectProductRecordType() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
        Test.startTest();
String result = ShareclassNavigatorController.getProjectProductRecordType(child.Id);
        Test.stopTest();
        System.assertEquals('FundCreation', result);
    }
 
    @isTest
    static void test_deleteProjectShareclass() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
 
        Test.startTest();
ShareclassNavigatorController.deleteProjectShareclass(shc.Id, child.Id);
        Test.stopTest();
 
System.assertEquals(0, [SELECT count() FROM ProjectShareclass__c WHERE Id = :shc.Id]);
    }
 
    @isTest
    static void test_canUserCreateShareclass() {
        Test.startTest();
        Boolean result = ShareclassNavigatorController.canUserCreateShareclass('dummy');
        Test.stopTest();
        System.assert(result != null);
    }
 
    @isTest
    static void test_createAndLinkShareclass() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
        ShareclassNavigatorController.createAndLinkShareclass(
        child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False'
        );
        Test.stopTest();
 
List <ProjectShareclass__c> listShareclass = [SELECT Id FROM ProjectShareclass__c WHERE ProjectProduct__c = :parent.Id];
        System.assert(!listShareclass.isEmpty());
    }
 
    @isTest
    static void test_getShareClassName() {
          Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
      
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
 
        Test.startTest();
String result = ShareclassNavigatorController.getShareClassName(share.Id);
        Test.stopTest();
 
        System.assertEquals('Test Share', result);
    }
 
    @isTest
    static void test_getPicklistValues() {
        Test.startTest();
        Map<String, List<String>> values = ShareclassNavigatorController.getPicklistValues();
        Test.stopTest();
 
        System.assert(values.containsKey('Type__c'));
        System.assert(values.get('Type__c').size() > 0);
    }

      @isTest static void test_getProjectShareclasses() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
PMTTestFactoryData.createJunction(child.Id, shc.Id);
 
        Test.startTest();
 ShareclassNavigatorController.getProjectShareclasses(child.Id);
        Test.stopTest();
 

    }
 
    @isTest static void test_getLinkedShareclasses() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
PMTTestFactoryData.createJunction(child.Id, shc.Id);
 
        Test.startTest();
 ShareclassNavigatorController.getLinkedShareclasses(child.Id);
        Test.stopTest();
 

    }
 
    @isTest static void test_getProjectShareclassChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
 
        Test.startTest();
Id result = ShareclassNavigatorController.getProjectShareclassChild(child.Id, shc.Id);
        Test.stopTest();
 

    }
 
    @isTest static void test_getRecordId_withChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
Id result = ShareclassNavigatorController.getRecordId(child.Id);
        Test.stopTest();
 

    }
 
    @isTest static void test_getRecordId_withParent() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
Id result = ShareclassNavigatorController.getRecordId(parent.Id);
        Test.stopTest();
 

    }
 
    @isTest static void test_cloneApexShareclass_project() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
        
        Test.startTest();
Id newId = ShareclassNavigatorController.cloneApexShareclass(child.Id, shc.Id, 'ProjectShareclass__c');
        Test.stopTest();
 

    }

      @isTest static void test_getFilteredReferentialShareclasses() {
         Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c shareClass = new Share_Class__c(Name = 'Global Fund', Fund__c = product.Id);
        insert shareClass;

        Test.startTest();
        List<Share_Class__c> result = ShareclassNavigatorController.getFilteredReferentialShareclasses('Global');
        Test.stopTest();

    }

    @isTest static void test_getFilteredProjectShareclasses() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');

        PMTTestFactoryData.createJunction(child.Id, shc.Id);

        Test.startTest();
        List<ProjectShareclass__c> result = ShareclassNavigatorController.getFilteredProjectShareclasses(child.Id, 'USD');
        Test.stopTest();

    }

    @isTest static void test_cloneApexShareclass_ProjectShareclass() {
       ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
        ProjectShareclass__c originalShc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');

        Test.startTest();
        Id newShareclassId = ShareclassNavigatorController.cloneApexShareclass(child.Id, originalShc.Id, 'ProjectShareclass__c');
        Test.stopTest();

        ProjectShareclass__c cloned = [SELECT Id, ClonedByProjectShareclass__c, ClonedByReferential__c FROM ProjectShareclass__c WHERE Id = :newShareclassId];

 
    }

    @isTest static void test_cloneApexShareclass_ShareClass() {
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c shareClass = new Share_Class__c(Name = 'Referential Class', Fund__c = product.Id);
        insert shareClass;

        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);

        Test.startTest();
        Id newShareclassId = ShareclassNavigatorController.cloneApexShareclass(child.Id, shareClass.Id, 'Share_Class__c');
        Test.stopTest();
    } 
}