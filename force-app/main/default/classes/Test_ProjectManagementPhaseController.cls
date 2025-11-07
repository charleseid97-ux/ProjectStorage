@IsTest
public class Test_ProjectManagementPhaseController {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    @isTest
    static void test_updateProjectChildren() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        ProjectProductChild__c projectProductChild  = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Proposal', null);
        projectProductChild.StartDate__c = date.today() + 1;

        Test.startTest();
        List<ProjectProductChild__c> listProjectProductChildUpdated = ProjectManagementPhaseController.updateProjectChildren(new List<ProjectProductChild__c>{projectProductChild}, proj.Id);
        Test.stopTest();
    }
}