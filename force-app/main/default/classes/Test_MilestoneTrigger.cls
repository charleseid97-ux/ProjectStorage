@isTest
public class Test_MilestoneTrigger {
    
    // Fund creation project: a milestone is linked to the stage covering its date, the Launch Date drives the project end date
    @isTest
    static void test_creationProject() {
        Id recordTypeId = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosByDeveloperName()
            .get('FundCreation')
            .getRecordTypeId();
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);

        // Étape dont la plage de dates couvre le milestone
        Date today = Date.today();
        insert new ProjectProductChild__c(
            Name = 'Proposal',
            ProjectProductParent__c = project.Id,
            StartDate__c = today,
            EndDate__c = today.addDays(10)
        );

        Milestone__c milestone = new Milestone__c(Name = 'Milestone A', Project_product__c = project.Id, StartDate__c = today.addDays(5));
        Milestone__c launchDate = new Milestone__c(Name = 'Launch Date', Project_product__c = project.Id, StartDate__c = today.addDays(5));

        Test.startTest();
        // The trigger links only the first milestone of a batch to its stage: one insert each
        insert milestone;
        insert launchDate;
        milestone.Name = 'Milestone B';
        update milestone;

        launchDate.StartDate__c = today.addDays(10);
        update launchDate;
        System.assertEquals(today.addDays(10), [SELECT EndDate__c FROM ProjectProduct__c WHERE Id = :project.Id].EndDate__c, 'The Launch Date is the project end date');

        project.EndDate__c = today.addDays(11);
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