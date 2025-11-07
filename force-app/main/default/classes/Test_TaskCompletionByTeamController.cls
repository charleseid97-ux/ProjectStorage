@isTest
public class Test_TaskCompletionByTeamController {
 
    @testSetup
    static void setupData() {
        // Création des matrices
        PMTTestFactoryData.createMatrice('Proposal', 'Risk', 'InvestmentObjective__c;InvestmentStrategy__c', 'CurrencyIsoCode;Type__c');
        
        // Création projet et étape
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(
            Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId()
        );
        
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Proposal', 'Risk');


        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
         

       

    }
 
    @isTest
    static void test_getStepWithTeams() {
       

            ProjectProductChild__c ppc = [SELECT Id FROM ProjectProductChild__c LIMIT 1];
    

         ProjectProduct__c proj = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        Test.startTest();
String json = TaskCompletionByTeamController.getStepWithTeams(proj.Id);
        Test.stopTest();
        System.assertNotEquals(null, json);
        System.debug(json);
    }
 
    @isTest
    static void test_getCompletionRatesBulk() {
        ProjectProduct__c proj = [SELECT Id FROM ProjectProduct__c LIMIT 1];
ProjectProductChild__c child = [SELECT Id, Name FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];
 

List<Id> recordIds = new List<Id>{child.Id};
 List<String> stepNames = new List<String>{child.Name};
        List<String> teamNames = new List<String>{'Risk'};
 
        Test.startTest();
        List<TaskCompletionByTeamController.TeamCompletionWrapper> results =
            TaskCompletionByTeamController.getCompletionRatesBulk(recordIds, stepNames, teamNames);
        Test.stopTest();
 
        System.assertEquals(1, results.size());
System.assertEquals(child.Id, results[0].recordId);
        System.assertEquals('Risk', results[0].teamName);
    }
}