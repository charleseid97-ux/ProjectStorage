/** ──────────────────────────────────────
 * @description AuraEnabled controller for the Custom Approval History LWC.
 *              Exposes approval history retrieval, approval/rejection/recall actions,
 *              and process submission to the front-end. Resolves user and queue-based
 *              permissions to determine which actions the current user may take.
 * @author Charles EID
 * @testClass CustomApprovalHistoryControllerTest
 * @coverage 85%   [20-05-26]
 ────────────────────────────────────── */
public with sharing class CustomApprovalHistoryController {

    // ─── getApprovalHistory ──────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ApprovalHistoryResult getApprovalHistory(Id recordId) {
        ApprovalHistoryResult result = new ApprovalHistoryResult();
        result.rows               = new List<ApprovalRow>();
        result.canApproveOrReject = false;
        result.canRecall          = false;
        result.processStatus      = null;

        if (recordId == null) return result;

        List<CustomApproval__c> approvals = [SELECT Id, Status__c, SubmittedBy__c, ProcessDeveloperName__c, CreatedDate, Comments__c
                                             FROM CustomApproval__c
                                             WHERE TargetRecordId__c = :String.valueOf(recordId)
                                             ORDER BY CreatedDate DESC];
        if (approvals.isEmpty()) return result;

        Set<Id> approvalIds = new Map<Id, CustomApproval__c>(approvals).keySet();
        Id currentUserId    = UserInfo.getUserId();
        Boolean isAdmin     = isAdministrator(currentUserId);

        List<CustomApprovalStep__c> steps = [SELECT Id, CustomApproval__c, StepLabel__c, StepDeveloperName__c, Status__c,
                                                    AssignedTo__c, AssignedToName__c, OriginalAssignedTo__c, OriginalAssignedToName__c,
                                                    ActualApprover__r.Name, Comments__c, ActionDate__c, IsCurrentStep__c,
                                                    CustomApproval__r.ProcessDeveloperName__c, CreatedDate
                                             FROM CustomApprovalStep__c
                                             WHERE CustomApproval__c IN :approvalIds
                                             ORDER BY CustomApproval__r.CreatedDate DESC, ActionDate__c ASC NULLS LAST, CreatedDate ASC];

        Boolean canApproveOrReject = false;
        Boolean canRecall          = false;

        Set<Id> queueIdsToCheck = new Set<Id>();
        for (CustomApprovalStep__c s : steps) {
            if (s.IsCurrentStep__c && String.isNotBlank(s.AssignedTo__c) && s.AssignedTo__c.startsWith('00G')) {
                queueIdsToCheck.add((Id) s.AssignedTo__c);
            }
        }
        Set<Id> userQueueIds = QueueMemberService.getQueuesContainingUser(queueIdsToCheck, currentUserId);

        Set<String> processDevNames = new Set<String>();
        for (CustomApproval__c a : approvals) {
            processDevNames.add(a.ProcessDeveloperName__c);
        }
        Map<String, Boolean> stepDevNameHasUserInput = buildStepConfigMap(processDevNames);

        for (CustomApprovalStep__c s : steps) {
            ApprovalRow row = buildRow(s);
            if (s.IsCurrentStep__c) {
                Boolean rowCanApprove = false;
                if (isAdmin) {
                    rowCanApprove = true;
                } else if (String.isNotBlank(s.AssignedTo__c)) {
                    Id assignedId = (Id) s.AssignedTo__c;
                    String prefix = String.valueOf(assignedId).left(3);
                    if (prefix == '005' && assignedId == currentUserId) {
                        rowCanApprove = true;
                    } else if (prefix == '00G' && userQueueIds.contains(assignedId)) {
                        rowCanApprove = true;
                    }
                }
                row.canApproveOrReject = rowCanApprove;
                if (rowCanApprove) canApproveOrReject = true;
            } else {
                row.canApproveOrReject = false;
            }
            result.rows.add(row);
        }

        for (CustomApproval__c a : approvals) {
            if (!canRecall && a.Status__c == 'Pending' && (isAdmin || a.SubmittedBy__c == currentUserId)) {
                canRecall = true;
            }
        }

        result.canApproveOrReject = canApproveOrReject;
        result.canRecall          = canRecall;
        result.processStatus      = approvals[0].Status__c;
        return result;
    }

    // ─── processApproval ────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static CustomApprovalHistoryUtility.ProcessResult processApproval(Id workItemId, String action, String comments, List<Id> nextApproverIds) {
        return CustomApprovalHistoryUtility.processApproval(workItemId, action, comments, nextApproverIds);
    }

    // ─── submitForApproval ──────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static CustomApprovalHistoryUtility.ProcessResult submitForApproval(Id recordId, String processName, String comments) {
        return CustomApprovalHistoryUtility.submitForApproval(recordId, processName, comments);
    }

    // ─── Permissions ────────────────────────────────────────────────────────────
    private static Boolean isAdministrator(Id userId) {
        for (PermissionSetAssignment psa : [SELECT Id
                                            FROM PermissionSetAssignment
                                            WHERE AssigneeId = :userId
                                              AND PermissionSet.IsOwnedByProfile = true
                                              AND PermissionSet.Profile.Name LIKE '%Administrator%' LIMIT 1]) {
            return true;
        }
        return false;
    }

    private static Map<String, Boolean> buildStepConfigMap(Set<String> processDevNames) {
        Map<String, Boolean> result = new Map<String, Boolean>();
        for (ApprovalStepApproverConfig__mdt cfg : [SELECT StepConfig__r.DeveloperName, ApproverSource__c
                                                    FROM ApprovalStepApproverConfig__mdt
                                                    WHERE StepConfig__r.ProcessConfig__r.DeveloperName IN :processDevNames]) {
            if (cfg.ApproverSource__c == 'UserInput') {
                result.put(cfg.StepConfig__r.DeveloperName, true);
            }
        }
        return result;
    }

    // ─── Row builder ────────────────────────────────────────────────────────────
    private static ApprovalRow buildRow(CustomApprovalStep__c s) {
        ApprovalRow row       = new ApprovalRow();
        row.id                = s.Id;
        row.workItemId        = s.IsCurrentStep__c ? s.Id : null;
        row.stepName          = String.isNotBlank(s.StepLabel__c) ? s.StepLabel__c : s.StepDeveloperName__c;
        row.stepDate          = s.ActionDate__c != null ? s.ActionDate__c : s.CreatedDate;
        row.stepDateFormatted = formatDatetime(row.stepDate);
        row.status            = s.Status__c;
        row.assignedTo        = String.isNotBlank(s.OriginalAssignedToName__c) ? s.OriginalAssignedToName__c : s.AssignedToName__c;
        row.actualApprover    = s.ActualApprover__r?.Name;
        row.comments          = s.Comments__c;
        row.isPending         = s.IsCurrentStep__c;
        row.processName       = s.CustomApproval__r?.ProcessDeveloperName__c;
        row.nextApproverSource = null;
        return row;
    }

    private static String formatDatetime(Datetime dt) {
        if (dt == null) return '';
        return dt.format('dd/MM/yyyy HH:mm');
    }

    // ─── Wrapper classes ────────────────────────────────────────────────────────
    public class ApprovalRow {
        @AuraEnabled public String   id;
        @AuraEnabled public String   workItemId;
        @AuraEnabled public String   stepName;
        @AuraEnabled public Datetime stepDate;
        @AuraEnabled public String   stepDateFormatted;
        @AuraEnabled public String   status;
        @AuraEnabled public String   assignedTo;
        @AuraEnabled public String   actualApprover;
        @AuraEnabled public String   comments;
        @AuraEnabled public Boolean  isPending;
        @AuraEnabled public Boolean  canApproveOrReject;
        @AuraEnabled public String   processName;
        @AuraEnabled public String   nextApproverSource;
    }

    public class ApprovalHistoryResult {
        @AuraEnabled public List<ApprovalRow> rows;
        @AuraEnabled public Boolean canApproveOrReject;
        @AuraEnabled public Boolean canRecall;
        @AuraEnabled public String  processStatus;
    }
}