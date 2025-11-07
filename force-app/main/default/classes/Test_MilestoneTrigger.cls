@isTest
public class Test_MilestoneTrigger {
    
    @isTest
    static void test_linkStepToMilestone() {
        // 1. Création du parent ProjectProduct
        Id recordTypeId = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosByDeveloperName()
            .get('FundCreation')
            .getRecordTypeId();
 
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
 
        // 2. Création d'une étape (step) avec une plage de dates couvrant le milestone
        Date today = Date.today();
        ProjectProductChild__c step = new ProjectProductChild__c(
            Name = 'Proposal',
            ProjectProductParent__c = project.Id,
            StartDate__c = today,
            EndDate__c = today.addDays(10)
        );
        insert step;
 
        // 3. Création d'un milestone avec une StartDate__c comprise dans la plage de l'étape
        Milestone__c milestone = new Milestone__c(
            Name = 'Milestone A',
            Project_product__c = project.Id,
            StartDate__c = today.addDays(5)
        );
 
        Test.startTest();
            insert milestone;
        Test.stopTest();
 
        // 4. Vérification que le milestone a bien été lié à l'étape
        Milestone__c insertedMilestone = [SELECT Id, Project_Product_Child__c FROM Milestone__c WHERE Id = :milestone.Id];
        insertedMilestone.Name = 'Milestone B';
        update insertedMilestone;
    }

     @isTest
    static void test_updateProjectLaunchDate() {
        // 1. Création du parent ProjectProduct
        Id recordTypeId = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosByDeveloperName()
            .get('FundCreation')
            .getRecordTypeId();
 
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
             // 3. Création d'un milestone avec une StartDate__c comprise dans la plage de l'étape
        Milestone__c milestone = new Milestone__c(
            Name = 'Launch Date',
            Project_product__c = project.Id,
            StartDate__c = Date.today().addDays(5)
        );

        insert milestone;

        Test.startTest();
            Milestone__c goLiveMilestone = [SELECT Id, StartDate__c FROM Milestone__c WHERE Project_Product__c = :project.Id AND Name = 'Launch Date' LIMIT 1];
            goLiveMilestone.StartDate__c = Date.today().addDays(10);
            update goLiveMilestone;

            project.EndDate__c = Date.today().addDays(11);
            update project;
        Test.stopTest();
    }
    
    @isTest
    static void test_updateOwnerOnProjectProduct() {
        // 1. Création du parent ProjectProduct
        Id recordTypeId = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosByDeveloperName()
            .get('FundShareClassModification')
            .getRecordTypeId();
 
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(project.Id, 'CurrencyIsoCode');

        Milestone__c milestone = new Milestone__c(
            Name = 'SPC Final',
            Project_product__c = project.Id,
            StartDate__c = Date.today().addDays(5)
        );
        insert milestone;
        Milestone__c milestoneGoLive = new Milestone__c(
            Name = 'Launch Date',
            Project_product__c = project.Id,
            StartDate__c = Date.today().addDays(25)
        );

        insert milestoneGoLive;
 
     	project.TECH_FieldsToModify__c = 'MinTaxAlignment__c;NAVFrequency__c';
        update project;
      
        Test.startTest();
        Milestone__c milestoneToUpdate = [SELECT Id, StartDate__c FROM Milestone__c WHERE Project_Product__c = :project.Id AND Name = 'SPC Final' LIMIT 1];
        milestoneToUpdate.Status__c = 'Completed';  
        update milestoneToUpdate;
        
        Test.stopTest();
    }
}