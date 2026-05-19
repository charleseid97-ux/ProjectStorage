public without sharing class CustomApprovalHistoryUtility {

    // ─── submitForApproval ────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProcessResult submitForApproval(Id recordId, String processName, String comments) {
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;
        try {
            List<ApprovalStepConfig__mdt> allSteps = [SELECT Id, DeveloperName, StepOrder__c, StepLabel__c, ApprovalMode__c
                                                      FROM ApprovalStepConfig__mdt
                                                      WHERE ProcessConfig__r.ProcessDeveloperName__c = :processName
                                                      ORDER BY StepOrder__c ASC];
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
                TargetRecordId__c       = String.valueOf(recordId),
                Status__c               = 'Pending',
                SubmittedBy__c          = currentUserId,
                ProcessDeveloperName__c = processName,
                CurrentStepDevName__c   = initialStep.DeveloperName,
                Comments__c             = comments
            );
            insert approval;

            List<CustomApprovalStep__c> steps = new List<CustomApprovalStep__c>();
            steps.add(new CustomApprovalStep__c(
                CustomApproval__c     = approval.Id,
                StepDeveloperName__c  = 'Submitted',
                StepLabel__c          = 'Submitted',
                Status__c             = 'Started',
                IsCurrentStep__c      = false,
                ActualApprover__c     = currentUserId,
                ActionDate__c         = System.now(),
                Comments__c           = comments
            ));
            steps.addAll(buildStepRecords(approval.Id, initialStep, assignments));
            insert steps;

            Set<Id> initialApproverIds = new Set<Id>();
            for (ApproverAssignment a : assignments) {
                initialApproverIds.add(a.approverId);
            }
            executeActions(processName, null, 'InitialSubmission', recordId, buildContext(currentUserId, initialApproverIds, null));

            result.success = true;
        } 
        catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─── processApproval ─────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProcessResult processApproval(Id stepId, String action, String comments, List<Id> nextApproverIds) {
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;
        try {
            CustomApprovalStep__c currentStep = [SELECT Id, CustomApproval__c, StepDeveloperName__c, AssignedTo__c,
                                                    CustomApproval__r.ProcessDeveloperName__c,
                                                    CustomApproval__r.TargetRecordId__c,
                                                    CustomApproval__r.SubmittedBy__c,
                                                    CustomApproval__r.Status__c
                                                 FROM CustomApprovalStep__c
                                                 WHERE Id = :stepId LIMIT 1];
            StepContext ctx = new StepContext(currentStep);

            if (action == 'Removed') {
                handleRecall(ctx, comments);
            } else {
                currentStep.Status__c         = (action == 'Approve') ? 'Approved' : 'Rejected';
                currentStep.IsCurrentStep__c  = false;
                currentStep.ActualApprover__c = ctx.currentUserId;
                currentStep.ActionDate__c     = System.now();
                currentStep.Comments__c       = comments;
                update currentStep;

                List<CustomApprovalStep__c> siblings = [SELECT Id, AssignedTo__c
                                                        FROM CustomApprovalStep__c
                                                        WHERE CustomApproval__c = :ctx.approvalId
                                                          AND StepDeveloperName__c = :ctx.stepDevName
                                                          AND IsCurrentStep__c = true
                                                          AND Id != :stepId];

                Set<Id> allCurrentIds = collectAssigneeIds(currentStep, siblings);

                if (action == 'Reject') {
                    handleReject(ctx, siblings, allCurrentIds);
                } else {
                    handleApprove(ctx, siblings, allCurrentIds, nextApproverIds);
                }
            }
            result.success = true;
        } 
        catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─── processApproval handlers ─────────────────────────────────────────────────
    private static void handleRecall(StepContext ctx, String comments) {
        List<CustomApprovalStep__c> pendingSteps = [SELECT Id, AssignedTo__c
                                                    FROM CustomApprovalStep__c
                                                    WHERE CustomApproval__c = :ctx.approvalId
                                                      AND IsCurrentStep__c = true];
        Set<Id> recalledIds = new Set<Id>();
        for (CustomApprovalStep__c s : pendingSteps) {
            if (String.isNotBlank(s.AssignedTo__c)) {
                recalledIds.add((Id) s.AssignedTo__c);
            }
        }
        recallSteps(pendingSteps, ctx.currentUserId, comments);
        closeApproval(ctx.approvalId, 'Recalled');
        executeActions(ctx.processName, null, 'Recall', ctx.targetRecordId, buildContext(ctx.submittedById, recalledIds, null));
    }

    private static void handleReject(StepContext ctx, List<CustomApprovalStep__c> siblings, Set<Id> allCurrentIds) {
        recallSteps(siblings, ctx.currentUserId, null);
        closeApproval(ctx.approvalId, 'Rejected');
        Map<String, Object> rejectCtx = buildContext(ctx.submittedById, allCurrentIds, null);
        executeActions(ctx.processName, ctx.stepDevName, 'StepRejection',  ctx.targetRecordId, rejectCtx);
        executeActions(ctx.processName, null, 'FinalRejection', ctx.targetRecordId, rejectCtx);
    }

    private static void handleApprove(StepContext ctx, List<CustomApprovalStep__c> siblings, Set<Id> allCurrentIds, List<Id> nextApproverIds) {
        ApprovalStepConfig__mdt stepCfg = [SELECT ApprovalMode__c, StepOrder__c
                                           FROM ApprovalStepConfig__mdt
                                           WHERE DeveloperName = :ctx.stepDevName
                                           LIMIT 1];

        if (stepCfg.ApprovalMode__c == 'All' && !siblings.isEmpty()) {
            return;
        }
        if (stepCfg.ApprovalMode__c == 'Any' && !siblings.isEmpty()) {
            recallSteps(siblings, ctx.currentUserId, null);
        }

        List<ApprovalStepConfig__mdt> nextSteps = [SELECT Id, DeveloperName, StepLabel__c, ApprovalMode__c
                                                   FROM ApprovalStepConfig__mdt
                                                   WHERE ProcessConfig__r.ProcessDeveloperName__c = :ctx.processName
                                                     AND StepOrder__c > :stepCfg.StepOrder__c
                                                   ORDER BY StepOrder__c ASC LIMIT 1];

        if (!nextSteps.isEmpty()) {
            ApprovalStepConfig__mdt nextStep = nextSteps[0];
            List<ApproverAssignment> nextAssignments = resolveApprovers(ctx.processName, nextStep, ctx.targetRecordId, nextApproverIds);
            Set<Id> nextIds = new Set<Id>();
            for (ApproverAssignment a : nextAssignments) {
                nextIds.add(a.approverId);
            }
            executeActions(ctx.processName, ctx.stepDevName, 'StepApproval', ctx.targetRecordId, buildContext(ctx.submittedById, allCurrentIds, nextIds));
            insert buildStepRecords(ctx.approvalId, nextStep, nextAssignments);
            update new CustomApproval__c(Id = ctx.approvalId, CurrentStepDevName__c = nextStep.DeveloperName);
        } 
        else {
            Map<String, Object> approveCtx = buildContext(ctx.submittedById, allCurrentIds, null);
            executeActions(ctx.processName, ctx.stepDevName, 'StepApproval',  ctx.targetRecordId, approveCtx);
            closeApproval(ctx.approvalId, 'Approved');
            executeActions(ctx.processName, null, 'FinalApproval', ctx.targetRecordId, approveCtx);
        }
    }

    // ─── Shared step helpers ──────────────────────────────────────────────────────
    private static void recallSteps(List<CustomApprovalStep__c> steps, Id actorId, String comments) {
        for (CustomApprovalStep__c s : steps) {
            s.Status__c         = 'Recalled';
            s.IsCurrentStep__c  = false;
            s.ActualApprover__c = actorId;
            s.ActionDate__c     = System.now();
            if (comments != null) s.Comments__c = comments;
        }
        if (!steps.isEmpty()) update steps;
    }

    private static void closeApproval(Id approvalId, String status) {
        update new CustomApproval__c(Id = approvalId, Status__c = status, CurrentStepDevName__c = null);
    }

    private static List<CustomApprovalStep__c> buildStepRecords(Id approvalId, ApprovalStepConfig__mdt step, List<ApproverAssignment> assignments) {
        List<CustomApprovalStep__c> records = new List<CustomApprovalStep__c>();
        for (ApproverAssignment a : assignments) {
            records.add(new CustomApprovalStep__c(
                CustomApproval__c         = approvalId,
                StepDeveloperName__c      = step.DeveloperName,
                StepLabel__c              = step.StepLabel__c,
                Status__c                 = 'Pending',
                IsCurrentStep__c          = true,
                AssignedTo__c             = String.valueOf(a.approverId),
                AssignedToName__c         = a.approverName,
                OriginalAssignedTo__c     = String.valueOf(a.approverId),
                OriginalAssignedToName__c = a.approverName
            ));
        }
        return records;
    }

    private static Set<Id> collectAssigneeIds(CustomApprovalStep__c currentStep, List<CustomApprovalStep__c> siblings) {
        Set<Id> ids = new Set<Id>();
        if (String.isNotBlank(currentStep.AssignedTo__c)) {
            ids.add((Id) currentStep.AssignedTo__c);
        }
        for (CustomApprovalStep__c s : siblings) {
            if (String.isNotBlank(s.AssignedTo__c)) {
                ids.add((Id) s.AssignedTo__c);
            }
        }
        return ids;
    }

    private static Map<String, Object> buildContext(Id submittedById, Set<Id> currentIds, Set<Id> nextIds) {
        return new Map<String, Object>{
            'submittedById'      => submittedById,
            'currentApproverIds' => currentIds != null ? new List<Id>(currentIds) : new List<Id>(),
            'nextApproverIds'    => nextIds    != null ? new List<Id>(nextIds)    : null
        };
    }

    // ─── resolveApprovers ────────────────────────────────────────────────────────
    private static List<ApproverAssignment> resolveApprovers(String processName, ApprovalStepConfig__mdt step, Id targetObjectId, List<Id> userInputIds) {
        List<ApproverAssignment> result = new List<ApproverAssignment>();
        for (ApprovalStepApproverConfig__mdt cfg : [SELECT ApproverSource__c, ApproverType__c, ApproverValue__c, ApproverResolverClass__c
                                                    FROM ApprovalStepApproverConfig__mdt
                                                    WHERE StepConfig__r.DeveloperName = :step.DeveloperName
                                                    ORDER BY ExecutionOrder__c ASC]) {
            if (cfg.ApproverSource__c == 'Configured') {
                result.addAll(resolveConfiguredApprover(cfg, targetObjectId));
            } 
            else if (cfg.ApproverSource__c == 'Dynamic') {
                result.addAll(resolveDynamicApprovers(cfg, targetObjectId));
            } 
            else if (cfg.ApproverSource__c == 'UserInput') {
                result.addAll(resolveUserInputApprovers(userInputIds));
            }
        }
        return result;
    }

    private static List<ApproverAssignment> resolveConfiguredApprover(ApprovalStepApproverConfig__mdt cfg, Id targetObjectId) {
        if (cfg.ApproverType__c == 'User') {
            ApproverAssignment a = resolveConfiguredUser(cfg.ApproverValue__c);
            return a != null ? new List<ApproverAssignment>{ a } : new List<ApproverAssignment>();
        }
        if (cfg.ApproverType__c == 'Queue') {
            ApproverAssignment a = resolveConfiguredQueue(cfg.ApproverValue__c);
            return a != null ? new List<ApproverAssignment>{ a } : new List<ApproverAssignment>();
        }
        if (cfg.ApproverType__c == 'RelatedUser') {
            ApproverAssignment a = resolveRelatedUser(cfg.ApproverValue__c, targetObjectId);
            return a != null ? new List<ApproverAssignment>{ a } : new List<ApproverAssignment>();
        }
        return new List<ApproverAssignment>();
    }

    private static ApproverAssignment resolveConfiguredUser(String username) {
        List<User> users = [SELECT Id, Name FROM User WHERE Username = :username LIMIT 1];
        return users.isEmpty() ? null : new ApproverAssignment(users[0].Id, users[0].Name);
    }

    private static ApproverAssignment resolveConfiguredQueue(String devName) {
        List<Group> queues = [SELECT Id, Name FROM Group WHERE DeveloperName = :devName AND Type = 'Queue' LIMIT 1];
        return queues.isEmpty() ? null : new ApproverAssignment(queues[0].Id, queues[0].Name);
    }

    private static ApproverAssignment resolveRelatedUser(String fieldApiName, Id targetObjectId) {
        try {
            String objectName = targetObjectId.getSObjectType().getDescribe().getName();
            SObject record = Database.query('SELECT ' + fieldApiName + ' FROM ' + objectName + ' WHERE Id = :targetObjectId LIMIT 1');
            Id relatedUserId = (Id) record.get(fieldApiName);
            if (relatedUserId == null) return null;
            List<User> users = [SELECT Id, Name FROM User WHERE Id = :relatedUserId LIMIT 1];
            return users.isEmpty() ? null : new ApproverAssignment(users[0].Id, users[0].Name);
        } catch (Exception e) {
            System.debug('resolveRelatedUser error: ' + e.getMessage());
            return null;
        }
    }

    private static List<ApproverAssignment> resolveDynamicApprovers(ApprovalStepApproverConfig__mdt cfg, Id targetObjectId) {
        List<ApproverAssignment> result = new List<ApproverAssignment>();
        if (String.isBlank(cfg.ApproverResolverClass__c)) return result;
        try {
            IApproverResolver resolver = (IApproverResolver) Type.forName(cfg.ApproverResolverClass__c).newInstance();
            for (Id resolvedId : resolver.resolve(targetObjectId)) {
                result.add(new ApproverAssignment(resolvedId, resolveApproverName(resolvedId)));
            }
        } catch (Exception e) {
            System.debug('resolveDynamicApprovers error: ' + e.getMessage());
        }
        return result;
    }

    private static List<ApproverAssignment> resolveUserInputApprovers(List<Id> userInputIds) {
        List<ApproverAssignment> result = new List<ApproverAssignment>();
        if (userInputIds == null) return result;
        for (Id uid : userInputIds) {
            List<User> users = [SELECT Id, Name FROM User WHERE Id = :uid LIMIT 1];
            if (!users.isEmpty()) {
                result.add(new ApproverAssignment(users[0].Id, users[0].Name));
            }
        }
        return result;
    }

    private static String resolveApproverName(Id approverId) {
        String prefix = String.valueOf(approverId).left(3);
        if (prefix == '005') {
            List<User> users = [SELECT Name FROM User WHERE Id = :approverId LIMIT 1];
            return users.isEmpty() ? String.valueOf(approverId) : users[0].Name;
        }
        if (prefix == '00G') {
            List<Group> groups = [SELECT Name FROM Group WHERE Id = :approverId LIMIT 1];
            return groups.isEmpty() ? String.valueOf(approverId) : groups[0].Name;
        }
        return String.valueOf(approverId);
    }

    // ─── executeActions ───────────────────────────────────────────────────────────
    private static void executeActions(String processDevName, String stepDevName, String actionType, Id targetRecordId, Map<String, Object> context) {
        String filterField = String.isNotBlank(stepDevName) ? 'StepConfig__r.DeveloperName' : 'ProcessConfig__r.ProcessDeveloperName__c';
        String filterValue = String.isNotBlank(stepDevName) ? stepDevName : processDevName;

        String approvalActionConfigQuery = 'SELECT ActionKind__c, TargetFieldApiName__c, FieldValue__c, ' +
                                                'EmailTemplateName__c, NotifyCurrentStepApprovers__c, NotifyNextStepApprovers__c, ' +
                                                'NotifySubmitter__c, NotifyRecordOwner__c, AdditionalQueues__c, ' +
                                                'AdditionalUsers__c, ActionClass__c ' +
                                            'FROM ApprovalActionConfig__mdt ' +
                                            'WHERE ' + filterField + ' = :filterValue ' +
                                            'AND ActionType__c = :actionType ' +
                                            'AND IsActive__c = true ' +
                                            'ORDER BY ExecutionOrder__c ASC';
        String objectApiName = targetRecordId.getSObjectType().getDescribe().getName();

        for (ApprovalActionConfig__mdt cfg : (List<ApprovalActionConfig__mdt>)Database.query(approvalActionConfigQuery)) {
            try {
                if      (cfg.ActionKind__c == 'FieldUpdate')  executeFieldUpdate(cfg, targetRecordId);
                else if (cfg.ActionKind__c == 'EmailAlert')   executeEmailAlert(cfg, targetRecordId, objectApiName, context);
                else if (cfg.ActionKind__c == 'CustomApex')   executeCustomApex(cfg, targetRecordId, context);
            } 
            catch (Exception e) {
                System.debug('executeActions error [' + cfg.ActionKind__c + ']: ' + e.getMessage());
            }
        }
    }

    private static void executeFieldUpdate(ApprovalActionConfig__mdt cfg, Id targetRecordId) {
        SObject obj = targetRecordId.getSObjectType().newSObject(targetRecordId);
        obj.put(cfg.TargetFieldApiName__c, cfg.FieldValue__c);
        update obj;
    }

    private static void executeEmailAlert(ApprovalActionConfig__mdt cfg, Id targetRecordId, String objectApiName, Map<String, Object> context) {
        Set<String> recipientTypes = new Set<String>();
        if (cfg.NotifyCurrentStepApprovers__c) recipientTypes.add('CurrentStepApprovers');
        if (cfg.NotifyNextStepApprovers__c)    recipientTypes.add('NextStepApprovers');
        if (cfg.NotifySubmitter__c)            recipientTypes.add('Submitter');
        if (cfg.NotifyRecordOwner__c)          recipientTypes.add('RecordOwner');

        Set<Id> currentIds = context.containsKey('currentApproverIds') ? new Set<Id>((List<Id>) context.get('currentApproverIds')) : new Set<Id>();
        Set<Id> nextIds = context.containsKey('nextApproverIds') && context.get('nextApproverIds') != null ? new Set<Id>((List<Id>) context.get('nextApproverIds')) : new Set<Id>();
        Id submittedById = (Id) context.get('submittedById');

        Set<Id> recipients = EmailService.resolveRecipientIds(recipientTypes, currentIds, nextIds, submittedById, targetRecordId, objectApiName);
        recipients.addAll(EmailService.resolveAdditionalRecipientIds(cfg.AdditionalQueues__c, cfg.AdditionalUsers__c));

        if (!recipients.isEmpty()) {
            EmailService.sendTemplateEmail(cfg.EmailTemplateName__c, targetRecordId, recipients);
        }
    }

    private static void executeCustomApex(ApprovalActionConfig__mdt cfg, Id targetRecordId, Map<String, Object> context) {
        if (String.isBlank(cfg.ActionClass__c)) return;
        IApprovalAction customAction = (IApprovalAction) Type.forName(cfg.ActionClass__c).newInstance();
        customAction.execute(targetRecordId, UserInfo.getUserId(), context);
    }

    // ─── Inner classes ────────────────────────────────────────────────────────────
    public class ProcessResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  errorMessage;
    }

    private class ApproverAssignment {
        public Id     approverId;
        public String approverName;
        ApproverAssignment(Id approverId, String approverName) {
            this.approverId   = approverId;
            this.approverName = approverName;
        }
    }

    private class StepContext {
        public Id     approvalId;
        public String processName;
        public Id     targetRecordId;
        public Id     submittedById;
        public String stepDevName;
        public Id     currentUserId;
        StepContext(CustomApprovalStep__c step) {
            this.approvalId     = step.CustomApproval__c;
            this.processName    = step.CustomApproval__r.ProcessDeveloperName__c;
            this.targetRecordId = (Id) step.CustomApproval__r.TargetRecordId__c;
            this.submittedById  = step.CustomApproval__r.SubmittedBy__c;
            this.stepDevName    = step.StepDeveloperName__c;
            this.currentUserId  = UserInfo.getUserId();
        }
    }
}