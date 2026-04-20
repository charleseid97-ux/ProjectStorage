/** ──────────────────────────────────────
 * @description Utility class for approval process actions used by the Custom Approval History LWC
 *              and any other components that need to submit, approve, reject, or recall records.
 *              Keeps action logic separate from the query/display logic in CustomApprovalHistoryController.
 * @author Charles EID
 * @testClass CustomApprovalHistoryControllerTest
────────────────────────────────────── */
public with sharing class CustomApprovalHistoryUtility {

    // ─────────────────────────────────────── Wrapper ───────────────────────────────────────
    public class ProcessResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  errorMessage;
    }

    // ─────────────────────────────────────── submitForApproval ───────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProcessResult submitForApproval(Id recordId, String processName, String comments) {
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;

        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(recordId);
            req.setProcessDefinitionNameOrId(processName);
            if (String.isNotBlank(comments)) {
                req.setComments(comments);
            }
            Approval.ProcessResult approvalResult = Approval.process(req);
            result.success = approvalResult.isSuccess();
            if (!approvalResult.isSuccess()) {
                List<String> msgs = new List<String>();
                for (Database.Error e : approvalResult.getErrors()) {
                    msgs.add(e.getMessage());
                }
                result.errorMessage = String.join(msgs, ', ');
            }
        } catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─────────────────────────────────────── processApproval ───────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProcessResult processApproval(Id workItemId, String action, String comments, List<Id> nextApproverIds) {
        System.debug('We are in processApproval');
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;

        try {
            // Load work item with process and target object context
            ProcessInstanceWorkitem wi = [SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId, ProcessInstance.ProcessDefinition.DeveloperName, ActorId
                                          FROM ProcessInstanceWorkitem
                                          WHERE Id = :workItemId
                                          LIMIT 1];

            String processDeveloperName = wi.ProcessInstance.ProcessDefinition.DeveloperName;
            System.debug('processDeveloperName: '+processDeveloperName);
            Id targetObjectId = wi.ProcessInstance.TargetObjectId;

            // Find the active ProcessInstanceNode for this work item's PI
            String stepDevName = null;
            List<ProcessInstanceNode> activePins = [SELECT ProcessNodeId
                                                    FROM ProcessInstanceNode
                                                    WHERE ProcessInstanceId = :wi.ProcessInstanceId
                                                    AND NodeStatus = 'Started'
                                                    LIMIT 1];
            if (!activePins.isEmpty() && activePins[0].ProcessNodeId != null) {
                List<ProcessNode> pns = [SELECT DeveloperName FROM ProcessNode WHERE Id = :activePins[0].ProcessNodeId LIMIT 1];
                if (!pns.isEmpty()) {
                    stepDevName = pns[0].DeveloperName;
                }
            }

            // Resolve next approvers based on step config
            List<Id> resolvedApprovers = new List<Id>();
            if (stepDevName != null) {
                List<ApprovalStepConfig__mdt> cfgs = [SELECT NextApproverSource__c, ApproverResolverClass__c
                                                      FROM ApprovalStepConfig__mdt
                                                      WHERE ProcessConfig__r.ProcessDeveloperName__c = :processDeveloperName
                                                      AND StepDeveloperName__c = :stepDevName
                                                      LIMIT 1];
                System.debug('cfgs: '+cfgs);
                if (!cfgs.isEmpty()) {
                    ApprovalStepConfig__mdt stepCfg = cfgs[0];
                    System.debug('stepCfg: '+stepCfg);
                    if (stepCfg.NextApproverSource__c == 'Dynamic' && String.isNotBlank(stepCfg.ApproverResolverClass__c)) {
                        Type resolverType = Type.forName(stepCfg.ApproverResolverClass__c);
                        IApproverResolver resolver = (IApproverResolver) resolverType.newInstance();
                        resolvedApprovers = resolver.resolve(targetObjectId);
                    }
                    else if (stepCfg.NextApproverSource__c == 'UserInput') {
                        resolvedApprovers = nextApproverIds != null ? nextApproverIds : new List<Id>();
                    }
                    // NotRequired: resolvedApprovers stays empty — pre-configured approver or last step
                }
                else { // No config found — fall back to user-provided
                    resolvedApprovers = nextApproverIds != null ? nextApproverIds : new List<Id>();
                }
            }

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItemId);
            req.setAction(action);
            if (!resolvedApprovers.isEmpty()) {
                req.setNextApproverIds(resolvedApprovers);
            }
            if (String.isNotBlank(comments)) {
                req.setComments(comments);
            }

            Approval.ProcessResult approvalResult = Approval.process(req);
            result.success = approvalResult.isSuccess();
            if (!approvalResult.isSuccess()) {
                List<String> errorMessages = new List<String>();
                for (Database.Error e : approvalResult.getErrors()) {
                    errorMessages.add(e.getMessage());
                }
                result.errorMessage = String.join(errorMessages, ', ');
            }
        }
        catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }
}