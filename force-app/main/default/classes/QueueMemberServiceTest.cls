/** ──────────────────────────────────────
 * @description Test class for QueueMemberService.
 *              Covers queue ID lookup, resolveMembers (user passthrough, direct queue
 *              members, nested public group, role group), and getQueueMemberEmails.
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

    // ─── resolveMembers ───────────────────────────────────────────────────────
    @IsTest
    static void testResolveMembers_EmptyInput() {
        Test.startTest();
        Map<Id, List<Id>> result = QueueMemberService.resolveMembers(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty map for empty input');
    }

    @IsTest
    static void testResolveMembers_UserPassthrough() {
        Id userId = UserInfo.getUserId();

        Test.startTest();
        Map<Id, List<Id>> result = QueueMemberService.resolveMembers(new Set<Id>{ userId });
        Test.stopTest();

        System.assert(result.containsKey(userId), 'Result should contain the user Id as key');
        System.assertEquals(1, result.get(userId).size(), 'User should map to a list containing itself');
        System.assertEquals(userId, result.get(userId)[0], 'User should map to itself');
    }

    @IsTest
    static void testResolveMembers_DirectQueueMember() {
        Group q = createQueue('QMS_Test_Queue_MemberIds');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();
        Map<Id, List<Id>> result = QueueMemberService.resolveMembers(new Set<Id>{ q.Id });
        Test.stopTest();

        System.assert(result.containsKey(q.Id), 'Result should contain the queue Id as key');
        System.assert(result.get(q.Id).contains(UserInfo.getUserId()), 'Should contain current user as direct member');
    }

    @IsTest
    static void testResolveMembers_NestedPublicGroup() {
        Group queue      = createQueue('QMS_Test_Queue_NestedIds');
        Group innerGroup = new Group(Name = 'QMS_Inner_Ids', DeveloperName = 'QMS_Inner_Ids', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert innerGroup;
            insert new GroupMember(GroupId = queue.Id,      UserOrGroupId = innerGroup.Id);
            insert new GroupMember(GroupId = innerGroup.Id, UserOrGroupId = UserInfo.getUserId());
        }

        Test.startTest();
        Map<Id, List<Id>> result = QueueMemberService.resolveMembers(new Set<Id>{ queue.Id });
        Test.stopTest();

        System.assert(result.containsKey(queue.Id), 'Result should contain queue Id as key');
        System.assert(result.get(queue.Id).contains(UserInfo.getUserId()), 'Should contain user via nested public group');
    }

    @IsTest
    static void testResolveMembers_RoleGroup() {
        UserRole role = new UserRole(Name = 'QMS_Test_Role', DeveloperName = 'QMS_Test_Role');
        insert role;

        // Salesforce auto-creates a Group with Type='Role' when a UserRole is inserted — query it
        List<Group> roleGroups = [SELECT Id FROM Group WHERE Type = 'Role' AND RelatedId = :role.Id LIMIT 1];
        if (roleGroups.isEmpty()) {
            return; // org did not generate the role group; skip
        }

        User testUser = new User(
            Alias             = 'qmsrole',
            Email             = 'qmsrole@test.example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'QmsRoleUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = UserInfo.getProfileId(),
            TimeZoneSidKey    = 'America/Los_Angeles',
            Username          = 'qmsroleuser@test.example.com',
            UserRoleId        = role.Id
        );
        insert testUser;

        Group queue = createQueue('QMS_Test_Queue_Role');
        insert new GroupMember(GroupId = queue.Id, UserOrGroupId = roleGroups[0].Id);

        Test.startTest();
        Map<Id, List<Id>> result = QueueMemberService.resolveMembers(new Set<Id>{ queue.Id });
        Test.stopTest();

        System.assert(result.containsKey(queue.Id), 'Result should contain queue Id as key');
        System.assert(result.get(queue.Id).contains(testUser.Id), 'Should contain user whose role matches the role group');
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