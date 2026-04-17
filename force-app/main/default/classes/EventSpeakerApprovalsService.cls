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

    public static void manageRollupOnInsert(Map<Id, EventSpeakerApprovals__c> newMap) {
        if (newMap == null || newMap.isEmpty()) return;
        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(newMap.values());
    }

    public static void manageRollupOnUpdate(
        Map<Id, EventSpeakerApprovals__c> newMap,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;

        List<EventSpeakerApprovals__c> statusChangedRecords = new List<EventSpeakerApprovals__c>();

        for (Id recordId : newMap.keySet()) {
            EventSpeakerApprovals__c newRec = newMap.get(recordId);
            EventSpeakerApprovals__c oldRec = oldMap.get(recordId);

            if (newRec.Status__c != oldRec.Status__c) {
                statusChangedRecords.add(newRec);
            }
        }

        if (!statusChangedRecords.isEmpty()) {
            customEventSpeakerApprovalService.updateEventStatusIfAllApproved(statusChangedRecords);
        }
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
     * ⚠️ Optionnel: plus nécessaire avec approvalType__c
     */
    public static void requireHOPApproval(List<EventSpeakerApprovals__c> newList) {
        // deprecated logic (can be removed if unused)
    }
}