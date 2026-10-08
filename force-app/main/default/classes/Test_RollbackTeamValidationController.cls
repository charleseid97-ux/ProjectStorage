@isTest
public class Test_RollbackTeamValidationController {
 
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
   
    @testSetup
    static void setupData() {
        // Création du ProjectProduct parent
     
        ProjectProduct__c parentProject = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        parentProject.LettreRequise__c = 'No';
        update parentProject;
 
        Milestone__c milestone = PMTTestFactoryData.createMilestone(parentProject.Id, 'SPC Final', parentProject.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;

        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parentProject.Id, 'Engineering', null);
        child.TECH_TeamValidation__c = 'Legal;Risk;Tax';
        update child;
    }
 
    @isTest
    static void test_allFunctions() {
        ProjectProduct__c parent = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        String phase = 'Engineering'; // Doit correspondre au DeveloperName du RecordType
        List<String> teamsToRemove = new List<String>{'Legal'};
        List<String> teamsToAdd = new List<String>{'Compliance'};

        Test.startTest();

        List<RecordType> result = RollbackTeamValidationController.getProjectProductChildRecordTypes(); //test_getProjectProductChildRecordTypes
        List<String> values = RollbackTeamValidationController.getTeamPicklistValues(parent.Id); // test_getTeamPicklistValues

        RollbackTeamValidationController.rollbackTeamValidation(phase, 'Draft', teamsToRemove, parent.Id); //test_rollbackTeamValidation_remove_and_add
        RollbackTeamValidationController.rollbackTeamValidation(phase, 'Validated', teamsToAdd, parent.Id); //test_rollbackTeamValidation_remove_and_add

        Test.stopTest();
    }
}