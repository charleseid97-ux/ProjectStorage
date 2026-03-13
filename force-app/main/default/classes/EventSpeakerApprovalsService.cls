// Service layer for EventSpeakerApprovals__c trigger processing
public with sharing class EventSpeakerApprovalsService {

    // Defaults used for ESA insert notifications (must match customEventNotificationService defaults)
    private static final String DEFAULT_QUEUE_DEV_NAME    = 'EventTeam';
    private static final String DEFAULT_TEMPLATE_DEV_NAME = 'EventTeamApproval';

    // Approval Process developer name to use for automatic submission
    private static final String SPEAKER_APPROVAL_PROCESS_DEVNAME = 'SpeakerApproval';
    private static final String HOP_APPROVAL_PROCESS_DEVNAME = 'SpeakerApprovalHOP';

    // Determines whether the trigger execution is allowed
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

    // Applies status audit fields on insert when Status__c is set
    public static void trackStatusUpdateOnInsert(List<EventSpeakerApprovals__c> newList) {
        if (newList == null || newList.isEmpty()) return;
        applyStatusAudit(newList, null);
    }

    // Applies status audit fields on update when Status__c changes
    public static void trackStatusUpdateOnUpdate(
        Map<Id, EventSpeakerApprovals__c> newMap,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;
        applyStatusAudit(newMap.values(), oldMap);
    }

    // Handles parent event rollup after record creation
    public static void manageRollupOnInsert(Map<Id, EventSpeakerApprovals__c> newMap) {
        if (newMap == null || newMap.isEmpty()) return;
        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(newMap.values());
    }

    // Handles parent event rollup after record update
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
     * Trigger entry point used for automatic approval submission.
     * The actual submission is delegated to a private reusable method.
     */
    public static void submitForSpeakerApproval(List<EventSpeakerApprovals__c> records, Map<Id, EventSpeakerApprovals__c> oldMap) {
        System.debug(LoggingLevel.DEBUG, '[EventSpeakerApprovalsService] submitForSpeakerApproval called with ' + (records == null ? 0 : records.size()) + ' records');
        if (records == null || records.isEmpty()) return;

        Boolean isAfterInsert = (oldMap == null || oldMap.isEmpty());

        for (EventSpeakerApprovals__c rec : records) {
            if (rec == null || rec.Id == null) continue;

            // AFTER INSERT logic
            if (isAfterInsert) {
                if (rec.HopApprovalRequired__c == true) {
                    submitApproval(
                        rec.Id,
                        HOP_APPROVAL_PROCESS_DEVNAME,
                        'Auto-submitted on creation (HOP required)'
                    );
                } else {
                    submitApproval(
                        rec.Id,
                        SPEAKER_APPROVAL_PROCESS_DEVNAME,
                        'Auto-submitted on creation (HOP not required)'
                    );
                }
                continue;
            }

            // AFTER UPDATE logic: check for transition to 'approved_hop'
            EventSpeakerApprovals__c oldRec = oldMap.get(rec.Id);
            String oldStatus = (oldRec != null) ? oldRec.Status__c : null;
            String newStatus = rec.Status__c;

            // If status passed from any value (including null/blank) to 'approved_hop' -> submit to Speaker approval
            if ((oldStatus == null || oldStatus != 'approved_hop') && newStatus == 'approved_hop') {
                submitApproval(
                    rec.Id,
                    SPEAKER_APPROVAL_PROCESS_DEVNAME,
                    'Auto-submitted on status change to approved_hop'
                );
            }
        }
    }

    /**
     * Manual recall/resubmit entry point called by the controller.
     * For a rejected item, the practical business need is to submit again
     * to the same process with a custom comment.
     */
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

                submitApproval(
                    eventSpeakerApprovalId,
                    processDeveloperName,
                    finalComment
                );
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

                submitApproval(
                    recallTargetId,
                    processDeveloperName,
                    finalComment
                );
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Recall approval failed: ' + ex.getMessage());
        }
    }

    /**
     * Reusable private method used by both trigger automation and manual recall/resubmit.
     */
    private static Approval.ProcessResult submitApproval(Id recordId, String processDeveloperName, String comments) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required for approval submission.');
        }
        if (String.isBlank(processDeveloperName)) {
            throw new AuraHandledException('Approval process developer name is required.');
        }

        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(recordId);
            req.setProcessDefinitionNameOrId(processDeveloperName);
            req.setComments(String.isBlank(comments) ? '' : comments);

            Approval.ProcessResult result = Approval.process(req);

            if (result == null || !result.isSuccess()) {
                String combined;
                try {
                    combined = JSON.serialize(result != null ? result.getErrors() : null);
                } catch (Exception exJson) {
                    combined = 'Unknown approval submission error';
                }
                throw new AuraHandledException('Approval submission failed: ' + combined);
            }

            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '[EventSpeakerApprovalsService] submitApproval failed -> ' + ex.getMessage());
            throw new AuraHandledException('Approval submission failed: ' + ex.getMessage());
        }
    }

    // Sets audit fields when the status is created or modified
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

    // Checks whether HOP approval is required and updates the flag on the record
    public static void requireHOPApproval(List<EventSpeakerApprovals__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // Collect Speaker Ids
        Set<Id> speakerIds = new Set<Id>();
        for (EventSpeakerApprovals__c rec : newList) {
            if (rec.Speaker__c != null) {
                speakerIds.add(rec.Speaker__c);
            }
        }

        // Query speakers with isTopSpeaker
        Map<Id, Contact> speakerMap = new Map<Id, Contact>(
            [SELECT Id, isTopSpeaker__c FROM Contact WHERE Id IN :speakerIds]
        );

        // Apply logic
        for (EventSpeakerApprovals__c rec : newList) {
            if (rec.Speaker__c != null && 
                speakerMap.containsKey(rec.Speaker__c) && 
                speakerMap.get(rec.Speaker__c).isTopSpeaker__c) {
                    
                rec.HopApprovalRequired__c = true;
            } else {
                rec.HopApprovalRequired__c = false;
            }
        }
    }
}