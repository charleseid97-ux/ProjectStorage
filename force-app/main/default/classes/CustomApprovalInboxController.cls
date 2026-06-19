/** ──────────────────────────────────────
 * @description AuraEnabled controller for the Custom Approval Inbox LWC.
 *              Returns up to 10 pending CustomApprovalStep__c records that the
 *              current user is authorised to approve, across all target objects.
 *              Resolves target record names, object labels, and the name of whoever
 *              last acted on the approval (submittedByName).
 * @author Charles EID
 ────────────────────────────────────── */
public without sharing class CustomApprovalInboxController {

    // ─── getItemsToApprove ───────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<ItemToApprove> getItemsToApprove() {
        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin  = CustomApprovalHistoryUtility.isAdministrator(currentUserId);

        List<CustomApprovalStep__c> allPending = queryPendingSteps();
        Map<Id, List<Id>> resolvedQueueMembers = resolveQueueMemberships(allPending);
        List<CustomApprovalStep__c> approvable = filterToApprovable(allPending, isAdmin, currentUserId, resolvedQueueMembers);

        if (approvable.isEmpty()) return new List<ItemToApprove>();

        Map<String, Boolean> stepDevNameHasUserInput = CustomApprovalHistoryUtility.buildStepConfigMap(collectProcessDevNames(approvable));
        Map<Id, String> submittedByPerApproval       = buildSubmittedByMap(collectApprovalIds(approvable));

        return buildResult(approvable, stepDevNameHasUserInput, submittedByPerApproval);
    }

    // ─── Query ───────────────────────────────────────────────────────────────────
    private static List<CustomApprovalStep__c> queryPendingSteps() {
        return [SELECT Id, StepLabel__c, StepDeveloperName__c, AssignedTo__c, AssignedToName__c, CreatedDate,
                       PreviousApprover__r.Name,
                       CustomApproval__c, CustomApproval__r.TargetRecordId__c, CustomApproval__r.RelatedToLabel__c,
                       CustomApproval__r.ProcessDeveloperName__c,
                       CustomApproval__r.SubmittedBy__r.Name, CustomApproval__r.TECH_ReadOnly__c, CustomApproval__r.CreatedDate
                FROM CustomApprovalStep__c
                WHERE IsCurrentStep__c = true
                  AND Status__c = 'Pending'
                ORDER BY CustomApproval__r.CreatedDate ASC];
    }

    // ─── Queue resolution ─────────────────────────────────────────────────────────
    private static Map<Id, List<Id>> resolveQueueMemberships(List<CustomApprovalStep__c> steps) {
        Set<Id> queueIds = new Set<Id>();
        for (CustomApprovalStep__c s : steps) {
            if (String.isNotBlank(s.AssignedTo__c) && s.AssignedTo__c.startsWith('00G')) {
                queueIds.add((Id) s.AssignedTo__c);
            }
        }
        return QueueMemberService.resolveMembers(queueIds);
    }

    // ─── Permission filter ────────────────────────────────────────────────────────
    private static List<CustomApprovalStep__c> filterToApprovable(List<CustomApprovalStep__c> allPending, Boolean isAdmin, Id currentUserId, Map<Id, List<Id>> resolvedQueueMembers) {
        List<CustomApprovalStep__c> approvable = new List<CustomApprovalStep__c>();
        for (CustomApprovalStep__c s : allPending) {
            if (s.CustomApproval__r?.TECH_ReadOnly__c == true) continue;
            if (canUserApprove(s, isAdmin, currentUserId, resolvedQueueMembers)) {
                approvable.add(s);
            }
        }
        return approvable;
    }

    private static Boolean canUserApprove(CustomApprovalStep__c s, Boolean isAdmin, Id currentUserId, Map<Id, List<Id>> resolvedQueueMembers) {
        if (isAdmin) return true;
        if (String.isBlank(s.AssignedTo__c)) return false;
        Id assignedId = (Id) s.AssignedTo__c;
        String prefix = String.valueOf(assignedId).left(3);
        if (prefix == '005') return assignedId == currentUserId;
        if (prefix == '00G') {
            List<Id> members = resolvedQueueMembers.get(assignedId);
            return members != null && members.contains(currentUserId);
        }
        return false;
    }

    // ─── Collection helpers ───────────────────────────────────────────────────────
    private static Set<Id> collectApprovalIds(List<CustomApprovalStep__c> steps) {
        Set<Id> ids = new Set<Id>();
        for (CustomApprovalStep__c s : steps) ids.add(s.CustomApproval__c);
        return ids;
    }

    private static Set<String> collectProcessDevNames(List<CustomApprovalStep__c> steps) {
        Set<String> names = new Set<String>();
        for (CustomApprovalStep__c s : steps) {
            if (String.isNotBlank(s.CustomApproval__r?.ProcessDeveloperName__c)) {
                names.add(s.CustomApproval__r.ProcessDeveloperName__c);
            }
        }
        return names;
    }

    // ─── Submitted-by resolution ──────────────────────────────────────────────────
    private static Map<Id, String> buildSubmittedByMap(Set<Id> approvalIds) {
        Map<Id, String> result = new Map<Id, String>();
        for (CustomApprovalStep__c s : [SELECT CustomApproval__c, ActualApprover__r.Name
                                        FROM   CustomApprovalStep__c
                                        WHERE  CustomApproval__c IN :approvalIds
                                          AND  Status__c         = 'Approved'
                                        ORDER BY ActionDate__c DESC NULLS LAST]) {
            if (!result.containsKey(s.CustomApproval__c)) {
                result.put(s.CustomApproval__c, s.ActualApprover__r?.Name);
            }
        }
        return result;
    }

    // ─── Result builder ───────────────────────────────────────────────────────────
    private static List<ItemToApprove> buildResult(List<CustomApprovalStep__c> approvable, Map<String, Boolean> stepDevNameHasUserInput, Map<Id, String> submittedByPerApproval) {
        List<ItemToApprove> result = new List<ItemToApprove>();
        for (CustomApprovalStep__c s : approvable) {
            result.add(buildItem(s, stepDevNameHasUserInput, submittedByPerApproval));
        }
        return result;
    }

    private static ItemToApprove buildItem(CustomApprovalStep__c s, Map<String, Boolean> stepDevNameHasUserInput, Map<Id, String> submittedByPerApproval) {
        ItemToApprove item = new ItemToApprove();
        item.stepId    = s.Id;
        item.stepLabel = String.isNotBlank(s.StepLabel__c) ? s.StepLabel__c : s.StepDeveloperName__c;
        item.nextApproverSource = stepDevNameHasUserInput.get(s.StepDeveloperName__c) == true ? 'UserInput' : null;

        String rawId = s.CustomApproval__r?.TargetRecordId__c;
        item.targetRecordId   = rawId;
        item.targetRecordName = String.isNotBlank(s.CustomApproval__r?.RelatedToLabel__c) ? s.CustomApproval__r?.RelatedToLabel__c : 'View Record';

        if (String.isNotBlank(rawId)) {
            try {
                item.objectLabel = ((Id) rawId).getSObjectType().getDescribe().getLabel();
            } catch (Exception e) { /* skip malformed Id */ }
        }

        item.submittedByName        = submittedByPerApproval.containsKey(s.CustomApproval__c) ? submittedByPerApproval.get(s.CustomApproval__c) : s.CustomApproval__r?.SubmittedBy__r?.Name;
        item.assignedToName         = s.AssignedToName__c;
        item.stepDateFormatted      = s.CreatedDate != null ? s.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
        item.previousApproverName   = s.PreviousApprover__r?.Name;
        item.submissionDateFormatted = s.CustomApproval__r?.CreatedDate != null ? s.CustomApproval__r.CreatedDate.format('dd/MM/yyyy HH:mm') : '';

        return item;
    }

    public class ItemToApprove {
        @AuraEnabled public String stepId;
        @AuraEnabled public String targetRecordId;
        @AuraEnabled public String targetRecordName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String submittedByName;
        @AuraEnabled public String nextApproverSource;
        @AuraEnabled public String stepLabel;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public String stepDateFormatted;
        @AuraEnabled public String previousApproverName;
        @AuraEnabled public String submissionDateFormatted;
    }
}