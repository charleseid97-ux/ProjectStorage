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
            // Resolve the approver for the initial step before submitting
            List<ApprovalStepConfig__mdt> initCfgs = [SELECT Id, StepDeveloperName__c
                                                       FROM ApprovalStepConfig__mdt
                                                       WHERE ProcessConfig__r.ProcessDeveloperName__c = :processName
                                                       AND IsInitialStep__c = true
                                                       LIMIT 1];
            String initialStepDevName = initCfgs.isEmpty() ? null : initCfgs[0].StepDeveloperName__c;
            List<Id> initialApprovers = resolveApprovers(processName, initialStepDevName, recordId, null);

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(recordId);
            req.setProcessDefinitionNameOrId(processName);
            if (!initialApprovers.isEmpty()) {
                req.setNextApproverIds(initialApprovers);
            }
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
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;

        try {
            ProcessInstanceWorkitem wi = [SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId, ProcessInstance.ProcessDefinition.DeveloperName, ActorId
                                          FROM ProcessInstanceWorkitem
                                          WHERE Id = :workItemId
                                          LIMIT 1];

            String processDeveloperName = wi.ProcessInstance.ProcessDefinition.DeveloperName;
            Id targetObjectId = wi.ProcessInstance.TargetObjectId;

            // Identify the active step
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

            List<Id> resolvedApprovers = resolveApprovers(processDeveloperName, stepDevName, targetObjectId, nextApproverIds);

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

    // ─────────────────────────────────────── resolveApprovers ───────────────────────────────────────
    private static List<Id> resolveApprovers(String processDeveloperName, String stepDevName, Id targetObjectId, List<Id> userInputIds) {
        if (String.isBlank(stepDevName)) {
            return userInputIds != null ? userInputIds : new List<Id>();
        }

        List<ApprovalStepConfig__mdt> cfgs = [SELECT NextApproverSource__c, ApproverResolverClass__c
                                               FROM ApprovalStepConfig__mdt
                                               WHERE ProcessConfig__r.ProcessDeveloperName__c = :processDeveloperName
                                               AND StepDeveloperName__c = :stepDevName
                                               LIMIT 1];
        if (cfgs.isEmpty()) {
            return userInputIds != null ? userInputIds : new List<Id>();
        }

        ApprovalStepConfig__mdt stepCfg = cfgs[0];

        if (stepCfg.NextApproverSource__c == 'Dynamic' && String.isNotBlank(stepCfg.ApproverResolverClass__c)) {
            IApproverResolver resolver = (IApproverResolver) Type.forName(stepCfg.ApproverResolverClass__c).newInstance();
            return resolver.resolve(targetObjectId);
        }
        if (stepCfg.NextApproverSource__c == 'UserInput') {
            return userInputIds != null ? userInputIds : new List<Id>();
        }
        // NotRequired: Salesforce uses the pre-configured approver
        return new List<Id>();
    }
}