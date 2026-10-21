/** ──────────────────────────────────────
 * @description Tests of the "Project Management Phase" table controller (Admin interface tab): reading the phases of a project, saving the edited dates and statuses, and the
 *                  save error returned to the LWC as a readable AuraHandledException (FIX-20270).
 * @covers ProjectManagementPhaseController   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ProjectManagementPhaseController {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    @isTest
    static void test_updateProjectChildren() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        ProjectProductChild__c engineering = [SELECT Id, StartDate__c
                                              FROM ProjectProductChild__c
                                              WHERE ProjectProductParent__c = :proj.Id AND Name = 'Engineering' LIMIT 1];
        Date newStartDate = engineering.StartDate__c.addDays(1);
        String errorMessage;

        Test.startTest();

        List<ProjectProductChild__c> phases = ProjectManagementPhaseController.updateProjectChildren(new List<ProjectProductChild__c>{ new ProjectProductChild__c(Id = engineering.Id, StartDate__c = newStartDate, Status__c = 'On track') }, proj.Id);
        try {
            // 'Delayed' is an inactive value of the restricted Status__c picklist
            ProjectManagementPhaseController.updateProjectChildren(new List<ProjectProductChild__c>{ new ProjectProductChild__c(Id = engineering.Id, Status__c = 'Delayed') }, proj.Id);
        }
        catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }

        Test.stopTest();

        System.assertEquals(5, phases.size(), 'The 5 phases of the project are returned after the save');
        ProjectProductChild__c savedEngineering = [SELECT StartDate__c, Status__c FROM ProjectProductChild__c WHERE Id = :engineering.Id];
        System.assertEquals(newStartDate, savedEngineering.StartDate__c);
        System.assertEquals('On track', savedEngineering.Status__c);
        System.assertNotEquals(null, errorMessage, 'The save error is returned to the LWC');
        System.assert(errorMessage.contains('Delayed'), 'The readable DML message is kept: ' + errorMessage);
    }
}