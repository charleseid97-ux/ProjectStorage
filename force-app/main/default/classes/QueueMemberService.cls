/** ──────────────────────────────────────
 * @description Service class for resolving Salesforce queue and group membership.
 *              Core function resolveMembers expands any mix of User/Queue/Group Ids
 *              into concrete user Ids, handling direct members, nested public groups,
 *              and role-based groups.
 *              Used by EmailService for recipient resolution and by
 *              CustomApprovalHistoryController for permission checks.
 * @author Charles EID
 * @testClass QueueMemberServiceTest
 * @coverage 100%   [20-05-26]
────────────────────────────────────── */
public without sharing class QueueMemberService {

    public static Map<Id, List<Id>> resolveMembers(Set<Id> groupOrUserIds) {
        System.debug('DBG resolveMembers | input=' + groupOrUserIds);
        Map<Id, List<Id>> result = new Map<Id, List<Id>>();
        if (groupOrUserIds == null || groupOrUserIds.isEmpty()) return result;

        Set<Id> groupIds = new Set<Id>();
        for (Id id : groupOrUserIds) {
            if (String.valueOf(id).left(3) == '005') {
                result.put(id, new List<Id>{ id });
                System.debug('DBG resolveMembers | user passthrough: ' + id);
            } else {
                groupIds.add(id);
                result.put(id, new List<Id>());
                System.debug('DBG resolveMembers | group/queue to expand: ' + id);
            }
        }
        if (groupIds.isEmpty()) return result;

        // First-level members
        Map<Id, Id> subGroupToTopGroup = new Map<Id, Id>(); // sub-group Id → top-level group Id
        List<GroupMember> firstLevelMembers = [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :groupIds];
        System.debug('DBG resolveMembers | first-level GroupMember count=' + firstLevelMembers.size());
        for (GroupMember gm : firstLevelMembers) {
            if (String.valueOf(gm.UserOrGroupId).left(3) == '005') {
                result.get(gm.GroupId).add(gm.UserOrGroupId);
                System.debug('DBG resolveMembers | direct user: groupId=' + gm.GroupId + ' userId=' + gm.UserOrGroupId);
            } else {
                subGroupToTopGroup.put(gm.UserOrGroupId, gm.GroupId);
                System.debug('DBG resolveMembers | sub-group: subGroupId=' + gm.UserOrGroupId + ' parentGroupId=' + gm.GroupId);
            }
        }
        System.debug('DBG resolveMembers | subGroupToTopGroup.size=' + subGroupToTopGroup.size());
        if (subGroupToTopGroup.isEmpty()) return result;

        // Classify sub-groups by type
        Set<Id> publicGroupIds    = new Set<Id>();
        Map<Id, Id> roleGrpToRole = new Map<Id, Id>(); // role-group Id → UserRole Id
        for (Group g : [SELECT Id, Type, RelatedId FROM Group WHERE Id IN :subGroupToTopGroup.keySet()]) {
            System.debug('DBG resolveMembers | sub-group classified: id=' + g.Id + ' type=' + g.Type + ' relatedId=' + g.RelatedId);
            if (g.Type == 'Regular') {
                publicGroupIds.add(g.Id);
            } else if (g.Type == 'Role' || g.Type == 'RoleAndSubordinates') {
                roleGrpToRole.put(g.Id, g.RelatedId);
            }
        }
        System.debug('DBG resolveMembers | publicGroupIds=' + publicGroupIds + ' | roleGrpToRole.size=' + roleGrpToRole.size());

        // Public groups — query their direct user members
        if (!publicGroupIds.isEmpty()) {
            for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :publicGroupIds]) {
                if (String.valueOf(gm.UserOrGroupId).left(3) == '005') {
                    Id topGroupId = subGroupToTopGroup.get(gm.GroupId);
                    if (topGroupId != null) result.get(topGroupId).add(gm.UserOrGroupId);
                }
            }
        }

        // Role groups — query active users with matching UserRoleId
        if (!roleGrpToRole.isEmpty()) {
            Set<Id> roleIds = new Set<Id>(roleGrpToRole.values());
            Map<Id, List<Id>> usersByRole = new Map<Id, List<Id>>();
            for (User u : [SELECT Id, UserRoleId FROM User WHERE UserRoleId IN :roleIds AND IsActive = true]) {
                System.debug('DBG resolveMembers | role user: id=' + u.Id + ' roleId=' + u.UserRoleId);
                if (!usersByRole.containsKey(u.UserRoleId)) usersByRole.put(u.UserRoleId, new List<Id>());
                usersByRole.get(u.UserRoleId).add(u.Id);
            }
            for (Id roleGrpId : roleGrpToRole.keySet()) {
                Id roleId   = roleGrpToRole.get(roleGrpId);
                Id topGrpId = subGroupToTopGroup.get(roleGrpId);
                if (topGrpId == null || !usersByRole.containsKey(roleId)) continue;
                result.get(topGrpId).addAll(usersByRole.get(roleId));
            }
        }

        System.debug('DBG resolveMembers | final result=' + result);
        return result;
    }

    public static Map<String, Set<String>> getQueueMemberEmails(Set<String> developerNames) {
        Map<String, Set<String>> result = new Map<String, Set<String>>();
        if (developerNames == null || developerNames.isEmpty()) return result;

        Map<Id, String> queueIdToDevName = new Map<Id, String>();
        for (Group q : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :developerNames]) {
            queueIdToDevName.put(q.Id, q.DeveloperName);
            result.put(q.DeveloperName, new Set<String>());
        }
        if (queueIdToDevName.isEmpty()) return result;

        Map<Id, List<Id>> membersByQueue = resolveMembers(queueIdToDevName.keySet());

        Set<Id> allUserIds = new Set<Id>();
        for (List<Id> userIds : membersByQueue.values()) allUserIds.addAll(userIds);

        Map<Id, String> emailByUserId = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :allUserIds AND IsActive = true]) {
            if (String.isNotBlank(u.Email)) emailByUserId.put(u.Id, u.Email);
        }

        for (Id queueId : membersByQueue.keySet()) {
            String devName = queueIdToDevName.get(queueId);
            if (devName == null) continue;
            for (Id userId : membersByQueue.get(queueId)) {
                String email = emailByUserId.get(userId);
                if (String.isNotBlank(email)) result.get(devName).add(email);
            }
        }

        return result;
    }

    public static Id getQueueId(String developerName) {
        List<Group> groups = [SELECT Id FROM Group WHERE DeveloperName = :developerName AND Type = 'Queue' LIMIT 1];
        return groups.isEmpty() ? null : groups[0].Id;
    }
}