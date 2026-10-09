@isTest
public class Test_ProjectChildTeamValidationCTRL {

    // Fund creation project: every read / validation method of the controller on the same project
    @isTest
    static void test_creationProject() {
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);

        // Créer ProjectProductChild (étape Proposal : un ShareclassChild DesignAndProposal est rattaché à l'étape Proposal)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Proposal', null);

        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        PMTTestFactoryData.createJunction(child.Id, shc.Id);

        // Créer ShareclassChild lié à la même étape
        ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;

        Test.startTest();
        // Permissions de l'utilisateur
        ProjectChildTeamValidationController.checkPortfolioManager();
        ProjectChildTeamValidationController.getUserPermissions();
        ProjectChildTeamValidationController.getMetadataFields(new List<String>{ 'ProjectProductChild__c', 'ProjectShareclassChild__c' });

        // Étape du projet, depuis l'étape elle-même ou depuis un ShareclassChild
        System.assertEquals(child.Id, ProjectChildTeamValidationController.getRecordId(child.Id), 'A Project Product Child is its own stage');
        System.assertEquals(child.Id, ProjectChildTeamValidationController.getRecordId(shChild.Id), 'A Shareclass Child resolves to the stage of its Share Class');

        System.assertEquals(null, ProjectChildTeamValidationController.getRecordId(null), 'No record, no stage');
        System.assertEquals(null, ProjectChildTeamValidationController.getRecordId(proj.Id), 'A project is not a stage');
        System.assertEquals('FundCreation', ProjectChildTeamValidationController.getParentRecordTypeName(child.Id), 'Record type of the parent project');
        ProjectChildTeamValidationController.getRecordTypeName(child.Id);

        ProjectChildTeamValidationController.getProjectChild(child.Id);
        ProjectChildTeamValidationController.getRecordWithFields('ProjectProductChild__c', new Set<Id>{ child.Id }, new List<String>{ 'Name' });
        ProjectChildTeamValidationController.getRecordWithFields('ProjectShareclassChild__c', new Set<Id>{ shc.Id }, new List<String>{ 'Name' });
        try {
            ProjectChildTeamValidationController.getRecordWithFields(null, null, null);
            System.assert(false, 'Invalid parameters must be rejected');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Invalid parameters'), 'Invalid parameters are rejected');
        }
        ProjectChildTeamValidationController.getShareclassesId(child.Id);
        ProjectChildTeamValidationController.hasProposalPortfolioManager(proj.Id);
        System.assert(ProjectChildTeamValidationController.getExcludedFieldsForValidation('FundCreation').isEmpty(), 'No exclusion outside Shareclass Creation');
        ProjectChildTeamValidationController.getExcludedFieldsForValidation('ShareclassCreation');

        // Champs de l'équipe à l'étape (matrice PMT) : Design (aucun champ) et Proposal (champs requis Product Strategy vides)
        ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(child.Id, 'Product Strategy', 'Design');
        System.assert(!ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(child.Id, 'Product Strategy', 'Proposal').isEmpty(), 'Empty required Product Strategy fields are reported');
        ProjectChildTeamValidationController.getShareClasses(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getFund(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getShareClassesMatrix(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getFundMatrix(child.Id, 'Product Strategy', 'Design');

        // Validation de l'équipe (en dernier : verrouille l'étape)
        ProjectChildTeamValidationController.updateTeamValidation(child.Id, 'ProductStrategy');
        Test.stopTest();
    }

    // Fund modification project: required fields check and record locks
    @isTest
    static void test_modificationProject() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        insert new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);

        Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
        ProjectProduct__c projmodif = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        projmodif.TECH_FieldsToModify__c = 'ProductName__c';
        update projmodif;

        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c childmodif = PMTTestFactoryData.createProjectProductChild(projmodif.Id, 'Design', null);

        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shcmodif = PMTTestFactoryData.createProjectShareclass(projmodif.Id, 'DividendPolicy__c');
        PMTTestFactoryData.createJunction(childmodif.Id, shcmodif.Id);

        // Créer ShareclassChild lié à la même étape
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
