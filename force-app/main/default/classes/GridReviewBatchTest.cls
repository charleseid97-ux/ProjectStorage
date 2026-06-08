/** ──────────────────────────────────────
 * @description Test class for GridReviewBatch.
 *              Covers CGL/CGF classification, LastReviewSentDate__c stamping,
 *                  future-dated grid exclusion, and the dispatch() entry point.
 * @author Charles EID
 * @coverage 97%   [11-05-26]
 ────────────────────────────────────── */
@isTest
private class GridReviewBatchTest {

    @TestSetup
    static void setup() {
        GridTestSetupHelper.setupTestData();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Add the running user to both queues so finish() resolves member emails
            List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName IN ('CGL_Top_Management', 'CGF_Top_Management')];
            List<GroupMember> members = new List<GroupMember>();
            for (Group q : queues) {
                members.add(new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId()));
            }
            if (!members.isEmpty()) insert members;

            List<Grid__c> grids = [SELECT Id FROM Grid__c ORDER BY Name];
            List<Convention__c> agreements = [SELECT Id FROM Convention__c ORDER BY Name];

            AgreementTriggerHandler.triggerDisabled = true;
            agreements[0].Carmignac_Legal_Entity__c = 'CGL';
            agreements[1].Carmignac_Legal_Entity__c = 'CGF';
            update agreements;
            AgreementTriggerHandler.triggerDisabled = false;

            grids[0].Agreement__c = agreements[0].Id;
            grids[0].NextReviewDate__c = Date.today().addDays(-1);
            grids[0].BusinessBackground__c = 'CGL business context';

            grids[1].Agreement__c = agreements[1].Id;
            grids[1].NextReviewDate__c = Date.today().addDays(-1);
            grids[1].BusinessBackground__c = 'CGF business context';

            grids[2].Agreement__c = agreements[0].Id;
            grids[2].NextReviewDate__c = Date.today().addDays(30);

            update grids;
        }
    }

    private static ScheduledAlert__mdt makeConfig() {
        return (ScheduledAlert__mdt) JSON.deserialize(
            '{"ApexClass__c":"GridReviewBatch","BatchSize__c":200,"IsActive__c":true,"Frequency__c":"Weekly"}',
            ScheduledAlert__mdt.class
        );
    }

    @isTest
    static void testCglGridsPickedUp() {
        Test.startTest();
        Database.executeBatch(new GridReviewBatch(makeConfig()), 200);
        Test.stopTest();

        List<Grid__c> processed = [SELECT LastReviewSentDate__c FROM Grid__c WHERE Agreement__r.Carmignac_Legal_Entity__c = 'CGL' AND NextReviewDate__c <= TODAY];
        System.assertEquals(1, processed.size());
        System.assertEquals(Date.today(), processed[0].LastReviewSentDate__c, 'LastReviewSentDate__c should be stamped for CGL grid');
    }

    @isTest
    static void testCgfGridsPickedUp() {
        Test.startTest();
        Database.executeBatch(new GridReviewBatch(makeConfig()), 200);
        Test.stopTest();

        List<Grid__c> processed = [SELECT LastReviewSentDate__c FROM Grid__c WHERE Agreement__r.Carmignac_Legal_Entity__c = 'CGF' AND NextReviewDate__c <= TODAY];
        System.assertEquals(1, processed.size());
        System.assertEquals(Date.today(), processed[0].LastReviewSentDate__c, 'LastReviewSentDate__c should be stamped for CGF grid');
    }

    @isTest
    static void testFutureGridNotPickedUp() {
        Test.startTest();
        Database.executeBatch(new GridReviewBatch(makeConfig()), 200);
        Test.stopTest();

        List<Grid__c> futureGrids = [SELECT LastReviewSentDate__c FROM Grid__c WHERE NextReviewDate__c > TODAY];
        System.assertEquals(1, futureGrids.size());
        System.assertEquals(null, futureGrids[0].LastReviewSentDate__c, 'Future-dated grid should not be processed');
    }

    @isTest
    static void testDispatchMethod() {
        ScheduledAlert__mdt config = makeConfig();

        Test.startTest();
        new GridReviewBatch(config).dispatch(config);
        Test.stopTest();

        List<Grid__c> processed = [SELECT LastReviewSentDate__c FROM Grid__c WHERE NextReviewDate__c <= TODAY];
        for (Grid__c g : processed) {
            System.assertEquals(Date.today(), g.LastReviewSentDate__c);
        }
    }
}
