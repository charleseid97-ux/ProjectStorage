public with sharing class EventSpeakerApprovalsService {

    private static final String DEFAULT_QUEUE_DEV_NAME    = 'EventTeam';
    private static final String DEFAULT_TEMPLATE_DEV_NAME = 'EventTeamApproval';

    private static final String SPEAKER_APPROVAL_PROCESS_DEVNAME = 'SpeakerApproval';
    private static final String HOP_APPROVAL_PROCESS_DEVNAME = 'SpeakerApprovalHOP';

    public static Boolean isDisabled(Boolean handlerToggle) {
        if (Type.forName('PAD') != null) {
            try {
                return PAD.canTrigger('EventSpeakerApprovalsTriggerHandler') ? handlerToggle : true;
            } catch (Exception e) {
                return handlerToggle;
            }
        }
        return handlerToggle;
    }

    public static void trackStatusUpdateOnInsert(List<EventSpeakerApprovals__c> newList) {
        if (newList == null || newList.isEmpty()) return;
        applyStatusAudit(newList, null);
    }

    public static void trackStatusUpdateOnUpdate(
        Map<Id, EventSpeakerApprovals__c> newMap,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;
        applyStatusAudit(newMap.values(), oldMap);
    }

    // After insert: handle rollup, approval submission and sharing
    public static void manageRollupOnInsert(Map<Id, EventSpeakerApprovals__c> newMap) {
        if (newMap == null || newMap.isEmpty()) return;

        // Collect related Event Ids from approvals
        Set<Id> eventIds = new Set<Id>();
        for (EventSpeakerApprovals__c rec : newMap.values()) {
            if (rec.Event__c != null) eventIds.add(rec.Event__c);
        }

        // Load event flags used to control rollup execution
        if (!eventIds.isEmpty()) {
            Map<Id, Event__c> eventMap = new Map<Id, Event__c>(
                [SELECT Id, OrganizerApprovalRequired__c, OrganizerDecision__c
                FROM Event__c
                WHERE Id IN :eventIds]
            );

            // Stop processing if organizer approval is required but not yet approved
            for (Event__c evt : eventMap.values()) {
                if (evt.OrganizerApprovalRequired__c && evt.OrganizerDecision__c != 'Approved') {
                    return;
                }
            }
        }

        // Execute status rollup on events
        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(newMap.values());
    }

    // Update rollup only if status changed AND organizer condition is respected
    public static void manageRollupOnUpdate(
        Map<Id, EventSpeakerApprovals__c> newMap,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;

        List<EventSpeakerApprovals__c> statusChangedRecords = new List<EventSpeakerApprovals__c>();
        Set<Id> eventIds = new Set<Id>();

        // Collect only records where status changed
        for (Id recordId : newMap.keySet()) {
            EventSpeakerApprovals__c newRec = newMap.get(recordId);
            EventSpeakerApprovals__c oldRec = oldMap.get(recordId);

            if (newRec.Status__c != oldRec.Status__c) {
                statusChangedRecords.add(newRec);
                if (newRec.Event__c != null) eventIds.add(newRec.Event__c);
            }
        }

        if (statusChangedRecords.isEmpty()) return;

        // Load event flags
        Map<Id, Event__c> eventMap = new Map<Id, Event__c>(
            [SELECT Id, OrganizerApprovalRequired__c, OrganizerDecision__c
            FROM Event__c
            WHERE Id IN :eventIds]
        );

        // Check organizer condition globally
        for (Event__c evt : eventMap.values()) {
            if (evt.OrganizerApprovalRequired__c && evt.OrganizerDecision__c != 'Approved') {
                System.debug('rollout approvals aborted because Event not approved by organizer');
                return;
            }
        }

        // Normal behavior
        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(statusChangedRecords);
    }

    /**
     *   routing basé sur approvalType__c
     */
    public static void submitForSpeakerApproval(List<EventSpeakerApprovals__c> records, Map<Id, EventSpeakerApprovals__c> oldMap) {
        if (records == null || records.isEmpty()) return;

        Boolean isAfterInsert = (oldMap == null || oldMap.isEmpty());

        for (EventSpeakerApprovals__c rec : records) {
            if (rec == null || rec.Id == null) continue;

            // AFTER INSERT
            if (isAfterInsert) {

                // Only submitted records go to approval
                if (rec.Status__c != 'Submitted') continue;

                if (rec.approvalType__c == 'Speaker') {
                    submitApproval(
                        rec.Id,
                        SPEAKER_APPROVAL_PROCESS_DEVNAME,
                        'Auto-submitted (Speaker)'
                    );
                } 
                else if (rec.approvalType__c == 'HOP') {
                    submitApproval(
                        rec.Id,
                        HOP_APPROVAL_PROCESS_DEVNAME,
                        'Auto-submitted (HOP)'
                    );
                }

                // Auto → no process
                continue;
            }

            // AFTER UPDATE: no chained resubmission anymore
            continue;
        }
    }

    @AuraEnabled
    public static void recallApproval(Id recallTargetId, Id eventSpeakerApprovalId, String processDeveloperName, String comments) {
        if (recallTargetId == null) {
            throw new AuraHandledException('Recall target Id is required.');
        }
        if (String.isBlank(processDeveloperName)) {
            throw new AuraHandledException('Process developer name is required.');
        }

        try {
            String finalComment = String.isBlank(comments)
                ? 'Resubmitted from recall action'
                : comments;

            if (eventSpeakerApprovalId != null) {
                EventSpeakerApprovals__c rec = [
                    SELECT Id, Status__c
                    FROM EventSpeakerApprovals__c
                    WHERE Id = :eventSpeakerApprovalId
                    LIMIT 1
                ];

                if (rec.Status__c != 'Submitted') {
                    rec.Status__c = 'Submitted';
                    update rec;
                }

                submitApproval(eventSpeakerApprovalId, processDeveloperName, finalComment);

            } else {
                Event__c evt = [
                    SELECT Id, Status__c
                    FROM Event__c
                    WHERE Id = :recallTargetId
                    LIMIT 1
                ];

                if (evt.Status__c != 'SubmittedToEventTeam') {
                    evt.Status__c = 'SubmittedToEventTeam';
                    update evt;
                }

                submitApproval(recallTargetId, processDeveloperName, finalComment);
            }

        } catch (Exception ex) {
            throw new AuraHandledException('Recall approval failed: ' + ex.getMessage());
        }
    }

    private static Approval.ProcessResult submitApproval(Id recordId, String processDeveloperName, String comments) {
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(recordId);
        req.setProcessDefinitionNameOrId(processDeveloperName);
        req.setComments(String.isBlank(comments) ? '' : comments);

        return Approval.process(req);
    }

    private static void applyStatusAudit(
        List<EventSpeakerApprovals__c> newList,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) return;

        for (EventSpeakerApprovals__c rec : newList) {
            String oldStatus = (oldMap == null || rec.Id == null || !oldMap.containsKey(rec.Id))
                ? null
                : oldMap.get(rec.Id).Status__c;

            Boolean statusChanged = (oldMap == null)
                ? String.isNotBlank(rec.Status__c)
                : (rec.Status__c != oldStatus);

            if (!statusChanged) continue;

            rec.StatusChangeDate__c = System.now();
            rec.StatusChangedBy__c  = UserInfo.getUserId();
        }
    }

    /**
     * 
     
    public static void requireHOPApproval(List<EventSpeakerApprovals__c> newList) {
        // deprecated logic (can be removed if unused)
    }*/
    
    // Updates Event status from Event before update without DML
    public static void triggerRollupFromEventBeforeUpdate(
        Map<Id, Event__c> newMap,
        Map<Id, Event__c> oldMap
    ) {
        system.debug('triggerRollupFromEventBeforeUpdate===============');
        if (newMap == null || newMap.isEmpty()) return;

        Set<Id> eventIds = new Set<Id>();

        // Detect OrganizerDecision__c becoming Approved
        for (Id evtId : newMap.keySet()) {
            Event__c newEvt = newMap.get(evtId);
            Event__c oldEvt = oldMap.get(evtId);
            system.debug('triggerRollupFromEventBeforeUpdate==========newEvt.OrganizerApprovalRequired__c====='+newEvt.OrganizerApprovalRequired__c);
            system.debug('triggerRollupFromEventBeforeUpdate========== newEvt.OrganizerDecision__c====='+ newEvt.OrganizerDecision__c);
            system.debug('triggerRollupFromEventBeforeUpdate===========oldEvt.OrganizerDecision__c===='+oldEvt.OrganizerDecision__c);

            if (
                newEvt.OrganizerApprovalRequired__c &&
                newEvt.OrganizerDecision__c == 'Approved' &&
                oldEvt.OrganizerDecision__c != 'Approved'
            ) {
                eventIds.add(evtId);
            }
        }

        if (eventIds.isEmpty()) return;

        Map<Id, String> statusByEventId = customEventSpeakerApprovalService.calculateEventStatusFromApprovals(eventIds);
        system.debug('triggerRollupFromEventBeforeUpdate===========statusByEventId===='+statusByEventId);

        // Apply status directly on trigger records
        for (Id evtId : statusByEventId.keySet()) {
            system.debug('triggerRollupFromEventBeforeUpdate===========newMap.containsKey(evtId)===='+newMap.containsKey(evtId));
            system.debug('triggerRollupFromEventBeforeUpdate===========newMap.containsKey(evtId)===='+newMap.containsKey(evtId));

            if (newMap.containsKey(evtId) && statusByEventId.get(evtId) != null) {
                newMap.get(evtId).Status__c = statusByEventId.get(evtId);
            }
        }
    }
}