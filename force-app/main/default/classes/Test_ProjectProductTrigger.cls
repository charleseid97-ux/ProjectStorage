@isTest
public class Test_ProjectProductTrigger {
 
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
 
    @IsTest(SeeAllData=true)
    static void test_beforeInsert_afterInsert() {
      
 
        Test.startTest();
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
          proj.TECH_FieldsToModify__c = 'LegalForm__c';
          update proj;
        Test.stopTest();
 
        // Assert that RoadToMarket__c was created (handled in after insert)
        List<RoadToMarket__c> roads = [
            SELECT Id FROM RoadToMarket__c WHERE Parent_Project__c = :proj.Id
        ];
        System.assert(!roads.isEmpty(), 'RoadToMarket should be created after insert');
    }
 
    @IsTest(SeeAllData=true)
    static void test_beforeUpdate_afterUpdate() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);

 
        // Set a milestone to test EndDate__c update handling
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);
 
        // Change fields to trigger before/after update logic
        proj.ProjectStatus__c = 'Active';
        proj.LegalForm__c = 'FCP';
        proj.EndDate__c = Date.today().addDays(10); // to update milestone
        proj.TECH_FieldsToModify__c = 'LegalForm__c';
 
        Test.startTest();
        update proj; // before update & after update triggered
        Test.stopTest();
 
        // Assert Tech_DateChangementStatus__c was set (via before update)
        ProjectProduct__c updated = [SELECT Tech_DateChangementStatus__c FROM ProjectProduct__c WHERE Id = :proj.Id];
        System.assertNotEquals(null, updated.Tech_DateChangementStatus__c, 'Status change date should be set');
 
        // Assert milestone was updated
        Milestone__c updatedMilestone = [SELECT StartDate__c FROM Milestone__c WHERE Id = :milestone.Id];
        System.assertEquals(proj.EndDate__c, updatedMilestone.StartDate__c, 'Milestone StartDate__c should match EndDate__c');
    }
}