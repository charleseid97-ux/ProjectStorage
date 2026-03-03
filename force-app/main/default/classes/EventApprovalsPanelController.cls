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

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getApprovalsForEvent(Id eventId) {

        Map<String, Object> result = new Map<String, Object>();
        result.put('pending', new List<PendingRow>());
        result.put('processed', new List<ProcessedRow>());

        if (eventId == null) return result;

        // Event and its ESAs
        Event__c evt = [
            SELECT Id, Name
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        List<EventSpeakerApprovals__c> esas = [
            SELECT Id, Name, Speaker__c, Speaker__r.Name
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :eventId
        ];

        // Build name lookups for targets and speakers
        Map<Id, String> targetNames = new Map<Id, String>();
        Map<Id, String> speakerNames = new Map<Id, String>();
        targetNames.put(evt.Id, evt.Name);
        for (EventSpeakerApprovals__c e : esas) {
            targetNames.put(e.Id, e.Name);
            if (e.Speaker__c != null) speakerNames.put(e.Id, e.Speaker__r.Name);
        }

        Set<Id> targetIds = new Set<Id>(targetNames.keySet());

        /*
         * PENDING: ProcessInstanceWorkitem
         */
        List<PendingRow> pending = new List<PendingRow>();

        if (!targetIds.isEmpty()) {
            List<ProcessInstanceWorkitem> workitems = [
                SELECT Id,
                       ActorId,
                       ProcessInstance.Id,
                       ProcessInstance.TargetObjectId,
                       ProcessInstance.SubmittedById,
                       ProcessInstance.ProcessDefinitionId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId IN :targetIds
            ];

            // Collect ids for lookups
            Set<Id> procDefIds = new Set<Id>();
            Set<Id> submittedByIds = new Set<Id>();
            Set<Id> actorUserIds = new Set<Id>();
            Set<Id> actorGroupIds = new Set<Id>();

            for (ProcessInstanceWorkitem w : workitems) {
                if (w.ProcessInstance != null) {
                    if (w.ProcessInstance.ProcessDefinitionId != null) procDefIds.add(w.ProcessInstance.ProcessDefinitionId);
                    if (w.ProcessInstance.SubmittedById != null) submittedByIds.add(w.ProcessInstance.SubmittedById);
                }
                if (w.ActorId != null) {
                    String prefix = String.valueOf(w.ActorId).substring(0,3);
                    if (prefix == '005') actorUserIds.add(w.ActorId);
                    else if (prefix == '00G') actorGroupIds.add(w.ActorId);
                }
            }

            // Resolve ProcessDefinition names (best-effort)
            Map<Id, String> procDefNames = new Map<Id, String>();
            if (!procDefIds.isEmpty()) {
                try {
                    for (ProcessDefinition pd : [ SELECT Id, Name  FROM ProcessDefinition WHERE Id IN :procDefIds ]) {
                        procDefNames.put(pd.Id, pd.Name );
                    }
                } catch (Exception ex) {
                    procDefNames.clear();
                }
            }

            // Resolve users (submitters + assigned user actors)
            Map<Id, String> userNames = new Map<Id, String>();
            Set<Id> allUserIds = new Set<Id>();
            allUserIds.addAll(submittedByIds);
            allUserIds.addAll(actorUserIds);
            if (!allUserIds.isEmpty()) {
                for (User u : [ SELECT Id, Name FROM User WHERE Id IN :allUserIds ]) {
                    userNames.put(u.Id, u.Name);
                }
            }

            // Determine group membership for current user
            Id me = UserInfo.getUserId();
            Set<Id> memberGroupIds = new Set<Id>();
            if (!actorGroupIds.isEmpty()) {
                for (GroupMember gm : [ SELECT GroupId FROM GroupMember WHERE GroupId IN :actorGroupIds AND UserOrGroupId = :me ]) {
                    memberGroupIds.add(gm.GroupId);
                }
            }

            // Build pending rows
            for (ProcessInstanceWorkitem w : workitems) {
                PendingRow r = new PendingRow();
                r.workItemId = w.Id;
                r.processInstanceId = (w.ProcessInstance != null) ? w.ProcessInstance.Id : null;
                r.targetId = (w.ProcessInstance != null) ? w.ProcessInstance.TargetObjectId : null;
                r.targetType = (r.targetId != null && String.valueOf(r.targetId).startsWith('a3v')) ? 'Event' : 'ESA';
                r.targetName = (r.targetId != null && targetNames.containsKey(r.targetId)) ? targetNames.get(r.targetId) : (r.targetId != null ? String.valueOf(r.targetId) : null);
                r.speakerName = speakerNames.get(r.targetId);

                r.submittedBy = (w.ProcessInstance != null && w.ProcessInstance.SubmittedById != null) ? userNames.get(w.ProcessInstance.SubmittedById) : null;

                Id pdId = (w.ProcessInstance != null) ? w.ProcessInstance.ProcessDefinitionId : null;
                r.processName = (pdId != null) ? procDefNames.get(pdId) : null;

                // assigned approver name
                if (w.ActorId != null) {
                    String prefix = String.valueOf(w.ActorId).substring(0,3);
                    if (prefix == '005') {
                        r.assignedApproverName = userNames.get(w.ActorId);
                        r.canAct = (w.ActorId == me);
                    } else if (prefix == '00G') {
                        r.assignedApproverName = 'Queue';
                        r.canAct = memberGroupIds.contains(w.ActorId);
                    } else {
                        r.assignedApproverName = String.valueOf(w.ActorId);
                        r.canAct = false;
                    }
                } else {
                    r.assignedApproverName = null;
                    r.canAct = false;
                }

                pending.add(r);
            }

            result.put('pending', pending);
        }

        /*
         * PROCESSED: use ProcessInstanceStep (keep latest Approved/Rejected step per ProcessInstance)
         */
        List<ProcessedRow> processed = new List<ProcessedRow>();

        if (!targetIds.isEmpty()) {
            List<ProcessInstanceStep> steps = new List<ProcessInstanceStep>();
            try {
                steps = [
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
                // Some orgs may not expose ProcessInstanceStep; ignore if not available
                steps.clear();
            }

            // Keep only the latest step per ProcessInstanceId
            Map<Id, ProcessInstanceStep> latestByProcess = new Map<Id, ProcessInstanceStep>();
            for (ProcessInstanceStep s : steps) {
                if (s == null || s.ProcessInstanceId == null) continue;
                if (!latestByProcess.containsKey(s.ProcessInstanceId)) latestByProcess.put(s.ProcessInstanceId, s);
            }

            // Resolve actor names for processed steps and procDef ids
            Set<Id> actorIdsForProcessed = new Set<Id>();
            Set<Id> procDefIdsForProcessed = new Set<Id>();
            for (ProcessInstanceStep s : latestByProcess.values()) {
                if (s.ActorId != null && String.valueOf(s.ActorId).startsWith('005')) actorIdsForProcessed.add(s.ActorId);
                if (s.ProcessInstance != null && s.ProcessInstance.ProcessDefinitionId != null) procDefIdsForProcessed.add(s.ProcessInstance.ProcessDefinitionId);
            }

            Map<Id, String> actorsById = new Map<Id, String>();
            if (!actorIdsForProcessed.isEmpty()) {
                for (User u : [ SELECT Id, Name FROM User WHERE Id IN :actorIdsForProcessed ]) {
                    actorsById.put(u.Id, u.Name);
                }
            }

            Map<Id, String> procDefNamesProcessed = new Map<Id, String>();
            if (!procDefIdsForProcessed.isEmpty()) {
                try {
                    for (ProcessDefinition pd : [ SELECT Id, Name  FROM ProcessDefinition WHERE Id IN :procDefIdsForProcessed ]) {
                        procDefNamesProcessed.put(pd.Id, pd.Name );
                    }
                } catch (Exception ex) {
                    procDefNamesProcessed.clear();
                }
            }

            // Build processed rows
            for (Id procId : latestByProcess.keySet()) {
                ProcessInstanceStep s = latestByProcess.get(procId);
                if (s == null) continue;

                ProcessedRow pr = new ProcessedRow();
                pr.processInstanceId = procId;

                Id tid = (s.ProcessInstance != null) ? s.ProcessInstance.TargetObjectId : null;
                pr.targetName = (tid != null && targetNames.containsKey(tid)) ? targetNames.get(tid) : (tid != null ? String.valueOf(tid) : null);
                pr.speakerName = speakerNames.get(tid);

                pr.result = s.StepStatus;
                pr.actorName = (s.ActorId != null && actorsById.containsKey(s.ActorId)) ? actorsById.get(s.ActorId) : (s.ActorId != null ? String.valueOf(s.ActorId) : '');
                pr.actionDate = s.CreatedDate;

                Id pdId = (s.ProcessInstance != null) ? s.ProcessInstance.ProcessDefinitionId : null;
                pr.processName = (pdId != null) ? procDefNamesProcessed.get(pdId) : null;

                processed.add(pr);
            }

            result.put('processed', processed);
        }

        return result;
    }

    @AuraEnabled
    public static void actOnWorkitem(Id workItemId, String action, String comments) {

        if (workItemId == null || action == null) {
            throw new AuraHandledException('Missing parameters');
        }

        // Load the workitem and ActorId
        ProcessInstanceWorkitem wi;
        try {
            wi = [ SELECT Id, ActorId FROM ProcessInstanceWorkitem WHERE Id = :workItemId LIMIT 1 ];
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to find the approval workitem.');
        }

        if (wi == null) throw new AuraHandledException('Approval workitem not found.');

        Id actorId = wi.ActorId;
        Id me = UserInfo.getUserId();

        // If assigned to a specific user and it's not me -> block
        if (actorId != null && String.valueOf(actorId).startsWith('005')) {
            if (actorId != me) throw new AuraHandledException('You are not the assigned approver for this request.');
        }

        // If assigned to a group/queue, ensure current user is member
        Boolean actingAsQueueMember = false;
        if (actorId != null && String.valueOf(actorId).startsWith('00G')) {
            Integer membershipCount = 0;
            try {
                membershipCount = [ SELECT COUNT() FROM GroupMember WHERE GroupId = :actorId AND UserOrGroupId = :me ];
            } catch (Exception ex) {
                throw new AuraHandledException('Unable to validate queue membership.');
            }
            if (membershipCount == 0) throw new AuraHandledException('You are not a member of the queue assigned to this approval request.');
            actingAsQueueMember = true;
        }

        // Build and run Approval API request
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(workItemId);
        req.setComments(comments == null ? '' : comments);
        req.setAction(action); // 'Approve' or 'Reject'

        if (actingAsQueueMember) req.setNextApproverIds(new Id[] { me });

        try {
            Approval.ProcessResult res = Approval.process(req);
            if (!res.isSuccess()) {
                String combined;
                try { combined = JSON.serialize(res.getErrors()); } catch (Exception e) { combined = 'Unknown approval error'; }
                throw new AuraHandledException('Approval action failed: ' + combined);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Approval action failed: ' + ex.getMessage());
        }
    }

    
}