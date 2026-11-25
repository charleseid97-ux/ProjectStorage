/** ──────────────────────────────────────
 * @description Tests of the projectChildTeamValidation LWC controller: on a Fund creation project, every read and validation method
 *                  (user permissions, stage of a record, records with fields, required fields and matrix of a team at a stage, team
 *                  validation); on a modification project, the required fields check and the record locks.
 * @covers ProjectChildTeamValidationController   94%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ProjectChildTeamValidationCTRL {

    // Fund creation project: every read / validation method of the controller on the same project
    @isTest
    static void test_creationProject() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));

        // Étape Proposal : un ShareclassChild DesignAndProposal est rattaché à l'étape Proposal
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Proposal', null);
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        PMTTestFactoryData.createJunction(child.Id, shc.Id);
        ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        String invalidParametersMessage;

        Test.startTest();

        // Permissions de l'utilisateur
        ProjectChildTeamValidationController.checkPortfolioManager();
        ProjectChildTeamValidationController.getUserPermissions();
        ProjectChildTeamValidationController.getMetadataFields(new List<String>{ 'ProjectProductChild__c', 'ProjectShareclassChild__c' });

        // Étape du projet, depuis l'étape elle-même ou depuis un ShareclassChild
        Id stageFromStage = ProjectChildTeamValidationController.getRecordId(child.Id);
        Id stageFromShareclassChild = ProjectChildTeamValidationController.getRecordId(shChild.Id);
        Id stageFromNothing = ProjectChildTeamValidationController.getRecordId(null);
        Id stageFromProject = ProjectChildTeamValidationController.getRecordId(proj.Id);
        String parentRecordType = ProjectChildTeamValidationController.getParentRecordTypeName(child.Id);
        ProjectChildTeamValidationController.getRecordTypeName(child.Id);
        ProjectChildTeamValidationController.getProjectChild(child.Id);
        ProjectChildTeamValidationController.getRecordWithFields('ProjectProductChild__c', new Set<Id>{ child.Id }, new List<String>{ 'Name' });
        ProjectChildTeamValidationController.getRecordWithFields('ProjectShareclassChild__c', new Set<Id>{ shc.Id }, new List<String>{ 'Name' });
        try {
            ProjectChildTeamValidationController.getRecordWithFields(null, null, null);
        }
        catch (IllegalArgumentException e) {
            invalidParametersMessage = e.getMessage();
        }
        ProjectChildTeamValidationController.getShareclassesId(child.Id);
        ProjectChildTeamValidationController.hasProposalPortfolioManager(proj.Id);
        Set<String> fundCreationExclusions = ProjectChildTeamValidationController.getExcludedFieldsForValidation('FundCreation');
        ProjectChildTeamValidationController.getExcludedFieldsForValidation('ShareclassCreation');

        // Champs de l'équipe à l'étape (matrice PMT) : Design (aucun champ) et Proposal (champs requis Product Strategy vides)
        ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(child.Id, 'Product Strategy', 'Design');
        Map<String, List<Map<String, List<String>>>> emptyProposalFields = ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(child.Id, 'Product Strategy', 'Proposal');
        ProjectChildTeamValidationController.getShareClasses(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getFund(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getShareClassesMatrix(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getFundMatrix(child.Id, 'Product Strategy', 'Design');

        // Validation de l'équipe (en dernier : verrouille l'étape)
        ProjectChildTeamValidationController.updateTeamValidation(child.Id, 'ProductStrategy');

        Test.stopTest();

        System.assertEquals(child.Id, stageFromStage, 'A Project Product Child is its own stage');
        System.assertEquals(child.Id, stageFromShareclassChild, 'A Shareclass Child resolves to the stage of its Share Class');
        System.assertEquals(null, stageFromNothing, 'No record, no stage');
        System.assertEquals(null, stageFromProject, 'A project is not a stage');
        System.assertEquals('FundCreation', parentRecordType, 'Record type of the parent project');
        System.assert(invalidParametersMessage != null && invalidParametersMessage.contains('Invalid parameters'), 'Invalid parameters are rejected');
        System.assert(fundCreationExclusions.isEmpty(), 'No exclusion outside Shareclass Creation');
        System.assert(!emptyProposalFields.isEmpty(), 'Empty required Product Strategy fields are reported');
    }

    // Fund modification project: required fields check and record locks
    @isTest
    static void test_modificationProject() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        insert new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        ProjectProduct__c projmodif = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification'));
        projmodif.TECH_FieldsToModify__c = 'ProductName__c';
        update projmodif;

        // Étape Design, son ProjectShareclass (junction) et son ShareclassChild
        ProjectProductChild__c childmodif = PMTTestFactoryData.createProjectProductChild(projmodif.Id, 'Design', null);
        ProjectShareclass__c shcmodif = PMTTestFactoryData.createProjectShareclass(projmodif.Id, 'DividendPolicy__c');
        PMTTestFactoryData.createJunction(childmodif.Id, shcmodif.Id);
        ProjectShareclassChild__c scChild = PMTTestFactoryData.createShareclassChild(shcmodif.Id, 'Design');

        Test.startTest();

        ProjectChildTeamValidationController.checkRequiredFieldsFundShareClassModification(childmodif.Id, 'Design', 'Product Strategy');
        // Proposal: the fields to modify (ProductName__c, DividendPolicy__c) belong to Product Strategy at this stage
        ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(childmodif.Id, 'Product Strategy', 'Proposal');
        ProjectChildTeamValidationController.lockRecordShareClassChild(scChild, scChild);
        ProjectChildTeamValidationController.lockRecordPPC(new List<ProjectProductChild__c>{ childmodif }, new List<ProjectProductChild__c>{ childmodif });

        Test.stopTest();
    }
}