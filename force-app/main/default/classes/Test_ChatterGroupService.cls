/** ──────────────────────────────────────
 * @description Tests of ChatterGroupService: Chatter group created with its members, and the notification frequency of a group's
 *                  members updated.
 * @covers ChatterGroupService   89%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ChatterGroupService {

    @isTest
    static void test_chatterGroups() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<User> users = new List<User>();
        for (Integer i = 0; i < 2; i++) {
            users.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'testuser' + i + '@test.com',
                Username = 'testuser' + i + '@test.com.' + System.currentTimeMillis(),
                Alias = 'test' + i,
                TimeZoneSidKey = 'Europe/Paris',
                LocaleSidKey = 'fr_FR',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'fr',
                ProfileId = p.Id
            ));
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert users; // Setup object: separated from the Chatter records (mixed DML)
        }
        CollaborationGroup notifiedGroup = new CollaborationGroup(Name = 'TestNotif', CollaborationType = 'Public', Description = 'Desc');
        insert notifiedGroup;
        CollaborationGroupMember member = new CollaborationGroupMember(CollaborationGroupId = notifiedGroup.Id, MemberId = users[0].Id, NotificationFrequency = 'N');
        insert member;

        Test.startTest();

        Map<String, List<Id>> memberIdsByGroupName = new Map<String, List<Id>>{ 'Projet Test Groupe Unitaire' => new List<Id>{ users[0].Id, users[1].Id } };
        List<Id> groupIds = ChatterGroupService.createGroupWithMembers(memberIdsByGroupName, 'Description test');
        ChatterGroupService.updateGroupMemberNotifications(new List<Id>{ notifiedGroup.Id }, 'P');

        Test.stopTest();

        Integer memberCount = [SELECT COUNT() FROM CollaborationGroupMember WHERE CollaborationGroupId IN :groupIds];
        CollaborationGroupMember updatedMember = [SELECT NotificationFrequency FROM CollaborationGroupMember WHERE Id = :member.Id];
        System.assertEquals(1, groupIds.size(), 'Un groupe devrait être créé');
        System.assertEquals(3, memberCount, 'Les 2 membres et le propriétaire du groupe');
        System.assertEquals('P', updatedMember.NotificationFrequency, 'La fréquence doit être mise à jour à P');
    }
}