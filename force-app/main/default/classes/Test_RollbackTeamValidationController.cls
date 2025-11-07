@isTest
public class Test_RollbackTeamValidationController {
 
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
   
    @testSetup
    static void setupData() {
        // Création du ProjectProduct parent
     
        ProjectProduct__c parentProject = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
 
        Milestone__c milestone = PMTTestFactoryData.createMilestone(parentProject.Id, 'SPC Final', parentProject.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parentProject.Id, 'Engineering', null);
        child.TECH_TeamValidation__c = 'Legal;Risk;Tax';
        update child;
    }
 
    @isTest
    static void test_getProjectProductChildRecordTypes() {
        Test.startTest();
        List<RecordType> result = RollbackTeamValidationController.getProjectProductChildRecordTypes();
        Test.stopTest();
    }
 
    @isTest
    static void test_getTeamPicklistValues() {
        Test.startTest();
        List<String> values = RollbackTeamValidationController.getTeamPicklistValues();
        Test.stopTest();
    }
 
    @isTest
    static void test_rollbackTeamValidation_remove_and_add() {
        ProjectProduct__c parent = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        String phase = 'Engineering'; // Doit correspondre au DeveloperName du RecordType
        List<String> teamsToRemove = new List<String>{'Legal'};
        List<String> teamsToAdd = new List<String>{'Compliance'};
 
        // ➖ Retrait d'une équipe
        Test.startTest();
RollbackTeamValidationController.rollbackTeamValidation(phase, 'Draft', teamsToRemove, parent.Id);
RollbackTeamValidationController.rollbackTeamValidation(phase, 'Validated', teamsToAdd, parent.Id);
        Test.stopTest();


    }
}