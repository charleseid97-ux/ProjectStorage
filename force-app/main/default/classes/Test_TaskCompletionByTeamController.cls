/** ──────────────────────────────────────
 * @description Tests of the lwc_TaskCompletionByTeam controller on a Fund creation project: the stage x team grid of the widget, then
 *                  the completion rates of a stage (known team computed, unknown team skipped, nothing to compute).
 * @covers TaskCompletionByTeamController   99%   [23-10-26]
 * @lastModifiedBy Charles EID   [23-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_TaskCompletionByTeamController {

    @isTest
    static void test_teamCompletion() {
        // FIX-20178: rules added to the PMT matrix of this transaction (in memory, so not in a @testSetup)
        PMTTestFactoryData.createMatrice('Proposal', 'Risk', 'InvestmentObjective__c;InvestmentStrategy__c', 'CurrencyIsoCode;Type__c');
        PMTTestFactoryData.createMatrice('Design', 'Risk', 'InvestmentObjective__c;InvestmentStrategy__c', 'CurrencyIsoCode;Type__c');
        // US-20194 V1.2.2: a Conditional line, required for this project (LegalForm__c Other), must be queried before its condition is evaluated
        PMTTestFactoryData.createMatrixLine('Proposal', 'Risk', 'Product__c', 'IntentedRetailInvestor__c', 'Conditional', null, 'NOT(ISPICKVAL(ProjectProduct__c.LegalForm__c, \'OEIC\'))');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        proj.Risk__c = UserInfo.getUserId(); // A real owner on the Risk team field, so the owner name resolves to an actual User
        update proj;

        // Proposal stage validated by Risk, linked to a share class with a Proposal Shareclass Child
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Proposal', 'Risk');
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        PMTTestFactoryData.createJunction(child.Id, shc.Id);
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');

        Test.startTest();

        String stepsWithTeams = TaskCompletionByTeamController.getStepWithTeams(proj.Id);
        // Risk is computed, an unknown team is skipped
        List<TaskCompletionByTeamController.TeamCompletionWrapper> results = TaskCompletionByTeamController.getCompletionRatesBulk(new List<Id>{ child.Id, child.Id }, new List<String>{ 'Proposal', 'Proposal' }, new List<String>{ 'Risk', 'Unknown Team' });
        List<TaskCompletionByTeamController.TeamCompletionWrapper> noResults = TaskCompletionByTeamController.getCompletionRatesBulk(new List<Id>(), new List<String>(), new List<String>());

        Test.stopTest();

        System.assertNotEquals(null, stepsWithTeams, 'Stages and teams of the project');
        System.assertEquals(1, results.size(), 'Only the known team is computed');
        System.assertEquals(child.Id, results[0].recordId);
        System.assertEquals('Risk', results[0].teamName);
        System.assert(noResults.isEmpty(), 'Nothing to compute');
    }
}