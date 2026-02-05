// Trigger handler for EventSpeakerApprovals__c.
// Delegates all logic to the service layer.
public with sharing class EventSpeakerApprovalsTriggerHandler implements ITriggerHandler {

    // Allows disabling the handler (tests / maintenance)
    public static Boolean triggerDisabled = false;

    // Before insert: track initial status audit
    public void BeforeInsert(List<SObject> newItems) {
        EventSpeakerApprovalsService.trackStatusUpdateOnInsert(
            (List<EventSpeakerApprovals__c>) newItems
        );
    }

    // Before update: track status changes
    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        EventSpeakerApprovalsService.trackStatusUpdateOnUpdate(
            (Map<Id, EventSpeakerApprovals__c>) newItems,
            (Map<Id, EventSpeakerApprovals__c>) oldItems
        );
    }

    // After insert: handle rollup and notifications
    public void AfterInsert(Map<Id, SObject> newItems) {
        Map<Id, EventSpeakerApprovals__c> newMap =
            (Map<Id, EventSpeakerApprovals__c>) newItems;

        EventSpeakerApprovalsService.manageRollupOnInsert(newMap);
        EventSpeakerApprovalsService.manageNotificationOnInsert(newMap);
    }

    // After update: handle rollup logic
    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        EventSpeakerApprovalsService.manageRollupOnUpdate(
            (Map<Id, EventSpeakerApprovals__c>) newItems,
            (Map<Id, EventSpeakerApprovals__c>) oldItems
        );
    }

    // No delete logic required
    public void BeforeDelete(Map<Id, SObject> oldItems) { /* no-op */ }
    public void AfterDelete(Map<Id, SObject> oldItems)  { /* no-op */ }
    public void AfterUndelete(Map<Id, SObject> oldItems){ /* no-op */ }

    // Central enable/disable guard
    public Boolean isDisabled() {
        return EventSpeakerApprovalsService.isDisabled(triggerDisabled);
    }
}