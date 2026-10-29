/** ──────────────────────────────────────
 * @description Tests of the ProjectProduct__c trigger on a Fund creation project: Road To Market at creation, status date,
 *                  Launch Date milestone, PMT owner rule (condition on LegalForm__c) and, when the fields read by the PMT
 *                  conditions change, the realignment of the automatically validated teams (US-20194: ISIN__c becomes an OPS field).
 * @covers ProjectProductTriggerHandler   100%   [21-10-26]
 * @covers ProjectProductSetupHandler   94%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ProjectProductTrigger {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    // Fund creation project: after insert (Road To Market), then before/after update (status date, Launch Date milestone, Legal owner rule, conditional PMT lines)
    @isTest
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
        PMTTestFactoryData.createOwnerRule('Legal', 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'OEIC\')', username);
        // US-20194: ISIN__c used by OPS at Filing only for a GB/LU OEIC/SICAV fund (the factory project is FR / Other: nobody uses it)
        PMTTestFactoryData.createMatrixLine('Filing', 'OPS', 'Share_Class__c', 'ISIN__c', 'Required', '(ISPICKVAL(ProjectProduct__c.DomiciledIn__c, \'GB\') || ISPICKVAL(ProjectProduct__c.DomiciledIn__c, \'LU\')) && (ISPICKVAL(ProjectProduct__c.LegalForm__c, \'OEIC\') || ISPICKVAL(ProjectProduct__c.LegalForm__c, \'SICAV\'))');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        List<RoadToMarket__c> roadToMarkets = [SELECT Id FROM RoadToMarket__c WHERE Parent_Project__c = :proj.Id];
        System.assert(!roadToMarkets.isEmpty(), 'RoadToMarket should be created after insert');
        PMTMatrix projectMatrix = PMTMatrix.get().forConditions(proj);
        Boolean opsUsesOtherFilingFields = !projectMatrix.getRule('OPS', 'Filing').isEmpty();
        ProjectProductChild__c filing = [SELECT TECH_TeamValidation__c
                                         FROM ProjectProductChild__c
                                         WHERE ProjectProductParent__c = :proj.Id AND Name = 'Filing'];
        System.assertEquals(!opsUsesOtherFilingFields, ProjectProductSetupHandlerUtilities.splitMultiPicklist(filing.TECH_TeamValidation__c).contains('OPS'), 'OPS without field at Filing is validated automatically');

        // Set a milestone to test EndDate__c update handling
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);

        // Change fields to trigger before/after update logic
        proj.ProjectStatus__c = 'Active';
        proj.LegalForm__c = 'OEIC'; // owner rule field: the Legal owner follows
        proj.DomiciledIn__c = 'LU'; // with OEIC: ISIN__c becomes an OPS field at Filing (US-20194)
        proj.EndDate__c = Date.today().addDays(10); // to update milestone
        proj.TECH_FieldsToModify__c = 'ProductName__c'; // a selected field is blanked on the phases then copied back to the project: not a field read by the PMT conditions

        Test.startTest();

        update proj; // before update & after update triggered

        Test.stopTest();

        // Assert Tech_DateChangementStatus__c was set (via before update)
        ProjectProduct__c updated = [SELECT Tech_DateChangementStatus__c, Legal__c FROM ProjectProduct__c WHERE Id = :proj.Id];
        System.assertNotEquals(null, updated.Tech_DateChangementStatus__c, 'Status change date should be set');
        System.assertEquals(oeicOwner.Id, updated.Legal__c, 'Legal owner of the new legal form (PMT owner rule)');

        // US-20194: OPS now has ISIN__c to fill at Filing, it is no longer validated automatically (resyncConditionalValues, asynchronous)
        filing = [SELECT TECH_TeamValidation__c FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id AND Name = 'Filing'];
        System.assert(!ProjectProductSetupHandlerUtilities.splitMultiPicklist(filing.TECH_TeamValidation__c).contains('OPS'), 'OPS gained a field at Filing: it has to validate');

        // Assert milestone was updated
        Milestone__c updatedMilestone = [SELECT StartDate__c FROM Milestone__c WHERE Id = :milestone.Id];
        System.assertEquals(proj.EndDate__c, updatedMilestone.StartDate__c, 'Milestone StartDate__c should match EndDate__c');
    }
}