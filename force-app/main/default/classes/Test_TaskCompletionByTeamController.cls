@isTest
public class Test_TaskCompletionByTeamController {

    // Fund creation project: stage x team grid of the widget, then the completion rates of a stage
    @isTest
    static void test_teamCompletion() {
        // FIX-20178: rules added to the PMT matrix of this transaction (in memory, so not in a @testSetup)
        PMTTestFactoryData.createMatrice('Proposal', 'Risk', 'InvestmentObjective__c;InvestmentStrategy__c', 'CurrencyIsoCode;Type__c');
        PMTTestFactoryData.createMatrice('Design', 'Risk', 'InvestmentObjective__c;InvestmentStrategy__c', 'CurrencyIsoCode;Type__c');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId());
        proj.Risk__c = UserInfo.getUserId(); // A real owner on the Risk team field, so the owner name resolves to an actual User
        update proj;

        // Proposal stage validated by Risk, linked to a share class with a Proposal Shareclass Child
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Proposal', 'Risk');
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        PMTTestFactoryData.createJunction(child.Id, shc.Id);
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');

        Test.startTest();
        System.assertNotEquals(null, TaskCompletionByTeamController.getStepWithTeams(proj.Id), 'Stages and teams of the project');

        // Risk is computed, an unknown team is skipped
        List<TaskCompletionByTeamController.TeamCompletionWrapper> results = TaskCompletionByTeamController.getCompletionRatesBulk(
            new List<Id>{ child.Id, child.Id }, new List<String>{ 'Proposal', 'Proposal' }, new List<String>{ 'Risk', 'Unknown Team' });
        System.assert(TaskCompletionByTeamController.getCompletionRatesBulk(new List<Id>(), new List<String>(), new List<String>()).isEmpty(), 'Nothing to compute');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only the known team is computed');
        System.assertEquals(child.Id, results[0].recordId);
        System.assertEquals('Risk', results[0].teamName);
    }
}
