// Service layer for EventSpeakerApprovals__c trigger processing
public with sharing class EventSpeakerApprovalsService {

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
        customEventNotificationService.notifySpeakerAssistantsOnCreate(newMap.values());
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
}