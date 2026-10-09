@isTest
public class Test_ProjectProductTrigger {
 
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
 
    // Fund creation project: after insert (Road To Market), then before/after update (status date, Launch Date milestone, Legal owner rule)
    @IsTest
    static void test_insertAndUpdate() {
        // FIX-20178: Legal owner of the OEIC legal form, through a PMT owner rule (owner found by FederationIdentifier)
        Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String username = 'pmtoeic' + System.currentTimeMillis() + '@pmtowner.test';
        User oeicOwner = new User(Alias = 'pmtoeic', Email = username, Username = username, LastName = 'PMT Owner', ProfileId = standardUser.Id,
                                  FederationIdentifier = username, EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
                                  LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Paris');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert oeicOwner; // Setup object: inserted apart from the project DML (mixed DML)
        }
        PMTMatrix.addOwnerRuleForTest('Legal', 'LegalForm__c', new List<String>{ 'OEIC' }, username);

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        System.assert(![SELECT Id FROM RoadToMarket__c WHERE Parent_Project__c = :proj.Id].isEmpty(), 'RoadToMarket should be created after insert');

        // Set a milestone to test EndDate__c update handling
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);
 
        // Change fields to trigger before/after update logic
        proj.ProjectStatus__c = 'Active';
        proj.LegalForm__c = 'OEIC'; // owner rule field: the Legal owner follows
        proj.EndDate__c = Date.today().addDays(10); // to update milestone
        proj.TECH_FieldsToModify__c = 'LegalForm__c';
 
        Test.startTest();
        update proj; // before update & after update triggered
        Test.stopTest();
 
        // Assert Tech_DateChangementStatus__c was set (via before update)
        ProjectProduct__c updated = [SELECT Tech_DateChangementStatus__c, Legal__c FROM ProjectProduct__c WHERE Id = :proj.Id];
        System.assertNotEquals(null, updated.Tech_DateChangementStatus__c, 'Status change date should be set');
        System.assertEquals(oeicOwner.Id, updated.Legal__c, 'Legal owner of the new legal form (PMT owner rule)');
 
        // Assert milestone was updated
        Milestone__c updatedMilestone = [SELECT StartDate__c FROM Milestone__c WHERE Id = :milestone.Id];
        System.assertEquals(proj.EndDate__c, updatedMilestone.StartDate__c, 'Milestone StartDate__c should match EndDate__c');
    }
}
