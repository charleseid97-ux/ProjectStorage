public with sharing class EventSpeakerApprovalsTriggerHandler implements ITriggerHandler {

    // Toggle to disable the handler in tests or maintenance
    public static Boolean triggerDisabled = false;

    /* =========================
       BEFORE INSERT
       ========================= */
    public void BeforeInsert(List<SObject> newItems) {
        // Convert to typed list
        List<EventSpeakerApprovals__c> newList = (List<EventSpeakerApprovals__c>) newItems;
        // Apply audit fields on insert
        applyStatusAudit(newList, null);
    }

    /* =========================
       BEFORE UPDATE
       ========================= */
    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // Convert maps to typed maps
        Map<Id, EventSpeakerApprovals__c> newMap = (Map<Id, EventSpeakerApprovals__c>) newItems;
        Map<Id, EventSpeakerApprovals__c> oldMap = (Map<Id, EventSpeakerApprovals__c>) oldItems;
        // Apply audit fields when status changes
        applyStatusAudit(newMap.values(), oldMap);
    }

    /* =========================
       AFTER INSERT
       ========================= */
    public void AfterInsert(Map<Id, SObject> newItems) {
        Map<Id, EventSpeakerApprovals__c> newMap = (Map<Id, EventSpeakerApprovals__c>) newItems;
        // Trigger rollup for cases where a child is created already Approved
        rollupIfNeeded(newMap.values(), null);
    }

    /* =========================
       AFTER UPDATE
       ========================= */
    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, EventSpeakerApprovals__c> newMap = (Map<Id, EventSpeakerApprovals__c>) newItems;
        Map<Id, EventSpeakerApprovals__c> oldMap = (Map<Id, EventSpeakerApprovals__c>) oldItems;
        // Trigger rollup when status transitions to Approved
        rollupIfNeeded(newMap.values(), oldMap);
    }

    /* =========================
       DELETE / UNDELETE (no-op)
       ========================= */
    public void BeforeDelete(Map<Id, SObject> oldItems) { /* no-op */ }
    public void AfterDelete(Map<Id, SObject> oldItems) { /* no-op */ }
    public void AfterUndelete(Map<Id, SObject> oldItems) { /* no-op */ }

    /* =========================
       ENABLED CHECK
       ========================= */
    public Boolean isDisabled() {
        if (Type.forName('PAD') != null) {
            // Use PAD guard if available; otherwise default to triggerDisabled
            try {
                return PAD.canTrigger('EventSpeakerApprovalsTriggerHandler') ? triggerDisabled : true;
            } catch (Exception e) {
                return triggerDisabled;
            }
        } else {
            return triggerDisabled;
        }
    }

    /* ======================================================
       Internal helpers
       ====================================================== */

    // Stamp status change audit fields before DML
    private static void applyStatusAudit(List<EventSpeakerApprovals__c> newList, Map<Id, EventSpeakerApprovals__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        for (EventSpeakerApprovals__c rec : newList) {
            String oldStatus = (oldMap == null || !oldMap.containsKey(rec.Id)) ? null : oldMap.get(rec.Id).Status__c;
            Boolean statusChanged = (oldMap == null) ? String.isNotBlank(rec.Status__c) : (rec.Status__c != oldStatus);

            if (statusChanged) {
                rec.StatusChangeDate__c = System.now();
                rec.StatusChangedBy__c = UserInfo.getUserId();

                // Log with record info; rec.Id may be null on insert
                if (rec.Id != null) {
                    System.debug(LoggingLevel.INFO, 'ESA audit: set status for ' + rec.Id + ' -> ' + rec.Status__c);
                } else {
                    System.debug(LoggingLevel.INFO, 'ESA audit: new record (event=' + rec.Event__c + ', speaker=' + rec.Speaker__c + ') -> ' + rec.Status__c);
                }
            }
        }
    }

    // Determine impacted events and call service to update parent status
    private static void rollupIfNeeded(List<EventSpeakerApprovals__c> newList, Map<Id, EventSpeakerApprovals__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        Set<Id> impactedEventIds = customEventSpeakerApprovalService.collectImpactedEventIds(newList, oldMap);
        if (impactedEventIds.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'ESA rollup: no impacted events');
            return;
        }

        System.debug(LoggingLevel.INFO, 'ESA rollup: impacted events = ' + impactedEventIds);
        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(impactedEventIds);
    }
}