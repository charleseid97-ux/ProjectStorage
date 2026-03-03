public with sharing class EventApprovalsPanelController {

    public class PendingRow {
        @AuraEnabled public String workItemId;
        @AuraEnabled public Id processInstanceId;
        @AuraEnabled public Id targetId;
        @AuraEnabled public String targetType;
        @AuraEnabled public String targetName;
        @AuraEnabled public String speakerName;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public String assignedApproverName;
        @AuraEnabled public String processName;
        @AuraEnabled public Boolean canAct;
    }

    public class ProcessedRow {
        @AuraEnabled public Id processInstanceId;
        @AuraEnabled public String targetName;
        @AuraEnabled public String speakerName;
        @AuraEnabled public String result;
        @AuraEnabled public String actorName;
        @AuraEnabled public Datetime actionDate;
        @AuraEnabled public String processName;
    }

    // Small container to carry the event + ESA data together
    private class EventContext {
        public Event__c evt;
        public List<EventSpeakerApprovals__c> esas;
        public Map<Id, String> targetNames = new Map<Id, String>();
        public Map<Id, String> speakerNames = new Map<Id, String>();
        public Set<Id> targetIds = new Set<Id>();
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getApprovalsForEvent(Id eventId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('pending', new List<PendingRow>());
        result.put('processed', new List<ProcessedRow>());

        if (eventId == null) return result;

        EventContext ctx = loadEventContext(eventId);
        if (ctx == null || ctx.targetIds.isEmpty()) return result;

        List<PendingRow> pending = buildPending(ctx);
        List<ProcessedRow> processed = buildProcessed(ctx);

        result.put('pending', pending);
        result.put('processed', processed);
        return result;
    }

    /**
     * Loads the Event and related EventSpeakerApprovals records,
     * then builds name lookup maps for targets and speakers.
     */
    private static EventContext loadEventContext(Id eventId) {
        EventContext ctx = new EventContext();

        ctx.evt = [
            SELECT Id, Name
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        ctx.esas = [
            SELECT Id, Name, Speaker__c, Speaker__r.Name
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :eventId
        ];

        // Target names include: the Event itself + each ESA
        ctx.targetNames.put(ctx.evt.Id, ctx.evt.Name);

        for (EventSpeakerApprovals__c e : ctx.esas) {
            ctx.targetNames.put(e.Id, e.Name);
            if (e.Speaker__c != null) {
                ctx.speakerNames.put(e.Id, e.Speaker__r.Name);
            }
        }

        ctx.targetIds.addAll(ctx.targetNames.keySet());
        return ctx;
    }

    /**
     * Builds the list of pending approval rows using ProcessInstanceWorkitem.
     * Also resolves submitter, process definition name and actor/queue display.
     */
    private static List<PendingRow> buildPending(EventContext ctx) {
        List<PendingRow> pending = new List<PendingRow>();
        List<ProcessInstanceWorkitem> workitems = queryWorkitems(ctx.targetIds);
        if (workitems.isEmpty()) return pending;

        PendingLookups lk = buildPendingLookups(workitems);

        Map<Id, String> procDefNames = resolveProcessDefinitionNames(lk.procDefIds);
        Map<Id, String> userNames = resolveUserNames(lk.allUserIds);

        Id me = UserInfo.getUserId();
        Set<Id> memberGroupIds = resolveMyGroupMembership(lk.actorGroupIds, me);

        for (ProcessInstanceWorkitem w : workitems) {
            pending.add(buildPendingRow(w, ctx, procDefNames, userNames, memberGroupIds, me));
        }
        return pending;
    }

    private class PendingLookups {
        public Set<Id> procDefIds = new Set<Id>();
        public Set<Id> submittedByIds = new Set<Id>();
        public Set<Id> actorUserIds = new Set<Id>();
        public Set<Id> actorGroupIds = new Set<Id>();
        public Set<Id> allUserIds = new Set<Id>();
    }

    private static List<ProcessInstanceWorkitem> queryWorkitems(Set<Id> targetIds) {
        if (targetIds == null || targetIds.isEmpty()) return new List<ProcessInstanceWorkitem>();

        return [
            SELECT Id,
                   ActorId,
                   ProcessInstance.Id,
                   ProcessInstance.TargetObjectId,
                   ProcessInstance.SubmittedById,
                   ProcessInstance.ProcessDefinitionId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId IN :targetIds
        ];
    }

    private static PendingLookups buildPendingLookups(List<ProcessInstanceWorkitem> workitems) {
        PendingLookups lk = new PendingLookups();

        for (ProcessInstanceWorkitem w : workitems) {
            if (w.ProcessInstance != null) {
                if (w.ProcessInstance.ProcessDefinitionId != null) lk.procDefIds.add(w.ProcessInstance.ProcessDefinitionId);
                if (w.ProcessInstance.SubmittedById != null) lk.submittedByIds.add(w.ProcessInstance.SubmittedById);
            }
            if (w.ActorId != null) {
                if (isUserId(w.ActorId)) lk.actorUserIds.add(w.ActorId);
                else if (isGroupId(w.ActorId)) lk.actorGroupIds.add(w.ActorId);
            }
        }

        lk.allUserIds.addAll(lk.submittedByIds);
        lk.allUserIds.addAll(lk.actorUserIds);
        return lk;
    }

    private static PendingRow buildPendingRow(
        ProcessInstanceWorkitem w,
        EventContext ctx,
        Map<Id, String> procDefNames,
        Map<Id, String> userNames,
        Set<Id> memberGroupIds,
        Id me
    ) {
        PendingRow r = new PendingRow();

        r.workItemId = w.Id;
        r.processInstanceId = (w.ProcessInstance != null) ? w.ProcessInstance.Id : null;
        r.targetId = (w.ProcessInstance != null) ? w.ProcessInstance.TargetObjectId : null;

        r.targetType = computeTargetType(r.targetId);
        r.targetName = resolveTargetName(r.targetId, ctx.targetNames);
        r.speakerName = (r.targetId != null) ? ctx.speakerNames.get(r.targetId) : null;

        r.submittedBy = resolveSubmittedByName(w, userNames);
        r.processName = resolveProcessName(w, procDefNames);

        AssignedApproverInfo ai = computeAssignedApprover(w.ActorId, userNames, memberGroupIds, me);
        r.assignedApproverName = ai.name;
        r.canAct = ai.canAct;

        return r;
    }

    private class AssignedApproverInfo {
        public String name;
        public Boolean canAct;
        public AssignedApproverInfo(String n, Boolean c) { name = n; canAct = c; }
    }

    private static AssignedApproverInfo computeAssignedApprover(
        Id actorId,
        Map<Id, String> userNames,
        Set<Id> memberGroupIds,
        Id me
    ) {
        if (actorId == null) return new AssignedApproverInfo(null, false);

        if (isUserId(actorId)) {
            return new AssignedApproverInfo(userNames.get(actorId), actorId == me);
        }
        if (isGroupId(actorId)) {
            Boolean canAct = (memberGroupIds != null && memberGroupIds.contains(actorId));
            return new AssignedApproverInfo('Queue', canAct);
        }

        return new AssignedApproverInfo(String.valueOf(actorId), false);
    }

    private static String computeTargetType(Id targetId) {
        if (targetId == null) return null;
        // Keep the existing heuristic used to detect Event vs ESA
        return String.valueOf(targetId).startsWith('a3v') ? 'Event' : 'ESA';
    }

    private static String resolveTargetName(Id targetId, Map<Id, String> targetNames) {
        if (targetId == null) return null;
        if (targetNames != null && targetNames.containsKey(targetId)) return targetNames.get(targetId);
        return String.valueOf(targetId);
    }

    private static String resolveSubmittedByName(ProcessInstanceWorkitem w, Map<Id, String> userNames) {
        if (w == null || w.ProcessInstance == null || w.ProcessInstance.SubmittedById == null) return null;
        return userNames.get(w.ProcessInstance.SubmittedById);
    }

    private static String resolveProcessName(ProcessInstanceWorkitem w, Map<Id, String> procDefNames) {
        if (w == null || w.ProcessInstance == null || w.ProcessInstance.ProcessDefinitionId == null) return null;
        return procDefNames.get(w.ProcessInstance.ProcessDefinitionId);
    }

    /**
     * Builds the list of processed approval rows based on the latest Approved/Rejected step per ProcessInstance.
     * Uses ProcessInstanceStep when available.
     */
    private static List<ProcessedRow> buildProcessed(EventContext ctx) {
        List<ProcessedRow> processed = new List<ProcessedRow>();

        List<ProcessInstanceStep> steps = queryApprovedRejectedStepsBestEffort(ctx.targetIds);
        if (steps.isEmpty()) return processed;

        Map<Id, ProcessInstanceStep> latestByProcess = keepLatestStepByProcess(steps);

        Set<Id> actorUserIds = new Set<Id>();
        Set<Id> procDefIds = new Set<Id>();
        for (ProcessInstanceStep s : latestByProcess.values()) {
            if (s.ActorId != null && isUserId(s.ActorId)) actorUserIds.add(s.ActorId);
            if (s.ProcessInstance != null && s.ProcessInstance.ProcessDefinitionId != null) procDefIds.add(s.ProcessInstance.ProcessDefinitionId);
        }

        Map<Id, String> actorNames = resolveUserNames(actorUserIds);
        Map<Id, String> procDefNames = resolveProcessDefinitionNames(procDefIds);

        for (Id procId : latestByProcess.keySet()) {
            ProcessInstanceStep s = latestByProcess.get(procId);
            if (s == null) continue;
            processed.add(buildProcessedRow(procId, s, ctx, actorNames, procDefNames));
        }

        return processed;
    }

    private static List<ProcessInstanceStep> queryApprovedRejectedStepsBestEffort(Set<Id> targetIds) {
        if (targetIds == null || targetIds.isEmpty()) return new List<ProcessInstanceStep>();

        try {
            return [
                SELECT Id,
                       ProcessInstanceId,
                       ProcessInstance.TargetObjectId,
                       ProcessInstance.ProcessDefinitionId,
                       StepStatus,
                       ActorId,
                       CreatedDate
                FROM ProcessInstanceStep
                WHERE ProcessInstance.TargetObjectId IN :targetIds
                  AND StepStatus IN ('Approved','Rejected')
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception ex) {
            // Some orgs may not expose ProcessInstanceStep
            return new List<ProcessInstanceStep>();
        }
    }

    private static Map<Id, ProcessInstanceStep> keepLatestStepByProcess(List<ProcessInstanceStep> steps) {
        Map<Id, ProcessInstanceStep> latestByProcess = new Map<Id, ProcessInstanceStep>();
        for (ProcessInstanceStep s : steps) {
            if (s == null || s.ProcessInstanceId == null) continue;
            if (!latestByProcess.containsKey(s.ProcessInstanceId)) {
                latestByProcess.put(s.ProcessInstanceId, s);
            }
        }
        return latestByProcess;
    }

    private static ProcessedRow buildProcessedRow(
        Id processInstanceId,
        ProcessInstanceStep s,
        EventContext ctx,
        Map<Id, String> actorNames,
        Map<Id, String> procDefNames
    ) {
        ProcessedRow pr = new ProcessedRow();
        pr.processInstanceId = processInstanceId;

        Id tid = (s.ProcessInstance != null) ? s.ProcessInstance.TargetObjectId : null;
        pr.targetName = resolveTargetName(tid, ctx.targetNames);
        pr.speakerName = (tid != null) ? ctx.speakerNames.get(tid) : null;

        pr.result = s.StepStatus;
        pr.actorName = resolveActorName(s.ActorId, actorNames);
        pr.actionDate = s.CreatedDate;

        Id pdId = (s.ProcessInstance != null) ? s.ProcessInstance.ProcessDefinitionId : null;
        pr.processName = (pdId != null) ? procDefNames.get(pdId) : null;

        return pr;
    }

    private static String resolveActorName(Id actorId, Map<Id, String> actorNames) {
        if (actorId == null) return '';
        if (actorNames != null && actorNames.containsKey(actorId)) return actorNames.get(actorId);
        return String.valueOf(actorId);
    }

    /**
     * Resolves ProcessDefinition names. The query can fail depending on org access,
     * so this method is best-effort and returns an empty map if not available.
     */
    private static Map<Id, String> resolveProcessDefinitionNames(Set<Id> procDefIds) {
        Map<Id, String> procDefNames = new Map<Id, String>();
        if (procDefIds == null || procDefIds.isEmpty()) return procDefNames;

        try {
            for (ProcessDefinition pd : [
                SELECT Id, Name
                FROM ProcessDefinition
                WHERE Id IN :procDefIds
            ]) {
                procDefNames.put(pd.Id, pd.Name);
            }
        } catch (Exception ex) {
            procDefNames.clear();
        }
        return procDefNames;
    }

    /**
     * Resolves User.Id -> User.Name for a given set of user ids.
     */
    private static Map<Id, String> resolveUserNames(Set<Id> userIds) {
        Map<Id, String> names = new Map<Id, String>();
        if (userIds == null || userIds.isEmpty()) return names;

        for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) {
            names.put(u.Id, u.Name);
        }
        return names;
    }

    /**
     * Returns the groups (queues/public groups/roles) from a given set where the current user is a member.
     */
    private static Set<Id> resolveMyGroupMembership(Set<Id> actorGroupIds, Id me) {
        Set<Id> memberGroupIds = new Set<Id>();
        if (actorGroupIds == null || actorGroupIds.isEmpty() || me == null) return memberGroupIds;

        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE GroupId IN :actorGroupIds
              AND UserOrGroupId = :me
        ]) {
            memberGroupIds.add(gm.GroupId);
        }
        return memberGroupIds;
    }

    private static Boolean isUserId(Id anyId) {
        return anyId != null && String.valueOf(anyId).startsWith('005');
    }

    private static Boolean isGroupId(Id anyId) {
        return anyId != null && String.valueOf(anyId).startsWith('00G');
    }

    @AuraEnabled
    public static void actOnWorkitem(Id workItemId, String action, String comments) {
        validateActionInputs(workItemId, action);

        ProcessInstanceWorkitem wi = loadWorkitem(workItemId);

        Id me = UserInfo.getUserId();
        validateActorCanAct(wi.ActorId, me);

        Approval.ProcessWorkitemRequest req = buildApprovalRequest(workItemId, action, comments, wi.ActorId, me);
        processApprovalRequest(req);
    }

    /**
     * Validates required parameters for an approval action.
     */
    private static void validateActionInputs(Id workItemId, String action) {
        if (workItemId == null || action == null) {
            throw new AuraHandledException('Missing parameters');
        }
    }

    /**
     * Loads a ProcessInstanceWorkitem by id and returns it.
     */
    private static ProcessInstanceWorkitem loadWorkitem(Id workItemId) {
        try {
            ProcessInstanceWorkitem wi = [
                SELECT Id, ActorId
                FROM ProcessInstanceWorkitem
                WHERE Id = :workItemId
                LIMIT 1
            ];
            if (wi == null) throw new AuraHandledException('Approval workitem not found.');
            return wi;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to find the approval workitem.');
        }
    }

    /**
     * Ensures the current user is allowed to act based on the ActorId:
     * - If ActorId is a user, it must be the current user.
     * - If ActorId is a group, the current user must be a member.
     */
    private static void validateActorCanAct(Id actorId, Id me) {
        if (actorId == null) return;

        if (isUserId(actorId)) {
            if (actorId != me) {
                throw new AuraHandledException('You are not the assigned approver for this request.');
            }
            return;
        }

        if (isGroupId(actorId)) {
            Integer membershipCount;
            try {
                membershipCount = [
                    SELECT COUNT()
                    FROM GroupMember
                    WHERE GroupId = :actorId
                      AND UserOrGroupId = :me
                ];
            } catch (Exception ex) {
                throw new AuraHandledException('Unable to validate queue membership.');
            }
            if (membershipCount == 0) {
                throw new AuraHandledException('You are not a member of the queue assigned to this approval request.');
            }
        }
    }

    /**
     * Creates an Approval.ProcessWorkitemRequest for Approve/Reject actions.
     * For queue-assigned workitems, sets NextApproverIds to the current user.
     */
    private static Approval.ProcessWorkitemRequest buildApprovalRequest(
        Id workItemId,
        String action,
        String comments,
        Id actorId,
        Id me
    ) {
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(workItemId);
        req.setComments(comments == null ? '' : comments);
        req.setAction(action); // 'Approve' or 'Reject'

        if (isGroupId(actorId)) {
            req.setNextApproverIds(new Id[] { me });
        }
        return req;
    }

    /**
     * Executes the Approval.process call and transforms errors into an AuraHandledException.
     */
    private static void processApprovalRequest(Approval.ProcessWorkitemRequest req) {
        try {
            Approval.ProcessResult res = Approval.process(req);
            if (!res.isSuccess()) {
                String combined;
                try {
                    combined = JSON.serialize(res.getErrors());
                } catch (Exception e) {
                    combined = 'Unknown approval error';
                }
                throw new AuraHandledException('Approval action failed: ' + combined);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Approval action failed: ' + ex.getMessage());
        }
    }
}