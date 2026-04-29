/** ──────────────────────────────────────
 * @description Generic Apex controller for the customApprovalHistory LWC.
 *              Retrieves the full approval history for any SObject record across all ProcessInstance attempts,
 *              and processes Approve / Reject / Recall actions with dynamic next-approver resolution
 *              driven by ApprovalStepConfig__mdt custom metadata.
 * @author Charles EID
 * @testClass CustomApprovalHistoryControllerTest
────────────────────────────────────── */
public with sharing class CustomApprovalHistoryController {

    // ─────────────────────────────────────── getApprovalHistory ───────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ApprovalHistoryResult getApprovalHistory(Id recordId) {
        ApprovalHistoryResult result = new ApprovalHistoryResult();
        result.rows               = new List<ApprovalRow>();
        result.canApproveOrReject = false;
        result.canRecall          = false;
        result.processStatus      = null;

        if (recordId == null) return result;

        List<ProcessInstance> instances = queryProcessInstances(recordId);
        if (instances.isEmpty()) return result;

        Set<Id> piIds    = new Map<Id, ProcessInstance>(instances).keySet();
        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin  = isAdministrator(currentUserId);

        List<ProcessInstanceStep> steps         = querySteps(piIds);
        List<ProcessInstanceNode> pins          = queryNodes(piIds);
        List<ProcessInstanceWorkitem> workItems = queryWorkItems(piIds);

        Map<Id, String> nodeIdToLabel                      = buildNodeIdToLabel(pins);
        Map<Id, Id> piIdToActiveNodeId                     = buildPiIdToActiveNodeId(pins);
        Map<Id, ProcessInstanceWorkitem> piIdToWorkItem    = buildWorkItemMap(workItems);
        Set<Id> userQueueIds                               = resolveUserQueueMembership(workItems, currentUserId);
        Map<String, ApprovalStepConfig__mdt> stepConfigMap = buildStepConfigMap(instances);

        Boolean canApproveOrReject = false;
        Boolean canRecall          = false;

        for (ProcessInstance pi : instances) {
            for (ProcessInstanceStep step : steps) {
                if (step.ProcessInstanceId != pi.Id) continue;
                result.rows.add(buildCompletedRow(step, pi.ProcessDefinition.Name, pins, nodeIdToLabel));
            }

            if (piIdToWorkItem.containsKey(pi.Id)) {
                ProcessInstanceWorkitem wi = piIdToWorkItem.get(pi.Id);
                String stepLabel           = resolveActiveStepLabel(pi.Id, piIdToActiveNodeId, nodeIdToLabel);
                String cfgKey              = pi.ProcessDefinition.DeveloperName + '__' + (stepLabel != null ? stepLabel : '');
                String nextApproverSource  = stepConfigMap.containsKey(cfgKey) ? stepConfigMap.get(cfgKey).NextApproverSource__c : null;

                result.rows.add(buildPendingRow(wi, pi.ProcessDefinition.Name, stepLabel, nextApproverSource));

                if (!canApproveOrReject) {
                    canApproveOrReject = canApproveOrRejectWorkItem(wi.ActorId, currentUserId, userQueueIds, isAdmin);
                }
            }

            if (!canRecall && isRecallEligible(pi, currentUserId, isAdmin)) {
                canRecall = true;
            }
        }

        result.canApproveOrReject = canApproveOrReject;
        result.canRecall          = canRecall;
        result.processStatus      = instances[0].Status;
        return result;
    }

    // ─────────────────────────────────────── processApproval ───────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static CustomApprovalHistoryUtility.ProcessResult processApproval(Id workItemId, String action, String comments, List<Id> nextApproverIds) {
        return CustomApprovalHistoryUtility.processApproval(workItemId, action, comments, nextApproverIds);
    }

    // ─────────────────────────────────────── Queries ───────────────────────────────────────
    private static List<ProcessInstance> queryProcessInstances(Id recordId) {
        return [SELECT Id, Status, SubmittedById, CreatedDate, ProcessDefinition.Name, ProcessDefinition.DeveloperName
                FROM ProcessInstance
                WHERE TargetObjectId = :recordId
                ORDER BY CreatedDate DESC];
    }

    private static List<ProcessInstanceStep> querySteps(Set<Id> piIds) {
        return [SELECT Id, StepNodeId, StepStatus, Comments, CreatedDate, Actor.Name, OriginalActor.Name, ProcessInstanceId
                FROM ProcessInstanceStep
                WHERE ProcessInstanceId IN :piIds
                ORDER BY CreatedDate ASC];
    }

    private static List<ProcessInstanceNode> queryNodes(Set<Id> piIds) {
        // Sort ASC so the last entry per PI is the most recently active node
        return [SELECT Id, ProcessInstanceId, ProcessNodeId, ProcessNodeName, NodeStatus
                FROM ProcessInstanceNode
                WHERE ProcessInstanceId IN :piIds
                ORDER BY CreatedDate ASC];
    }

    private static List<ProcessInstanceWorkitem> queryWorkItems(Set<Id> piIds) {
        return [SELECT Id, ProcessInstanceId, ActorId, Actor.Name, OriginalActorId, OriginalActor.Name, CreatedDate
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstanceId IN :piIds];
    }

    // ─────────────────────────────────────── Map builders ───────────────────────────────────────
    private static Map<Id, String> buildNodeIdToLabel(List<ProcessInstanceNode> pins) {
        Map<Id, String> m = new Map<Id, String>();
        for (ProcessInstanceNode pin : pins) {
            if (pin.ProcessNodeId != null && String.isNotBlank(pin.ProcessNodeName)) {
                m.put(pin.ProcessNodeId, pin.ProcessNodeName);
            }
        }
        return m;
    }

    private static Map<Id, Id> buildPiIdToActiveNodeId(List<ProcessInstanceNode> pins) {
        Map<Id, Id> m = new Map<Id, Id>();
        for (ProcessInstanceNode pin : pins) {
            if (pin.ProcessNodeId != null) {
                m.put(pin.ProcessInstanceId, pin.ProcessNodeId);
            }
        }
        return m;
    }

    private static Map<Id, ProcessInstanceWorkitem> buildWorkItemMap(List<ProcessInstanceWorkitem> workItems) {
        Map<Id, ProcessInstanceWorkitem> m = new Map<Id, ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem wi : workItems) {
            m.put(wi.ProcessInstanceId, wi);
        }
        return m;
    }

    private static Map<String, ApprovalStepConfig__mdt> buildStepConfigMap(List<ProcessInstance> instances) {
        Set<String> processDevNames = new Set<String>();
        for (ProcessInstance pi : instances) {
            processDevNames.add(pi.ProcessDefinition.DeveloperName);
        }
        Map<String, ApprovalStepConfig__mdt> m = new Map<String, ApprovalStepConfig__mdt>();
        for (ApprovalStepConfig__mdt cfg : [SELECT ProcessConfig__r.ProcessDeveloperName__c, StepDeveloperName__c, NextApproverSource__c, ApproverResolverClass__c
                                            FROM ApprovalStepConfig__mdt
                                            WHERE ProcessConfig__r.ProcessDeveloperName__c IN :processDevNames]) {
            m.put(cfg.ProcessConfig__r.ProcessDeveloperName__c + '__' + cfg.StepDeveloperName__c, cfg);
        }
        return m;
    }

    // ─────────────────────────────────────── Permissions ───────────────────────────────────────
    private static Boolean isAdministrator(Id userId) {
        for (PermissionSetAssignment psa : [SELECT Id FROM PermissionSetAssignment
                                            WHERE AssigneeId = :userId
                                            AND PermissionSet.IsOwnedByProfile = true
                                            AND PermissionSet.Profile.Name LIKE '%Administrator%'
                                            LIMIT 1]) {
            return true;
        }
        return false;
    }

    // Returns the subset of queue ActorIds that the current user is a member of.
    // Queue IDs start with '00G' (Group prefix); User IDs start with '005'.
    private static Set<Id> resolveUserQueueMembership(List<ProcessInstanceWorkitem> workItems, Id currentUserId) {
        Set<Id> queueActorIds = new Set<Id>();
        for (ProcessInstanceWorkitem wi : workItems) {
            if (wi.ActorId != null && String.valueOf(wi.ActorId).startsWith('00G')) {
                queueActorIds.add(wi.ActorId);
            }
        }
        Set<Id> userQueueIds = new Set<Id>();
        if (!queueActorIds.isEmpty()) {
            for (GroupMember gm : [SELECT GroupId FROM GroupMember
                                   WHERE GroupId IN :queueActorIds
                                   AND UserOrGroupId = :currentUserId]) {
                userQueueIds.add(gm.GroupId);
            }
        }
        return userQueueIds;
    }

    private static Boolean canApproveOrRejectWorkItem(Id actorId, Id currentUserId, Set<Id> userQueueIds, Boolean isAdmin) {
        return isAdmin || actorId == currentUserId || userQueueIds.contains(actorId);
    }

    // AllowRecall is enforced server-side by Salesforce — only check pending + submitter/admin here.
    private static Boolean isRecallEligible(ProcessInstance pi, Id userId, Boolean isAdmin) {
        return pi.Status == 'Pending' && (isAdmin || pi.SubmittedById == userId);
    }

    // ─────────────────────────────────────── Row builders ───────────────────────────────────────
    private static ApprovalRow buildCompletedRow(ProcessInstanceStep step, String processName, List<ProcessInstanceNode> pins, Map<Id, String> nodeIdToLabel) {
        String resolvedName = resolveStepName(step.StepNodeId, pins, nodeIdToLabel);
        ApprovalRow row = new ApprovalRow();
        row.id                 = step.Id;
        row.workItemId         = null;
        row.stepName           = String.isNotBlank(resolvedName) ? resolvedName : (step.StepStatus == 'Started' ? 'Approval Request Submitted' : step.StepStatus);
        row.stepDate           = step.CreatedDate;
        row.stepDateFormatted  = formatDatetime(step.CreatedDate);
        row.status             = step.StepStatus == 'Started' ? 'Submitted' : step.StepStatus;
        row.assignedTo         = step.OriginalActor?.Name;
        row.actualApprover     = step.Actor?.Name;
        row.comments           = step.Comments;
        row.isPending          = false;
        row.processName        = processName;
        row.nextApproverSource = null;
        return row;
    }

    private static ApprovalRow buildPendingRow(ProcessInstanceWorkitem wi, String processName, String stepLabel, String nextApproverSource) {
        ApprovalRow row = new ApprovalRow();
        row.id                 = wi.Id;
        row.workItemId         = wi.Id;
        row.stepName           = stepLabel != null ? stepLabel : 'Pending';
        row.stepDate           = wi.CreatedDate;
        row.stepDateFormatted  = formatDatetime(wi.CreatedDate);
        row.status             = 'Pending';
        row.assignedTo         = wi.OriginalActor?.Name;
        row.actualApprover     = wi.Actor?.Name;
        row.comments           = null;
        row.isPending          = true;
        row.processName        = processName;
        row.nextApproverSource = nextApproverSource;
        return row;
    }

    // ─────────────────────────────────────── Private helpers ───────────────────────────────────────
    private static String resolveActiveStepLabel(Id piId, Map<Id, Id> piIdToActiveNodeId, Map<Id, String> nodeIdToLabel) {
        Id activeNodeId = piIdToActiveNodeId.get(piId);
        return activeNodeId != null ? nodeIdToLabel.get(activeNodeId) : null;
    }

    private static String resolveStepName(Id stepNodeId, List<ProcessInstanceNode> pins, Map<Id, String> nodeIdToLabel) {
        if (stepNodeId == null) return null;
        for (ProcessInstanceNode pin : pins) {
            if (pin.ProcessNodeId == stepNodeId) {
                return nodeIdToLabel.get(pin.ProcessNodeId);
            }
        }
        return null;
    }

    private static String formatDatetime(Datetime dt) {
        if (dt == null) return '';
        return dt.format('dd/MM/yyyy HH:mm');
    }

    // ─────────────────────────────────────── Wrapper classes ───────────────────────────────────────
    public class ApprovalRow {
        @AuraEnabled public String id;
        @AuraEnabled public String workItemId;
        @AuraEnabled public String stepName;
        @AuraEnabled public Datetime stepDate;
        @AuraEnabled public String stepDateFormatted;
        @AuraEnabled public String status;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public String actualApprover;
        @AuraEnabled public String comments;
        @AuraEnabled public Boolean isPending;
        @AuraEnabled public String processName;
        @AuraEnabled public String nextApproverSource;
    }

    public class ApprovalHistoryResult {
        @AuraEnabled public List<ApprovalRow> rows;
        @AuraEnabled public Boolean canApproveOrReject;
        @AuraEnabled public Boolean canRecall;
        @AuraEnabled public String processStatus;
    }
}