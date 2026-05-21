/** ──────────────────────────────────────
 * @description Service class for resolving Salesforce queue membership.
 *              Supports direct and nested group membership lookups, returning
 *              member user IDs or email addresses by queue developer name.
 *              Used by EmailService for recipient resolution and by
 *              CustomApprovalHistoryController for permission checks.
 * @author Charles EID
 * @testClass QueueMemberServiceTest
 * @coverage 100%   [20-05-26]
 ────────────────────────────────────── */
public without sharing class QueueMemberService {

    public static Map<String, Set<String>> getQueueMemberEmails(Set<String> developerNames) {
        Map<Id, String> queueIdToDevName = new Map<Id, String>();
        Map<String, Set<String>> result = new Map<String, Set<String>>();

        for (Group q : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :developerNames]) {
            queueIdToDevName.put(q.Id, q.DeveloperName);
            result.put(q.DeveloperName, new Set<String>());
        }

        Map<Id, Set<String>> groupIdToQueueDevNames = new Map<Id, Set<String>>();
        Set<Id> nestedGroupIds = new Set<Id>();

        for (GroupMember gm : [SELECT GroupId, UserOrGroupId, UserOrGroup.Email FROM GroupMember WHERE GroupId IN :queueIdToDevName.keySet()]) {
            String queueDevName = queueIdToDevName.get(gm.GroupId);
            if (String.isNotBlank(gm.UserOrGroup.Email)) {
                result.get(queueDevName).add(gm.UserOrGroup.Email);
            } else {
                nestedGroupIds.add(gm.UserOrGroupId);
                if (!groupIdToQueueDevNames.containsKey(gm.UserOrGroupId)) {
                    groupIdToQueueDevNames.put(gm.UserOrGroupId, new Set<String>());
                }
                groupIdToQueueDevNames.get(gm.UserOrGroupId).add(queueDevName);
            }
        }

        if (!nestedGroupIds.isEmpty()) {
            for (GroupMember gm : [SELECT GroupId, UserOrGroupId, UserOrGroup.Email FROM GroupMember WHERE GroupId IN :nestedGroupIds]) {
                if (String.isNotBlank(gm.UserOrGroup.Email)) {
                    for (String queueDevName : groupIdToQueueDevNames.get(gm.GroupId)) {
                        result.get(queueDevName).add(gm.UserOrGroup.Email);
                    }
                }
            }
        }
        return result;
    }

    public static Map<String, Set<Id>> getQueueMemberIds(Set<String> developerNames) {
        Map<Id, String> queueIdToDevName = new Map<Id, String>();
        Map<String, Set<Id>> result = new Map<String, Set<Id>>();

        for (Group q : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :developerNames]) {
            queueIdToDevName.put(q.Id, q.DeveloperName);
            result.put(q.DeveloperName, new Set<Id>());
        }

        Map<Id, Set<String>> groupIdToQueueDevNames = new Map<Id, Set<String>>();
        Set<Id> nestedGroupIds = new Set<Id>();

        for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :queueIdToDevName.keySet()]) {
            String queueDevName = queueIdToDevName.get(gm.GroupId);
            String idPrefix = String.valueOf(gm.UserOrGroupId).left(3);
            if (idPrefix == '005') {
                result.get(queueDevName).add(gm.UserOrGroupId);
            } else {
                nestedGroupIds.add(gm.UserOrGroupId);
                if (!groupIdToQueueDevNames.containsKey(gm.UserOrGroupId)) {
                    groupIdToQueueDevNames.put(gm.UserOrGroupId, new Set<String>());
                }
                groupIdToQueueDevNames.get(gm.UserOrGroupId).add(queueDevName);
            }
        }

        if (!nestedGroupIds.isEmpty()) {
            for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :nestedGroupIds]) {
                String idPrefix = String.valueOf(gm.UserOrGroupId).left(3);
                if (idPrefix == '005') {
                    for (String queueDevName : groupIdToQueueDevNames.get(gm.GroupId)) {
                        result.get(queueDevName).add(gm.UserOrGroupId);
                    }
                }
            }
        }
        return result;
    }

    public static Id getQueueId(String developerName) {
        List<Group> groups = [SELECT Id FROM Group WHERE DeveloperName = :developerName AND Type = 'Queue' LIMIT 1];
        return groups.isEmpty() ? null : groups[0].Id;
    }

    public static Set<Id> getQueuesContainingUser(Set<Id> queueIds, Id userId) {
        Set<Id> memberOf = new Set<Id>();
        if (queueIds == null || queueIds.isEmpty()) return memberOf;

        // Step 1: collect all members of these queues
        Map<Id, Id> memberToQueue = new Map<Id, Id>(); // non-user member Id → queue Id
        for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :queueIds]) {
            if (gm.UserOrGroupId == userId) {
                memberOf.add(gm.GroupId);
            } else {
                memberToQueue.put(gm.UserOrGroupId, gm.GroupId);
            }
        }
        if (memberToQueue.isEmpty()) return memberOf;

        // Step 2: resolve group types — public groups vs role groups
        Set<Id> publicGroupIds    = new Set<Id>();
        Map<Id, Id> roleGrpToRole = new Map<Id, Id>(); // role-group Id → UserRole Id
        for (Group g : [SELECT Id, Type, RelatedId FROM Group WHERE Id IN :memberToQueue.keySet()]) {
            if (g.Type == 'Regular') {
                publicGroupIds.add(g.Id);
            } else if (g.Type == 'Role' || g.Type == 'RoleAndSubordinates') {
                roleGrpToRole.put(g.Id, g.RelatedId);
            }
        }

        // Step 3: check public group membership via GroupMember
        if (!publicGroupIds.isEmpty()) {
            for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE GroupId IN :publicGroupIds AND UserOrGroupId = :userId]) {
                memberOf.add(memberToQueue.get(gm.GroupId));
            }
        }

        // Step 4: check role membership via User.UserRoleId
        if (!roleGrpToRole.isEmpty()) {
            Id userRoleId = [SELECT UserRoleId FROM User WHERE Id = :userId LIMIT 1].UserRoleId;
            if (userRoleId != null) {
                for (Id roleGrpId : roleGrpToRole.keySet()) {
                    if (roleGrpToRole.get(roleGrpId) == userRoleId) {
                        memberOf.add(memberToQueue.get(roleGrpId));
                    }
                }
            }
        }

        return memberOf;
    }

    public static Boolean isUserInQueue(Id userId, Id queueId) {
        List<GroupMember> directMembers = [SELECT Id FROM GroupMember WHERE GroupId = :queueId AND UserOrGroupId = :userId LIMIT 1];
        if (!directMembers.isEmpty()) {
            return true;
        }
        Set<Id> nestedGroupIds = new Set<Id>();
        for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queueId]) {
            String idPrefix = String.valueOf(gm.UserOrGroupId).left(3);
            if (idPrefix != '005') {
                nestedGroupIds.add(gm.UserOrGroupId);
            }
        }
        if (!nestedGroupIds.isEmpty()) {
            List<GroupMember> nestedMembers = [SELECT Id FROM GroupMember WHERE GroupId IN :nestedGroupIds AND UserOrGroupId = :userId LIMIT 1];
            return !nestedMembers.isEmpty();
        }
        return false;
    }
}