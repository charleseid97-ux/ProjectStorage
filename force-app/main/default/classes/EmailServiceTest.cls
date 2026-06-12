/** ──────────────────────────────────────
 * @description Test class for EmailService.
 *              Covers recipient type resolution (submitter, current/next approvers,
 *              record owner, queue expansion), additional recipient resolution,
 *              and sendTemplateEmail early-return guards.
 * @author Charles EID
 * @covers EmailService
 ────────────────────────────────────── */
@IsTest
public class EmailServiceTest {

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── sendTemplateEmail ────────────────────────────────────────────────────
    @IsTest
    static void testSendTemplateEmail_NullRecipients() {
        Test.startTest();

        EmailService.sendTemplateEmail('SomeTemplate', null, null);

        Test.stopTest();
        
        System.assert(true, 'Should handle null recipients without error'); // No exception — null recipients returns early
    }

    @IsTest
    static void testSendTemplateEmail_EmptyRecipients() {
        Test.startTest();

        EmailService.sendTemplateEmail('SomeTemplate', null, new Set<Id>());

        Test.stopTest();

        System.assert(true, 'Should handle empty recipients without error');
    }

    @IsTest
    static void testSendTemplateEmail_TemplateNotFound() {
        Test.startTest();

        EmailService.sendTemplateEmail('NonExistent_Template_XYZ', UserInfo.getUserId(), new Set<Id>{ UserInfo.getUserId() });

        Test.stopTest();

        System.assert(true, 'Should handle missing template gracefully');
    }

    // ─── resolveRecipientIds ──────────────────────────────────────────────────
    @IsTest
    static void testResolveRecipientIds_EmptyTypes() {
        Test.startTest();
        
        Set<Id> result = EmailService.resolveRecipientIds(new Set<String>(), null, null, null, null, null);

        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty set for empty types');
    }

    @IsTest
    static void testResolveRecipientIds_NullTypes() {
        Test.startTest();

        Set<Id> result = EmailService.resolveRecipientIds(null, null, null, null, null, null);

        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty set for null types');
    }

    @IsTest
    static void testResolveRecipientIds_Submitter() {
        Id submitterId = UserInfo.getUserId();

        Test.startTest();

        Set<Id> result = EmailService.resolveRecipientIds(new Set<String>{ 'Submitter' }, null, null, submitterId, null, null);

        Test.stopTest();

        System.assert(result.contains(submitterId), 'Should include the submitter');
    }

    @IsTest
    static void testResolveRecipientIds_CurrentApprovers_User() {
        Id currentUserId = UserInfo.getUserId();

        Test.startTest();

        Set<Id> result = EmailService.resolveRecipientIds(new Set<String>{ 'CurrentStepApprovers' }, new Set<Id>{ currentUserId }, null, null, null, null);

        Test.stopTest();

        System.assert(result.contains(currentUserId), 'Should include the current user approver');
    }

    @IsTest
    static void testResolveRecipientIds_CurrentApprovers_Queue() {
        // Exercises expandApproverIds with a queue ID, which calls QueueMemberService.getQueueMemberIds
        Group q = new Group(Name = 'EST_Approver_Queue', DeveloperName = 'EST_Approver_Queue', Type = 'Queue');
        insert q;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();
        
        Set<Id> result = EmailService.resolveRecipientIds(new Set<String>{ 'CurrentStepApprovers' }, new Set<Id>{ q.Id }, null, null, null, null);

        Test.stopTest();

        System.assert(result.contains(UserInfo.getUserId()), 'Should expand queue approver to its user member');
    }

    @IsTest
    static void testResolveRecipientIds_NextApprovers() {
        Id nextUserId = UserInfo.getUserId();

        Test.startTest();

        Set<Id> result = EmailService.resolveRecipientIds(new Set<String>{ 'NextStepApprovers' }, null, new Set<Id>{ nextUserId }, null, null, null);

        Test.stopTest();

        System.assert(result.contains(nextUserId), 'Should include the next step approver');
    }

    @IsTest
    static void testResolveRecipientIds_RecordOwner() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();

        Set<Id> result = EmailService.resolveRecipientIds(new Set<String>{ 'RecordOwner' }, null, null, null, grid.Id, 'Grid__c');

        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Should resolve the grid record owner');
    }

    // ─── resolveAdditionalRecipientIds ────────────────────────────────────────
    @IsTest
    static void testResolveAdditionalRecipientIds_BlankInputs() {
        Test.startTest();

        Set<Id> result = EmailService.resolveAdditionalRecipientIds(null, null);

        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty set for blank inputs');
    }

    @IsTest
    static void testResolveAdditionalRecipientIds_AdditionalUser() {
        User runningUser = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId()];

        Test.startTest();

        Set<Id> result = EmailService.resolveAdditionalRecipientIds(null, runningUser.Username);

        Test.stopTest();

        System.assert(result.contains(runningUser.Id), 'Should resolve user by username');
    }

    @IsTest
    static void testResolveAdditionalRecipientIds_AdditionalQueue() {
        Group q = new Group(Name = 'EST_Additional_Queue', DeveloperName = 'EST_Additional_Queue', Type = 'Queue');
        insert q;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();

        Set<Id> result = EmailService.resolveAdditionalRecipientIds('EST_Additional_Queue', null);

        Test.stopTest();

        System.assert(result.contains(UserInfo.getUserId()), 'Should resolve queue members as recipients');
    }
}