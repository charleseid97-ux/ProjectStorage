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
        rollupIfNeeded(newMap.values(), null);
    }

    // Handles parent event rollup after record update
    public static void manageRollupOnUpdate(
        Map<Id, EventSpeakerApprovals__c> newMap,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;
        rollupIfNeeded(newMap.values(), oldMap);
    }

    // Sends notification emails after record creation
    public static void manageNotificationOnInsert(Map<Id, EventSpeakerApprovals__c> newMap) {
        if (newMap == null || newMap.isEmpty()) return;

        Set<Id> eventIds = new Set<Id>();
        for (EventSpeakerApprovals__c esa : newMap.values()) {
            if (esa != null && esa.Event__c != null) {
                eventIds.add(esa.Event__c);
            }
        }
        if (eventIds.isEmpty()) return;

        // Pass correct parameters instead of null
        customEventNotificationService.sendApprovalEmails(
            eventIds,
            DEFAULT_QUEUE_DEV_NAME,
            DEFAULT_TEMPLATE_DEV_NAME
        );
    }

    public static void submitForSpeakerApproval(List<EventSpeakerApprovals__c> records, Map<Id, EventSpeakerApprovals__c> oldMap) {
        System.debug(LoggingLevel.DEBUG, '[EventSpeakerApprovalsService] submitForSpeakerApproval called with ' + records.size() + ' records');
        if (records == null || records.isEmpty()) return;

        Boolean isAfterInsert = (oldMap == null || oldMap.isEmpty());
        List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();

        for (EventSpeakerApprovals__c rec : records) {
            if (rec == null || rec.Id == null) continue;

            // AFTER INSERT logic
            if (isAfterInsert) {
                // If HOP approval required, send to HOP approval process
                if (rec.HopApprovalRequired__c == true) {
                    Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                    req.setObjectId(rec.Id);
                    req.setProcessDefinitionNameOrId(HOP_APPROVAL_PROCESS_DEVNAME);
                    req.setComments('Auto-submitted on creation (HOP required)');
                    requests.add(req);
                } else {
                    // Otherwise, submit to Speaker approval process
                    Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                    req.setObjectId(rec.Id);
                    req.setProcessDefinitionNameOrId(SPEAKER_APPROVAL_PROCESS_DEVNAME);
                    req.setComments('Auto-submitted on creation (HOP not required)');
                    requests.add(req);
                }
                continue;
            }

            // AFTER UPDATE logic: check for transition to 'approved_hop'
            EventSpeakerApprovals__c oldRec = oldMap.get(rec.Id);
            String oldStatus = (oldRec != null) ? oldRec.Status__c : null;
            String newStatus = rec.Status__c;

            // If status passed from any value (including null/blank) to 'approved_hop' -> submit to Speaker approval
            if ((oldStatus == null || oldStatus != 'approved_hop') 
                && newStatus == 'approved_hop') {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(rec.Id);
                req.setProcessDefinitionNameOrId(SPEAKER_APPROVAL_PROCESS_DEVNAME);
                req.setComments('Auto-submitted on status change to approved_hop');
                requests.add(req);
            }
        }

        if (requests.isEmpty()) return;

        try {
            Approval.process(requests);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '[EventSpeakerApprovalsService] submitForSpeakerApproval failed -> ' + ex.getMessage());
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

    // Updates parent event status when all speaker approvals are completed
    private static void rollupIfNeeded(
        List<EventSpeakerApprovals__c> newList,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) return;

        Set<Id> impactedEventIds =
            customEventSpeakerApprovalService.collectImpactedEventIds(newList, oldMap);

        if (impactedEventIds.isEmpty()) return;

        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(impactedEventIds);
    }

    //requireHOPAppval will check if we need to submit to HOP approval process and do it if necessary, and will check  HOPapprovalRequired__c field
    public static void requireHOPAppval (List<EventSpeakerApprovals__c> newList) {
        if (newList == null || newList.isEmpty()) return;
        for (EventSpeakerApprovals__c rec : newList) {
            if (rec.speaker__c == '0035800000rqKGpAAM') {
                rec.HopApprovalRequired__c = true;
            }   else {
                rec.HopApprovalRequired__c = false;
            }   
        }    
        
    }

}