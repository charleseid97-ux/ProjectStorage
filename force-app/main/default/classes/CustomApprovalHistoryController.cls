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
        result.rows              = new List<ApprovalRow>();
        result.canApproveOrReject = false;
        result.canRecall          = false;
        result.processStatus      = null;

        if (recordId == null) {
            return result;
        }

        // 1. Load all ProcessInstances for this record
        // Note: ProcessDefinition.AllowRecall is not queryable via SOQL.
        // Recall eligibility is evaluated for pending PIs by submitter/admin;
        // the Salesforce engine will enforce the AllowRecall setting server-side.
        List<ProcessInstance> instances = [SELECT Id, Status, SubmittedById, CreatedDate, ProcessDefinition.Name, ProcessDefinition.DeveloperName
                                           FROM ProcessInstance
                                           WHERE TargetObjectId = :recordId
                                           ORDER BY CreatedDate DESC];
        if (instances.isEmpty()) {
            return result;
        }

        Set<Id> piIds = new Map<Id, ProcessInstance>(instances).keySet();

        // 2. Completed steps
        List<ProcessInstanceStep> steps = [SELECT Id, StepNodeId, StepStatus, Comments, CreatedDate, Actor.Name, OriginalActor.Name, ProcessInstanceId
                                           FROM ProcessInstanceStep
                                           WHERE ProcessInstanceId IN :piIds
                                           ORDER BY CreatedDate ASC];

        // 3. ProcessInstanceNodes — ProcessNodeName gives the step label directly,
        //    so no separate ProcessNode query is needed.
        //    Sort ASC so the most recently created node overwrites earlier ones in the active-node map.
        List<ProcessInstanceNode> pins = [SELECT Id, ProcessInstanceId, ProcessNodeId, ProcessNodeName, NodeStatus
                                          FROM ProcessInstanceNode
                                          WHERE ProcessInstanceId IN :piIds
                                          ORDER BY CreatedDate ASC];
        // Map ProcessNodeId → step label (ProcessNodeName)
        Map<Id, String> nodeIdToLabel = new Map<Id, String>();
        for (ProcessInstanceNode pin : pins) {
            if (pin.ProcessNodeId != null && String.isNotBlank(pin.ProcessNodeName)) {
                nodeIdToLabel.put(pin.ProcessNodeId, pin.ProcessNodeName);
            }
        }
        // Map processInstanceId → most recent active ProcessNodeId.
        // Don't filter by NodeStatus — the active node for a pending PI may have status 'Pending'
        // or 'Started' depending on the org version. Taking the last non-null ProcessNodeId (ASC order)
        // gives us the currently active step for any pending PI.
        Map<Id, Id> piIdToActiveNodeId = new Map<Id, Id>();
        for (ProcessInstanceNode pin : pins) {
            if (pin.ProcessNodeId != null) {
                piIdToActiveNodeId.put(pin.ProcessInstanceId, pin.ProcessNodeId);
            }
        }

        // 4. Pending work items
        List<ProcessInstanceWorkitem> workItems = [SELECT Id, ProcessInstanceId, ActorId, Actor.Name, OriginalActorId, OriginalActor.Name, CreatedDate
                                                   FROM ProcessInstanceWorkitem
                                                   WHERE ProcessInstanceId IN :piIds];
        Map<Id, ProcessInstanceWorkitem> piIdToWorkItem = new Map<Id, ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem wi : workItems) {
            piIdToWorkItem.put(wi.ProcessInstanceId, wi);
        }

        // 5. Load ApprovalStepConfig__mdt for all process developer names
        Set<String> processDevNames = new Set<String>();
        for (ProcessInstance pi : instances) {
            processDevNames.add(pi.ProcessDefinition.DeveloperName);
        }
        // Build map: processDevName + stepDevName → NextApproverSource__c
        Map<String, ApprovalStepConfig__mdt> stepConfigMap = new Map<String, ApprovalStepConfig__mdt>();
        for (ApprovalStepConfig__mdt cfg : [SELECT ProcessConfig__r.ProcessDeveloperName__c, StepDeveloperName__c, NextApproverSource__c, ApproverResolverClass__c
                                            FROM ApprovalStepConfig__mdt
                                            WHERE ProcessConfig__r.ProcessDeveloperName__c IN :processDevNames]) {
            String key = cfg.ProcessConfig__r.ProcessDeveloperName__c + '__' + cfg.StepDeveloperName__c;
            stepConfigMap.put(key, cfg);
        }

        // 6. Determine current user permissions
        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin = false;
        for (PermissionSetAssignment psa : [SELECT PermissionSet.Name
                                            FROM PermissionSetAssignment
                                            WHERE AssigneeId = :currentUserId
                                            AND PermissionSet.IsOwnedByProfile = true
                                            AND PermissionSet.Profile.Name LIKE '%Administrator%']) {
            isAdmin = true;
        }

        // 7. Build rows
        Boolean canApproveOrReject = false;
        Boolean canRecall = false;
        String processStatus = instances[0].Status;

        for (ProcessInstance pi : instances) {
            String processName = pi.ProcessDefinition.Name;
            String processDeveloperName = pi.ProcessDefinition.DeveloperName;

            // Completed steps for this PI
            for (ProcessInstanceStep step : steps) {
                if (step.ProcessInstanceId != pi.Id) continue;
                ApprovalRow row = new ApprovalRow();
                String resolvedName = resolveStepName(step.StepNodeId, pins, nodeIdToLabel);
                row.id                 = step.Id;
                row.workItemId         = null;
                row.stepName           = String.isNotBlank(resolvedName) ? resolvedName
                                         : (step.StepStatus == 'Started' ? 'Approval Request Submitted' : step.StepStatus);
                row.stepDate           = step.CreatedDate;
                row.stepDateFormatted  = formatDatetime(step.CreatedDate);
                row.status             = step.StepStatus == 'Started' ? 'Submitted' : step.StepStatus;
                row.assignedTo         = step.OriginalActor?.Name;
                row.actualApprover     = step.Actor?.Name;
                row.comments           = step.Comments;
                row.isPending          = false;
                row.processName        = processName;
                row.nextApproverSource = null;
                result.rows.add(row);
            }

            // Pending work item for this PI
            if (piIdToWorkItem.containsKey(pi.Id)) {
                ProcessInstanceWorkitem wi = piIdToWorkItem.get(pi.Id);
                Id activeNodeId = piIdToActiveNodeId.get(pi.Id);
                String stepLabel = activeNodeId != null ? nodeIdToLabel.get(activeNodeId) : null;
                String cfgKey = processDeveloperName + '__' + (stepLabel != null ? stepLabel : '');
                ApprovalStepConfig__mdt stepCfg = stepConfigMap.get(cfgKey);
                String nextApproverSource = stepCfg != null ? stepCfg.NextApproverSource__c : null;

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
                result.rows.add(row);

                if (wi.ActorId == currentUserId || isAdmin) {
                    canApproveOrReject = true;
                }
            }

            // Recall eligibility (only for Pending PIs; AllowRecall enforced server-side by Salesforce)
            if (pi.Status == 'Pending') {
                if (isAdmin || pi.SubmittedById == currentUserId) {
                    canRecall = true;
                }
            }
        }

        result.canApproveOrReject = canApproveOrReject;
        result.canRecall          = canRecall;
        result.processStatus      = processStatus;
        return result;
    }

    // ─────────────────────────────────────── processApproval ───────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static CustomApprovalHistoryUtility.ProcessResult processApproval(Id workItemId, String action, String comments, List<Id> nextApproverIds) {
        return CustomApprovalHistoryUtility.processApproval(workItemId, action, comments, nextApproverIds);
    }

    // ─────────────────────────────────────── Private helpers ───────────────────────────────────────
    private static String resolveStepName(Id stepNodeId, List<ProcessInstanceNode> pins, Map<Id, String> nodeIdToDeveloperName) {
        if (stepNodeId == null) return null;
        for (ProcessInstanceNode pin : pins) {
            if (pin.ProcessNodeId == stepNodeId) {
                return nodeIdToDeveloperName.get(pin.ProcessNodeId);
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