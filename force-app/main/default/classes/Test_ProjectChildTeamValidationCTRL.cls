@isTest
public class Test_ProjectChildTeamValidationCTRL {
    
    @isTest(SeeAllData=true)
    static void test_checkPortfolioManagerAndUserPermissions() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        // 1) Vérifier les permissions (toujours non nulles pour cet utilisateur)
        
        List<String> perms1 = ProjectChildTeamValidationController.checkPortfolioManager();
        List<String> perms2 = ProjectChildTeamValidationController.getUserPermissions();
        /*
        List<Map<String,String>> meta = ProjectChildTeamValidationController.getMetadataFields(
            new List<String>{ 'ProjectProductChild__c', 'ProjectShareclassChild__c' }
        );
        
        
        Id rec1 = ProjectChildTeamValidationController.getRecordId(child.Id);
        
        
        
        ProjectChildTeamValidationController.getProjectChild(child.Id);
        
        ProjectChildTeamValidationController.updateTeamValidation(child.Id, 'ProductStrategy');
        
        ProjectChildTeamValidationController.getRecordWithFields('ProjectProduct__c', new Set<Id> {child.Id}, new List<String> {'Name'});
        
        
        ProjectChildTeamValidationController.getShareclassesId(child.Id);
        ProjectChildTeamValidationController.hasProposalPortfolioManager(proj.Id);
        ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(child.Id, 'Product Strategy', 'Design');
        ProjectChildTeamValidationController.getShareClasses(child.Id, 'Product Strategy', 'Design');
        
        ProjectChildTeamValidationController.getFund(child.Id, 'Product Strategy', 'Design');
        
        Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
        
        ProjectProduct__c projmodif = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        projmodif.TECH_FieldsToModify__c = 'ProductName__c';
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c childmodif = PMTTestFactoryData.createProjectProductChild(projmodif.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shcmodif = PMTTestFactoryData.createProjectShareclass(projmodif.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junctionmodif = PMTTestFactoryData.createJunction(childmodif.Id, shcmodif.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shcmodif.Id, 'Design');
        
        
        ProjectChildTeamValidationController.checkRequiredFieldsFundShareClassModification(childmodif.Id, 'Design', 'Product Strategy');
        */
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getMetadataFields() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        List<Map<String,String>> meta = ProjectChildTeamValidationController.getMetadataFields(
            new List<String>{ 'ProjectProductChild__c', 'ProjectShareclassChild__c' }
        );
        
        Test.stopTest();

    }

    @isTest(SeeAllData=true)
    static void test_getRecordId() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        Id rec1 = ProjectChildTeamValidationController.getRecordId(child.Id);
		Id rec2 = ProjectChildTeamValidationController.getRecordId(shChild.Id);
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getProjectChild() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.getProjectChild(child.Id);
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_updateTeamValidation() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
       
        ProjectChildTeamValidationController.updateTeamValidation(child.Id, 'ProductStrategy');
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getRecordWithFields() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.getRecordWithFields('ProjectProductChild__c', new Set<Id> {child.Id}, new List<String> {'Name'});
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getShareclassesId() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        
        ProjectChildTeamValidationController.getShareclassesId(child.Id);
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_hasProposalPortfolioManager() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.hasProposalPortfolioManager(proj.Id);
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_checkRequiredFiledsIsEmpty() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty(child.Id, 'Product Strategy', 'Design');
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getShareClasses() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.getShareClasses(child.Id, 'Product Strategy', 'Design');
       
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getFund() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        
        ProjectChildTeamValidationController.getFund(child.Id, 'Product Strategy', 'Design');
        
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_checkRequiredFieldsFundShareClassModification() {
        
        
        Test.startTest();
                
        Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
        
        ProjectProduct__c projmodif = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        projmodif.TECH_FieldsToModify__c = 'ProductName__c';
        update projmodif;
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c childmodif = PMTTestFactoryData.createProjectProductChild(projmodif.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shcmodif = PMTTestFactoryData.createProjectShareclass(projmodif.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junctionmodif = PMTTestFactoryData.createJunction(childmodif.Id, shcmodif.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shcmodif.Id, 'Design');
        
        
        ProjectChildTeamValidationController.checkRequiredFieldsFundShareClassModification(childmodif.Id, 'Design', 'Product Strategy');
        
        Test.stopTest();

    }
        
    @isTest(SeeAllData=true)
    static void test_lockRecordShareClassChild(){
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
        
        Test.startTest();
                
        Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
        
        ProjectProduct__c projmodif = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        projmodif.TECH_FieldsToModify__c = 'ProductName__c';
        update projmodif;
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c childmodif = PMTTestFactoryData.createProjectProductChild(projmodif.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shcmodif = PMTTestFactoryData.createProjectShareclass(projmodif.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junctionmodif = PMTTestFactoryData.createJunction(childmodif.Id, shcmodif.Id);
        
        // Créer ShareclassChild lié à la même étape
        ProjectShareclassChild__c scChild = PMTTestFactoryData.createShareclassChild(shcmodif.Id, 'Design');
        
        
        ProjectChildTeamValidationController.lockRecordShareClassChild(scChild,scChild);
        
        Test.stopTest();
    }
    
    @isTest(SeeAllData=true)
    static void test_lockRecordPPC(){
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
        
        Test.startTest();
                
        Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
        
        ProjectProduct__c projmodif = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRecordTypeId);
        projmodif.TECH_FieldsToModify__c = 'ProductName__c';
        update projmodif;
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c childmodif = PMTTestFactoryData.createProjectProductChild(projmodif.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shcmodif = PMTTestFactoryData.createProjectShareclass(projmodif.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junctionmodif = PMTTestFactoryData.createJunction(childmodif.Id, shcmodif.Id);
        
        // Créer ShareclassChild lié à la même étape
        ProjectShareclassChild__c scChild = PMTTestFactoryData.createShareclassChild(shcmodif.Id, 'Design');
        
        
        ProjectChildTeamValidationController.lockRecordPPC(New List<ProjectProductChild__c>{childmodif},New List<ProjectProductChild__c>{childmodif});
        
        Test.stopTest();
    }

	
@isTest(SeeAllData=true)
    static void test_getShareClassesMatrix() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.getShareClassesMatrix(child.Id, 'Product Strategy', 'Design');
        
        Test.stopTest();

    }
    
    @isTest(SeeAllData=true)
    static void test_getFundMatrix() {
        
        Test.startTest();
        // Créer projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        // Créer ProjectProductChild (étape Design)
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(proj.Id, 'Design', null);
        
        // Créer ProjectShareclass et son junction
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
        ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shc.Id);
        
        // Créer ShareclassChild lié à la même étape
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Design');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        
        ProjectShareclassChild__c shChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        
        ProjectChildTeamValidationController.getFundMatrix(child.Id, 'Product Strategy', 'Design');
        
        Test.stopTest();

    }
    
    
}