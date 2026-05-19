public without sharing class CustomApprovalHistoryUtility {

    public class ProcessResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  errorMessage;
    }

    private class ApproverAssignment {
        public Id    approverId;
        public String approverName;
        ApproverAssignment(Id approverId, String approverName) {
            this.approverId   = approverId;
            this.approverName = approverName;
        }
    }

    // ─── submitForApproval ───────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static ProcessResult submitForApproval(Id recordId, String processName, String comments) {
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;
        try {
            List<ApprovalStepConfig__mdt> allSteps = [
                SELECT Id, DeveloperName, StepOrder__c, StepLabel__c, ApprovalMode__c
                FROM ApprovalStepConfig__mdt
                WHERE ProcessConfig__r.ProcessDeveloperName__c = :processName
                ORDER BY StepOrder__c ASC
            ];
            if (allSteps.isEmpty()) {
                result.errorMessage = 'No step configuration found for process: ' + processName;
                return result;
            }
            ApprovalStepConfig__mdt initialStep = allSteps[0];

            List<ApproverAssignment> assignments = resolveApprovers(processName, initialStep, recordId, null);
            if (assignments.isEmpty()) {
                result.errorMessage = 'No approvers could be resolved for the initial step.';
                return result;
            }

            Id currentUserId = UserInfo.getUserId();

            CustomApproval__c approval = new CustomApproval__c(
                TargetRecordId__c        = String.valueOf(recordId),
                Status__c                = 'Pending',
                SubmittedBy__c           = currentUserId,
                ProcessDeveloperName__c  = processName,
                CurrentStepDevName__c    = initialStep.DeveloperName,
                Comments__c              = comments
            );
            insert approval;

            List<CustomApprovalStep__c> steps = new List<CustomApprovalStep__c>();

            CustomApprovalStep__c submittedEntry = new CustomApprovalStep__c(
                CustomApproval__c      = approval.Id,
                StepDeveloperName__c   = 'Submitted',
                StepLabel__c           = 'Submitted',
                Status__c              = 'Started',
                IsCurrentStep__c       = false,
                ActualApprover__c      = currentUserId,
                ActionDate__c          = System.now(),
                Comments__c            = comments
            );
            steps.add(submittedEntry);

            Set<Id> initialApproverIds = new Set<Id>();
            for (ApproverAssignment a : assignments) {
                CustomApprovalStep__c step = new CustomApprovalStep__c(
                    CustomApproval__c         = approval.Id,
                    StepDeveloperName__c      = initialStep.DeveloperName,
                    StepLabel__c              = initialStep.StepLabel__c,
                    Status__c                 = 'Pending',
                    IsCurrentStep__c          = true,
                    AssignedTo__c             = String.valueOf(a.approverId),
                    AssignedToName__c         = a.approverName,
                    OriginalAssignedTo__c     = String.valueOf(a.approverId),
                    OriginalAssignedToName__c = a.approverName
                );
                steps.add(step);
                initialApproverIds.add(a.approverId);
            }
            insert steps;

            Map<String, Object> ctx = new Map<String, Object>{
                'submittedById'     => currentUserId,
                'currentApproverIds' => new List<Id>(initialApproverIds),
                'nextApproverIds'   => null,
                'actionType'        => 'InitialSubmission'
            };
            executeActions(processName, null, 'InitialSubmission', recordId, ctx);

            result.success = true;
        } catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─── processApproval ────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static ProcessResult processApproval(Id stepId, String action, String comments, List<Id> nextApproverIds) {
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;
        try {
            CustomApprovalStep__c currentStep = [
                SELECT Id, CustomApproval__c, StepDeveloperName__c,
                       CustomApproval__r.ProcessDeveloperName__c,
                       CustomApproval__r.TargetRecordId__c,
                       CustomApproval__r.SubmittedBy__c,
                       CustomApproval__r.Status__c
                FROM CustomApprovalStep__c
                WHERE Id = :stepId
                LIMIT 1
            ];

            Id approvalId          = currentStep.CustomApproval__c;
            String processName     = currentStep.CustomApproval__r.ProcessDeveloperName__c;
            Id targetRecordId      = (Id) currentStep.CustomApproval__r.TargetRecordId__c;
            Id submittedById       = currentStep.CustomApproval__r.SubmittedBy__c;
            String stepDevName     = currentStep.StepDeveloperName__c;
            Id currentUserId       = UserInfo.getUserId();

            // ── Recall ──────────────────────────────────────────────────────────
            if (action == 'Removed') {
                List<CustomApprovalStep__c> pendingSteps = [
                    SELECT Id, AssignedTo__c
                    FROM CustomApprovalStep__c
                    WHERE CustomApproval__c = :approvalId AND IsCurrentStep__c = true
                ];
                Set<Id> recalledIds = new Set<Id>();
                for (CustomApprovalStep__c s : pendingSteps) {
                    s.Status__c        = 'Recalled';
                    s.IsCurrentStep__c = false;
                    s.ActualApprover__c = currentUserId;
                    s.ActionDate__c    = System.now();
                    s.Comments__c      = comments;
                    if (String.isNotBlank(s.AssignedTo__c)) {
                        recalledIds.add((Id) s.AssignedTo__c);
                    }
                }
                update pendingSteps;

                CustomApproval__c approval = new CustomApproval__c(
                    Id                    = approvalId,
                    Status__c             = 'Recalled',
                    CurrentStepDevName__c = null
                );
                update approval;

                Map<String, Object> ctx = new Map<String, Object>{
                    'submittedById'      => submittedById,
                    'currentApproverIds' => new List<Id>(recalledIds),
                    'nextApproverIds'    => null,
                    'actionType'         => 'Recall'
                };
                executeActions(processName, null, 'Recall', targetRecordId, ctx);
                result.success = true;
                return result;
            }

            // ── Approve / Reject ─────────────────────────────────────────────────
            String newStatus = (action == 'Approve') ? 'Approved' : 'Rejected';
            currentStep.Status__c        = newStatus;
            currentStep.IsCurrentStep__c = false;
            currentStep.ActualApprover__c = currentUserId;
            currentStep.ActionDate__c    = System.now();
            currentStep.Comments__c      = comments;
            update currentStep;

            List<CustomApprovalStep__c> siblings = [
                SELECT Id, AssignedTo__c
                FROM CustomApprovalStep__c
                WHERE CustomApproval__c = :approvalId
                  AND StepDeveloperName__c = :stepDevName
                  AND IsCurrentStep__c = true
                  AND Id != :stepId
            ];

            // Build full list of all assignees for this step (for context map)
            Set<Id> allCurrentAssigneeIds = new Set<Id>();
            if (String.isNotBlank(currentStep.AssignedTo__c)) {
                allCurrentAssigneeIds.add((Id) currentStep.AssignedTo__c);
            }
            for (CustomApprovalStep__c s : siblings) {
                if (String.isNotBlank(s.AssignedTo__c)) {
                    allCurrentAssigneeIds.add((Id) s.AssignedTo__c);
                }
            }

            // ── Reject: always final ─────────────────────────────────────────────
            if (action == 'Reject') {
                for (CustomApprovalStep__c s : siblings) {
                    s.Status__c        = 'Recalled';
                    s.IsCurrentStep__c = false;
                    s.ActualApprover__c = currentUserId;
                    s.ActionDate__c    = System.now();
                }
                if (!siblings.isEmpty()) {
                    update siblings;
                }

                Map<String, Object> stepCtx = new Map<String, Object>{
                    'submittedById'      => submittedById,
                    'currentApproverIds' => new List<Id>(allCurrentAssigneeIds),
                    'nextApproverIds'    => null,
                    'actionType'         => 'StepRejection'
                };
                executeActions(processName, stepDevName, 'StepRejection', targetRecordId, stepCtx);

                CustomApproval__c approval = new CustomApproval__c(
                    Id                    = approvalId,
                    Status__c             = 'Rejected',
                    CurrentStepDevName__c = null
                );
                update approval;

                stepCtx.put('actionType', 'FinalRejection');
                executeActions(processName, null, 'FinalRejection', targetRecordId, stepCtx);
                result.success = true;
                return result;
            }

            // ── Approve: check mode and sibling state ────────────────────────────
            ApprovalStepConfig__mdt stepCfg = [
                SELECT ApprovalMode__c, StepOrder__c
                FROM ApprovalStepConfig__mdt
                WHERE DeveloperName = :stepDevName
                LIMIT 1
            ];

            // All mode with siblings still pending — wait for unanimous outcome
            if (stepCfg.ApprovalMode__c == 'All' && !siblings.isEmpty()) {
                result.success = true;
                return result;
            }

            // Any mode: recall remaining siblings before advancing
            if (stepCfg.ApprovalMode__c == 'Any' && !siblings.isEmpty()) {
                for (CustomApprovalStep__c s : siblings) {
                    s.Status__c        = 'Recalled';
                    s.IsCurrentStep__c = false;
                    s.ActualApprover__c = currentUserId;
                    s.ActionDate__c    = System.now();
                }
                update siblings;
            }

            // Find next step
            List<ApprovalStepConfig__mdt> nextSteps = [
                SELECT Id, DeveloperName, StepLabel__c, ApprovalMode__c
                FROM ApprovalStepConfig__mdt
                WHERE ProcessConfig__r.ProcessDeveloperName__c = :processName
                  AND StepOrder__c > :stepCfg.StepOrder__c
                ORDER BY StepOrder__c ASC
                LIMIT 1
            ];

            if (!nextSteps.isEmpty()) {
                ApprovalStepConfig__mdt nextStep = nextSteps[0];
                List<ApproverAssignment> nextAssignments = resolveApprovers(processName, nextStep, targetRecordId, nextApproverIds);

                Set<Id> nextAssigneeIds = new Set<Id>();
                for (ApproverAssignment a : nextAssignments) {
                    nextAssigneeIds.add(a.approverId);
                }

                Map<String, Object> ctx = new Map<String, Object>{
                    'submittedById'      => submittedById,
                    'currentApproverIds' => new List<Id>(allCurrentAssigneeIds),
                    'nextApproverIds'    => new List<Id>(nextAssigneeIds),
                    'actionType'         => 'StepApproval'
                };
                executeActions(processName, stepDevName, 'StepApproval', targetRecordId, ctx);

                List<CustomApprovalStep__c> newSteps = new List<CustomApprovalStep__c>();
                for (ApproverAssignment a : nextAssignments) {
                    newSteps.add(new CustomApprovalStep__c(
                        CustomApproval__c         = approvalId,
                        StepDeveloperName__c      = nextStep.DeveloperName,
                        StepLabel__c              = nextStep.StepLabel__c,
                        Status__c                 = 'Pending',
                        IsCurrentStep__c          = true,
                        AssignedTo__c             = String.valueOf(a.approverId),
                        AssignedToName__c         = a.approverName,
                        OriginalAssignedTo__c     = String.valueOf(a.approverId),
                        OriginalAssignedToName__c = a.approverName
                    ));
                }
                insert newSteps;

                update new CustomApproval__c(Id = approvalId, CurrentStepDevName__c = nextStep.DeveloperName);

            } else {
                // No next step — final approval
                Map<String, Object> ctx = new Map<String, Object>{
                    'submittedById'      => submittedById,
                    'currentApproverIds' => new List<Id>(allCurrentAssigneeIds),
                    'nextApproverIds'    => null,
                    'actionType'         => 'StepApproval'
                };
                executeActions(processName, stepDevName, 'StepApproval', targetRecordId, ctx);

                update new CustomApproval__c(Id = approvalId, Status__c = 'Approved', CurrentStepDevName__c = null);

                ctx.put('actionType', 'FinalApproval');
                executeActions(processName, null, 'FinalApproval', targetRecordId, ctx);
            }

            result.success = true;
        } catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─── resolveApprovers ───────────────────────────────────────────────────────

    private static List<ApproverAssignment> resolveApprovers(
        String processName,
        ApprovalStepConfig__mdt step,
        Id targetObjectId,
        List<Id> userInputIds
    ) {
        List<ApproverAssignment> result = new List<ApproverAssignment>();

        List<ApprovalStepApproverConfig__mdt> approverCfgs = [
            SELECT ApproverSource__c, ApproverType__c, ApproverValue__c, ApproverResolverClass__c
            FROM ApprovalStepApproverConfig__mdt
            WHERE StepConfig__r.DeveloperName = :step.DeveloperName
            ORDER BY ExecutionOrder__c ASC
        ];

        for (ApprovalStepApproverConfig__mdt cfg : approverCfgs) {
            if (cfg.ApproverSource__c == 'Configured') {
                if (cfg.ApproverType__c == 'User') {
                    List<User> users = [SELECT Id, Name FROM User WHERE Username = :cfg.ApproverValue__c LIMIT 1];
                    if (!users.isEmpty()) {
                        result.add(new ApproverAssignment(users[0].Id, users[0].Name));
                    }
                } else if (cfg.ApproverType__c == 'Queue') {
                    List<Group> queues = [SELECT Id, Name FROM Group WHERE DeveloperName = :cfg.ApproverValue__c AND Type = 'Queue' LIMIT 1];
                    if (!queues.isEmpty()) {
                        result.add(new ApproverAssignment(queues[0].Id, queues[0].Name));
                    }
                } else if (cfg.ApproverType__c == 'RelatedUser') {
                    try {
                        SObject record = Database.query('SELECT ' + cfg.ApproverValue__c + ' FROM ' + targetObjectId.getSObjectType().getDescribe().getName() + ' WHERE Id = :targetObjectId LIMIT 1');
                        Id relatedUserId = (Id) record.get(cfg.ApproverValue__c);
                        if (relatedUserId != null) {
                            List<User> users = [SELECT Id, Name FROM User WHERE Id = :relatedUserId LIMIT 1];
                            if (!users.isEmpty()) {
                                result.add(new ApproverAssignment(users[0].Id, users[0].Name));
                            }
                        }
                    } catch (Exception e) {
                        System.debug('resolveApprovers RelatedUser error: ' + e.getMessage());
                    }
                }
            } else if (cfg.ApproverSource__c == 'Dynamic' && String.isNotBlank(cfg.ApproverResolverClass__c)) {
                try {
                    IApproverResolver resolver = (IApproverResolver) Type.forName(cfg.ApproverResolverClass__c).newInstance();
                    List<Id> resolvedIds = resolver.resolve(targetObjectId);
                    for (Id resolvedId : resolvedIds) {
                        String resolvedName = resolvedId;
                        String prefix = String.valueOf(resolvedId).left(3);
                        if (prefix == '005') {
                            List<User> users = [SELECT Name FROM User WHERE Id = :resolvedId LIMIT 1];
                            if (!users.isEmpty()) {
                                resolvedName = users[0].Name;
                            }
                        } else if (prefix == '00G') {
                            List<Group> queues = [SELECT Name FROM Group WHERE Id = :resolvedId LIMIT 1];
                            if (!queues.isEmpty()) {
                                resolvedName = queues[0].Name;
                            }
                        }
                        result.add(new ApproverAssignment(resolvedId, resolvedName));
                    }
                } catch (Exception e) {
                    System.debug('resolveApprovers Dynamic error: ' + e.getMessage());
                }
            } else if (cfg.ApproverSource__c == 'UserInput') {
                if (userInputIds != null) {
                    for (Id uid : userInputIds) {
                        List<User> users = [SELECT Id, Name FROM User WHERE Id = :uid LIMIT 1];
                        if (!users.isEmpty()) {
                            result.add(new ApproverAssignment(users[0].Id, users[0].Name));
                        }
                    }
                }
            }
        }
        return result;
    }

    // ─── executeActions ──────────────────────────────────────────────────────────

    private static void executeActions(
        String processDevName,
        String stepDevName,
        String actionType,
        Id targetRecordId,
        Map<String, Object> context
    ) {
        List<ApprovalActionConfig__mdt> actions;
        if (String.isNotBlank(stepDevName)) {
            actions = [
                SELECT ActionKind__c, TargetFieldApiName__c, FieldValue__c,
                       EmailTemplateName__c, RecipientType__c, AdditionalQueues__c,
                       AdditionalUsers__c, ActionClass__c
                FROM ApprovalActionConfig__mdt
                WHERE StepConfig__r.DeveloperName = :stepDevName
                  AND ActionType__c = :actionType
                  AND IsActive__c = true
                ORDER BY ExecutionOrder__c ASC
            ];
        } else {
            actions = [
                SELECT ActionKind__c, TargetFieldApiName__c, FieldValue__c,
                       EmailTemplateName__c, RecipientType__c, AdditionalQueues__c,
                       AdditionalUsers__c, ActionClass__c
                FROM ApprovalActionConfig__mdt
                WHERE ProcessConfig__r.ProcessDeveloperName__c = :processDevName
                  AND ActionType__c = :actionType
                  AND IsActive__c = true
                ORDER BY ExecutionOrder__c ASC
            ];
        }

        String objectApiName = targetRecordId.getSObjectType().getDescribe().getName();

        for (ApprovalActionConfig__mdt cfg : actions) {
            try {
                if (cfg.ActionKind__c == 'FieldUpdate') {
                    SObject obj = targetRecordId.getSObjectType().newSObject(targetRecordId);
                    obj.put(cfg.TargetFieldApiName__c, cfg.FieldValue__c);
                    update obj;

                } else if (cfg.ActionKind__c == 'EmailAlert') {
                    Set<String> recipientTypes = new Set<String>();
                    if (String.isNotBlank(cfg.RecipientType__c)) {
                        recipientTypes.addAll(cfg.RecipientType__c.split(';'));
                    }

                    Set<Id> currentIds = context.containsKey('currentApproverIds')
                        ? new Set<Id>((List<Id>) context.get('currentApproverIds'))
                        : new Set<Id>();
                    Set<Id> nextIds = context.containsKey('nextApproverIds') && context.get('nextApproverIds') != null
                        ? new Set<Id>((List<Id>) context.get('nextApproverIds'))
                        : new Set<Id>();
                    Id submittedById = (Id) context.get('submittedById');

                    Set<Id> recipients = EmailService.resolveRecipientIds(
                        recipientTypes, currentIds, nextIds, submittedById, targetRecordId, objectApiName
                    );
                    recipients.addAll(EmailService.resolveAdditionalRecipientIds(cfg.AdditionalQueues__c, cfg.AdditionalUsers__c));

                    if (!recipients.isEmpty()) {
                        EmailService.sendTemplateEmail(cfg.EmailTemplateName__c, targetRecordId, recipients);
                    }

                } else if (cfg.ActionKind__c == 'CustomApex' && String.isNotBlank(cfg.ActionClass__c)) {
                    IApprovalAction customAction = (IApprovalAction) Type.forName(cfg.ActionClass__c).newInstance();
                    customAction.execute(targetRecordId, UserInfo.getUserId(), context);
                }
            } catch (Exception e) {
                System.debug('executeActions error [' + cfg.ActionKind__c + ']: ' + e.getMessage());
            }
        }
    }
}
