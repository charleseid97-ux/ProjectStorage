/** ──────────────────────────────────────
 * @description Tests of the Rollback Validation panel controller (phases, teams of the project's Scope, add / remove validated teams), and of the phase status that follows
 *                  the team validation (FIX-20270): Completed once every team of the Scope has validated, back to On track when a team is removed, Design following Proposal
 *                  (in the same save, and through a separate update when Design is not in the save).
 * @covers RollbackTeamValidationController   100%   [19-10-26]
 * @covers ProjectProductChildHandlerUtilities   100%   [19-10-26]
 * @lastModifiedBy Charles EID   [19-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_RollbackTeamValidationController {

    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    @testSetup
    static void setupData() {
        // Modification project with an extra Engineering phase
        ProjectProduct__c modificationProject = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        Milestone__c milestone = PMTTestFactoryData.createMilestone(modificationProject.Id, 'SPC Final', modificationProject.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;

        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(modificationProject.Id, 'Engineering', null);
        child.TECH_TeamValidation__c = 'Legal;Risk;Tax';
        update child;

        // FIX-20270: creation project with its 5 phases; its SPC Final milestone (created with the Proposal phase) completed so the teams can validate
        ProjectProduct__c creationProject = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRecordTypeId);
        Milestone__c spcFinal = [SELECT Id FROM Milestone__c WHERE Project_Product__c = :creationProject.Id AND Name = 'SPC Final' LIMIT 1];
        spcFinal.Status__c = 'Completed';
        update spcFinal;
    }

    @isTest
    static void test_allFunctions() {
        ProjectProduct__c modificationProject = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundModificationRecordTypeId LIMIT 1];
        ProjectProduct__c creationProject = [SELECT Id, Scope__c FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRecordTypeId LIMIT 1];
        String scope = ProjectProductSetupHandlerUtilities.normalizeScope(creationProject.Scope__c);
        List<String> scopeTeams = new List<String>(PMTMatrix.get().forScope(scope).getValidationTeamKeys());
        Map<String, Id> phaseIdByName = new Map<String, Id>();
        for (ProjectProductChild__c phase : [SELECT Id, Name FROM ProjectProductChild__c WHERE ProjectProductParent__c = :creationProject.Id]) {
            phaseIdByName.put(phase.Name, phase.Id);
        }

        Test.startTest();

        List<RecordType> recordTypes = RollbackTeamValidationController.getProjectProductChildRecordTypes();
        List<String> teams = RollbackTeamValidationController.getTeamPicklistValues(modificationProject.Id);
        RollbackTeamValidationController.rollbackTeamValidation('Engineering', 'Draft', new List<String>{ 'Legal' }, modificationProject.Id);
        RollbackTeamValidationController.rollbackTeamValidation('Engineering', 'Validated', new List<String>{ 'Compliance' }, modificationProject.Id);

        // Every team of the Scope validates Design and Proposal (one save): Proposal Completed, Design follows in the same save
        RollbackTeamValidationController.rollbackTeamValidation('DesignAndProposal', 'Validated', scopeTeams, creationProject.Id);
        Map<String, String> statusAfterValidation = getStatusByPhase(creationProject.Id);

        // A team of the Scope is removed: both back to On track
        RollbackTeamValidationController.rollbackTeamValidation('DesignAndProposal', 'Draft', new List<String>{ scopeTeams[0] }, creationProject.Id);
        Map<String, String> statusAfterRollback = getStatusByPhase(creationProject.Id);

        // The team validates Proposal alone: Proposal Completed, Design (not in the save) updated separately
        ProjectChildTeamValidationController.updateTeamValidation(phaseIdByName.get('Proposal'), scopeTeams[0]);
        Map<String, String> statusAfterTeamValidation = getStatusByPhase(creationProject.Id);

        Test.stopTest();

        System.assertEquals(4, recordTypes.size(), 'DesignAndProposal, Engineering, Filing and SetUp');
        System.assert(!(teams.contains('ProductStrategy') && teams.contains('IS')), 'Product Strategy and IS are never offered together');
        for (ProjectProductChild__c phase : [SELECT TECH_TeamValidation__c FROM ProjectProductChild__c WHERE ProjectProductParent__c = :modificationProject.Id AND Name = 'Engineering']) {
            Set<String> validatedTeams = ProjectProductSetupHandlerUtilities.splitMultiPicklist(phase.TECH_TeamValidation__c);
            System.assert(!validatedTeams.contains('Legal'), 'Legal rolled back to Draft');
            System.assert(validatedTeams.contains('Compliance'), 'Compliance validated');
        }

        System.assertEquals('Completed', statusAfterValidation.get('Proposal'), 'Every team of the Scope validated Proposal');
        System.assertEquals('Completed', statusAfterValidation.get('Design'), 'Design follows Proposal in the same save');
        System.assertEquals('On track', statusAfterRollback.get('Proposal'), 'A team of the Scope was removed');
        System.assertEquals('On track', statusAfterRollback.get('Design'), 'Design follows Proposal');
        System.assertEquals('Completed', statusAfterTeamValidation.get('Proposal'), 'The removed team validated again');
        System.assertEquals('Completed', statusAfterTeamValidation.get('Design'), 'Design follows Proposal through a separate update');
        System.assertEquals('Not Started', statusAfterTeamValidation.get('Engineering'), 'Engineering was never validated');
    }

    private static Map<String, String> getStatusByPhase(Id projectId) {
        Map<String, String> statusByPhase = new Map<String, String>();
        for (ProjectProductChild__c phase : [SELECT Name, Status__c FROM ProjectProductChild__c WHERE ProjectProductParent__c = :projectId]) {
            statusByPhase.put(phase.Name, phase.Status__c);
        }
        return statusByPhase;
    }
}