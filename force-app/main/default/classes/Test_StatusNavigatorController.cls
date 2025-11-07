@isTest
public class Test_StatusNavigatorController {
 
    @testSetup
    static void setupData() {
        PMTTestFactoryData.createMatrice(
            'Proposal', 'Risk', 'InvestmentObjective__c;InvestmentStrategy__c', 'CurrencyIsoCode;Type__c'
        );
    }
 
    @isTest
    static void test_getMatchingProjectProductChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
PMTTestFactoryData.createJunction(child.Id, shc.Id);
 
        Test.startTest();
Id result = statusNavigatorController.getMatchingProjectProductChild(shChild.Id);
        Test.stopTest();
 
System.assertEquals(child.Id, result);
    }
 
    @isTest
    static void test_getProjectProduct() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
ProjectProduct__c result = statusNavigatorController.getProjectProduct(child.Id);
        Test.stopTest();
 
System.assertEquals(parent.Id, result.Id);
    }
 
    @isTest
    static void test_getSteps_withProductChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
List<Map<String, Object>> steps = statusNavigatorController.getSteps(child.Id, 'ProjectProductChild__c');
        Test.stopTest();
 
        System.assert(!steps.isEmpty());
    }
 
    @isTest
    static void test_getSteps_withShareclassChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
 
        Test.startTest();
List<Map<String, Object>> steps = statusNavigatorController.getSteps(shChild.Id, 'ProjectShareclassChild__c');
        Test.stopTest();
 
        System.assert(!steps.isEmpty());
    }
 
    @isTest
    static void test_getProposalStep() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
PMTTestFactoryData.createJunction(child.Id, shc.Id);
 
        Test.startTest();
Id result = statusNavigatorController.getProposalStep(shChild.Id);
        Test.stopTest();
 
System.assertEquals(child.Id, result);
    }
 
    @isTest
    static void test_getParentRecord_withProductChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
Id result = statusNavigatorController.getParentRecord(child.Id, 'ProjectProductChild__c');
        Test.stopTest();
 
System.assertEquals(parent.Id, result);
    }
 
    @isTest
    static void test_getParentRecord_withShareclassChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
PMTTestFactoryData.createJunction(child.Id, shc.Id);
 
        Test.startTest();
Id result = statusNavigatorController.getParentRecord(shChild.Id, 'ProjectShareclassChild__c');
        Test.stopTest();
 
System.assertEquals(child.Id, result);
    }
 
    @isTest
    static void test_getCurrentStep_withProductChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
 
        Test.startTest();
String step = statusNavigatorController.getCurrentStep(child.Id, 'ProjectProductChild__c');
        Test.stopTest();
 
        System.assertEquals('DesignAndProposal', step);
    }
 
    @isTest
    static void test_getCurrentStep_withShareclassChild() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
 
        Test.startTest();
String step = statusNavigatorController.getCurrentStep(shChild.Id, 'ProjectShareclassChild__c');
        Test.stopTest();
 
        System.assertEquals('DesignAndProposal', step);
    }
}