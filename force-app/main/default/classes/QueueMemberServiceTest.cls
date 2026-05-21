/** ──────────────────────────────────────
 * @description Test class for QueueMemberService.
 *              Covers queue ID lookup, direct and nested group member resolution
 *              for both ID and email variants, and isUserInQueue checks
 *              including the nested group fallback path.
 * @author Charles EID
 * @covers QueueMemberService
 ────────────────────────────────────── */
@IsTest
public class QueueMemberServiceTest {

    private static Group createQueue(String devName) {
        Group q = new Group(Name = devName, DeveloperName = devName, Type = 'Queue');
        insert q;
        return q;
    }

    // ─── getQueueId ───────────────────────────────────────────────────────────
    @IsTest
    static void testGetQueueId_Found() {
        Group q = createQueue('QMS_Test_Queue_Found');

        Test.startTest();

        Id result = QueueMemberService.getQueueId('QMS_Test_Queue_Found');

        Test.stopTest();

        System.assertEquals(q.Id, result, 'Should return the queue Id');
    }

    @IsTest
    static void testGetQueueId_NotFound() {
        Test.startTest();

        Id result = QueueMemberService.getQueueId('QMS_NonExistent_XYZ');

        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for unknown queue');
    }

    // ─── isUserInQueue ────────────────────────────────────────────────────────
    @IsTest
    static void testIsUserInQueue_DirectMember() {
        Group q = createQueue('QMS_Test_Queue_Direct');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();

        Boolean result = QueueMemberService.isUserInQueue(UserInfo.getUserId(), q.Id);

        Test.stopTest();

        System.assertEquals(true, result, 'User should be a direct member');
    }

    @IsTest
    static void testIsUserInQueue_NotMember() {
        Group q = createQueue('QMS_Test_Queue_NotMember');

        Test.startTest();

        Boolean result = QueueMemberService.isUserInQueue(UserInfo.getUserId(), q.Id);

        Test.stopTest();

        System.assertEquals(false, result, 'User should not be a member of the empty queue');
    }

    @IsTest
    static void testIsUserInQueue_NestedGroupMember() {
        Group queue       = createQueue('QMS_Test_Queue_Nested');
        Group innerGroup  = new Group(Name = 'QMS_Inner_Group', DeveloperName = 'QMS_Inner_Group', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert innerGroup;
            insert new GroupMember(GroupId = queue.Id,      UserOrGroupId = innerGroup.Id);
            insert new GroupMember(GroupId = innerGroup.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();

        Boolean result = QueueMemberService.isUserInQueue(UserInfo.getUserId(), queue.Id);

        Test.stopTest();

        System.assertEquals(true, result, 'User should be found via nested group membership');
    }

    // ─── getQueueMemberIds ────────────────────────────────────────────────────
    @IsTest
    static void testGetQueueMemberIds_EmptyInput() {
        Test.startTest();

        Map<String, Set<Id>> result = QueueMemberService.getQueueMemberIds(new Set<String>());

        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty map for empty input');
    }

    @IsTest
    static void testGetQueueMemberIds_DirectUser() {
        Group q = createQueue('QMS_Test_Queue_MemberIds');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();

        Map<String, Set<Id>> result = QueueMemberService.getQueueMemberIds(new Set<String>{ 'QMS_Test_Queue_MemberIds' });

        Test.stopTest();

        System.assert(result.containsKey('QMS_Test_Queue_MemberIds'), 'Result should contain queue key');
        System.assert(result.get('QMS_Test_Queue_MemberIds').contains(UserInfo.getUserId()), 'Should contain current user');
    }

    @IsTest
    static void testGetQueueMemberIds_NestedGroup() {
        Group queue      = createQueue('QMS_Test_Queue_NestedIds');
        Group innerGroup = new Group(Name = 'QMS_Inner_Ids', DeveloperName = 'QMS_Inner_Ids', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert innerGroup;
            insert new GroupMember(GroupId = queue.Id,      UserOrGroupId = innerGroup.Id);
            insert new GroupMember(GroupId = innerGroup.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();

        Map<String, Set<Id>> result = QueueMemberService.getQueueMemberIds(new Set<String>{ 'QMS_Test_Queue_NestedIds' });

        Test.stopTest();

        System.assert(result.containsKey('QMS_Test_Queue_NestedIds'), 'Result should contain queue key');
        System.assert(result.get('QMS_Test_Queue_NestedIds').contains(UserInfo.getUserId()), 'Should contain user via nested group');
    }

    // ─── getQueueMemberEmails ─────────────────────────────────────────────────
    @IsTest
    static void testGetQueueMemberEmails_DirectMember() {
        Group q = createQueue('QMS_Test_Queue_Emails');
        User runningUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = runningUser.Id);
        }

        Test.startTest();

        Map<String, Set<String>> result = QueueMemberService.getQueueMemberEmails(new Set<String>{ 'QMS_Test_Queue_Emails' });
        
        Test.stopTest();

        System.assert(result.containsKey('QMS_Test_Queue_Emails'), 'Should contain queue key');
        if (String.isNotBlank(runningUser.Email)) {
            System.assert(result.get('QMS_Test_Queue_Emails').contains(runningUser.Email), 'Should contain user email');
        }
    }

    @IsTest
    static void testGetQueueMemberEmails_NestedGroup() {
        Group queue      = createQueue('QMS_Test_Queue_EmailsNested');
        Group innerGroup = new Group(Name = 'QMS_Inner_Emails', DeveloperName = 'QMS_Inner_Emails', Type = 'Regular');
        User runningUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            insert innerGroup;
            insert new GroupMember(GroupId = queue.Id,      UserOrGroupId = innerGroup.Id);
            insert new GroupMember(GroupId = innerGroup.Id, UserOrGroupId = runningUser.Id);
        }

        Test.startTest();

        Map<String, Set<String>> result = QueueMemberService.getQueueMemberEmails(new Set<String>{ 'QMS_Test_Queue_EmailsNested' });

        Test.stopTest();

        System.assert(result.containsKey('QMS_Test_Queue_EmailsNested'), 'Should contain queue key');
        if (String.isNotBlank(runningUser.Email)) {
            System.assert(result.get('QMS_Test_Queue_EmailsNested').contains(runningUser.Email), 'Should contain nested user email');
        }
    }
}