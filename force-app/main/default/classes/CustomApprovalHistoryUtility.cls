/** ──────────────────────────────────────
 * @description Core service class for the custom approval process engine.
 *              Handles submission, step-by-step approval/rejection/recall flows,
 *              approver resolution (configured, dynamic, user-input), and
 *              post-action execution (field updates, email alerts, custom Apex).
 * @author Charles EID
 * @testClass CustomApprovalHistoryUtilityTest
 * @coverage 65%   [20-05-26]
 ────────────────────────────────────── */
public without sharing class CustomApprovalHistoryUtility {

    private static final Set<String> LOCK_SYSTEM_FIELDS = new Set<String>{'id', 'createdbyid', 'createddate', 'lastmodifiedbyid', 'lastmodifieddate', 'systemmodstamp', 'isdeleted', 'lastactivitydate', 'lastreferenceddate', 'lastvieweddate'};

    // ─── submitForApproval ────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProcessResult submitForApproval(Id recordId, String processName, String comments) {
        ProcessResult result = new ProcessResult();
        result.success      = false;
        result.errorMessage = null;
        try {
            List<ApprovalStepConfig__mdt> allSteps = [SELECT Id, DeveloperName, StepOrder__c, StepLabel__c, ApprovalMode__c
                                                      FROM ApprovalStepConfig__mdt
                                                      WHERE ProcessConfig__r.DeveloperName = :processName
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

            CustomApproval__c approval = createCustomApproval(String.valueOf(recordId), processName, 'Pending', currentUserId, initialStep.DeveloperName, comments, false);
            insert approval;

            List<CustomApprovalStep__c> steps = new List<CustomApprovalStep__c>();
            steps.add(createCustomApprovalStep(approval.Id, 'Submitted', 'Submitted', 'Started', false, null, null, null, null, currentUserId, System.now(), comments));
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
    public static ProcessResult processApproval(Id stepId, String action, String comments, List<Id> userInputApproverIds) {
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
                    handleApprove(ctx, siblings, allCurrentIds, userInputApproverIds);
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

    private static void handleApprove(StepContext ctx, List<CustomApprovalStep__c> siblings, Set<Id> allCurrentIds, List<Id> userInputApproverIds) {
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

        List<ApprovalStepConfig__mdt> nextSteps = [SELECT Id, DeveloperName, StepLabel__c, ApprovalMode__c, StepOrder__c
                                                   FROM ApprovalStepConfig__mdt
                                                   WHERE ProcessConfig__r.DeveloperName = :ctx.processName
                                                     AND StepOrder__c > :stepCfg.StepOrder__c
                                                   ORDER BY StepOrder__c ASC LIMIT 1];

        if (!nextSteps.isEmpty()) {
            ApprovalStepConfig__mdt nextStep = nextSteps[0];
            List<ApproverAssignment> nextAssignments = resolveApprovers(ctx.processName, nextStep, ctx.targetRecordId, userInputApproverIds);
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
            records.add(createCustomApprovalStep(approvalId, step.DeveloperName, step.StepLabel__c, 'Pending', true, String.valueOf(a.approverId), a.approverName, String.valueOf(a.approverId), a.approverName, null, null, null));
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
        for (ApprovalStepApproverConfig__mdt cfg : [SELECT ApproverSource__c, ApproverType__c, ApproverValue__c, ApproverResolverClass__c, ExecutionOrder__c
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
        String filterField = String.isNotBlank(stepDevName) ? 'StepConfig__r.DeveloperName' : 'ProcessConfig__r.DeveloperName';
        String filterValue = String.isNotBlank(stepDevName) ? stepDevName : processDevName;

        String approvalActionConfigQuery = 'SELECT ActionKind__c, TargetFieldApiName__c, FieldValue__c, ExecutionOrder__c, ' +
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
            if      (cfg.ActionKind__c == 'FieldUpdate')  executeFieldUpdate(cfg, targetRecordId);
            else if (cfg.ActionKind__c == 'EmailAlert')   executeEmailAlert(cfg, targetRecordId, objectApiName, context);
            else if (cfg.ActionKind__c == 'CustomApex')   executeCustomApex(cfg, targetRecordId, context);
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

        // ─── Record factories ─────────────────────────────────────────────────────────
    public static CustomApproval__c createCustomApproval(String targetRecordId, String processDevName, String status, Id submittedById, String currentStepDevName, String comments, Boolean readOnly) {
        return new CustomApproval__c(
            TargetRecordId__c       = targetRecordId,
            Status__c               = status,
            SubmittedBy__c          = submittedById,
            ProcessDeveloperName__c = processDevName,
            CurrentStepDevName__c   = currentStepDevName,
            Comments__c             = comments,
            TECH_ReadOnly__c        = readOnly
        );
    }

    public static CustomApprovalStep__c createCustomApprovalStep(Id approvalId, String stepDevName, String stepLabel, String status, Boolean isCurrentStep, String assignedToId, String assignedToName, String origAssignedToId, String origAssignedToName, Id actualApproverId, Datetime actionDate, String comments) {
        return new CustomApprovalStep__c(
            CustomApproval__c         = approvalId,
            StepDeveloperName__c      = stepDevName,
            StepLabel__c              = stepLabel,
            Status__c                 = status,
            IsCurrentStep__c          = isCurrentStep,
            AssignedTo__c             = assignedToId,
            AssignedToName__c         = assignedToName,
            OriginalAssignedTo__c     = origAssignedToId,
            OriginalAssignedToName__c = origAssignedToName,
            ActualApprover__c         = actualApproverId,
            ActionDate__c             = actionDate,
            Comments__c               = comments
        );
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

    // ─── Approval lock enforcement ────────────────────────────────────────────────
    private static ApprovalLockConfig__mdt getLockConfig(String objectApiName) {
        List<ApprovalLockConfig__mdt> configs = [SELECT StatusFieldApiName__c, LockedStatuses__c, ExemptFields__c
                                                 FROM ApprovalLockConfig__mdt
                                                 WHERE ObjectApiName__c = :objectApiName
                                                   AND Active__c = true
                                                 LIMIT 1];
        return configs.isEmpty() ? null : configs[0];
    }

    private static Set<String> splitCSV(String csv) {
        Set<String> result = new Set<String>();
        if (String.isBlank(csv)) return result;
        for (String entry : csv.split(',')) {
            String trimmed = entry.trim();
            if (String.isNotBlank(trimmed)) result.add(trimmed.toLowerCase());
        }
        return result;
    }

    public static void enforceApprovalLock(List<SObject> newRecords, Map<Id, SObject> oldRecords) {
        if (newRecords == null || newRecords.isEmpty()) return;

        String objectApiName = newRecords[0].getSObjectType().getDescribe().getName();
        ApprovalLockConfig__mdt config = getLockConfig(objectApiName);
        if (config == null) return;

        Set<String> lockedStatuses = splitCSV(config.LockedStatuses__c);
        Set<String> exemptFields   = splitCSV(config.ExemptFields__c);
        exemptFields.addAll(LOCK_SYSTEM_FIELDS);
        String statusField = config.StatusFieldApiName__c;

        for (SObject newRecord : newRecords) {
            SObject oldRecord  = oldRecords.get((Id) newRecord.get('Id'));
            String  oldStatus  = (String) oldRecord.get(statusField);
            String  newStatus  = (String) newRecord.get(statusField);

            if (!lockedStatuses.contains(oldStatus)) continue; // not in a locked status
            if (newStatus != oldStatus) continue;              // approval transition itself — allow

            for (String fieldName : newRecord.getPopulatedFieldsAsMap().keySet()) {
                if (exemptFields.contains(fieldName.toLowerCase())) continue;
                if (newRecord.get(fieldName) != oldRecord.get(fieldName)) {
                    newRecord.addError('This record is locked while in \'' + oldStatus + '\' status and cannot be edited.');
                    break;
                }
            }
        }
    }
}