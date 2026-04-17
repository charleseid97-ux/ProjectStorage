// Trigger handler for EventSpeakerApprovals__c.
// Delegates all logic to the service layer.
public with sharing class EventSpeakerApprovalsTriggerHandler implements ITriggerHandler {

    // Allows disabling the handler (tests / maintenance)
    public static Boolean triggerDisabled = false;

    // Before insert: track initial status audit
    public void BeforeInsert(List<SObject> newItems) {
        List<EventSpeakerApprovals__c> approvalsToProcess = filterAutomatedApprovals(
            (List<EventSpeakerApprovals__c>) newItems
        );

        if (approvalsToProcess.isEmpty()) return;

        EventSpeakerApprovalsService.trackStatusUpdateOnInsert(approvalsToProcess);

        EventSpeakerApprovalsService.requireHOPApproval(approvalsToProcess);
    }

    // Before update: track status changes
    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, EventSpeakerApprovals__c> newMap = filterAutomatedApprovalsMap(
            (Map<Id, EventSpeakerApprovals__c>) newItems
        );
        Map<Id, EventSpeakerApprovals__c> oldMap = filterOldMap(
            (Map<Id, EventSpeakerApprovals__c>) oldItems,
            newMap.keySet()
        );

        if (newMap.isEmpty()) return;

        EventSpeakerApprovalsService.trackStatusUpdateOnUpdate(newMap, oldMap);
    }

    // After insert: handle rollup, approval submission and sharing
    public void AfterInsert(Map<Id, SObject> newItems) {
        Map<Id, EventSpeakerApprovals__c> newMap = filterAutomatedApprovalsMap(
            (Map<Id, EventSpeakerApprovals__c>) newItems
        );

        if (newMap.isEmpty()) return;

        EventSpeakerApprovalsService.manageRollupOnInsert(newMap);
        //EventSpeakerApprovalsService.manageNotificationOnInsert(newMap);
        EventSpeakerApprovalsService.submitForSpeakerApproval(newMap.values(), null);
        //EventSpeakerApprovalsSharingService.refreshEventSharingFromApprovals(newMap.values(), null);
    }

    // After update: handle rollup, approval submission and sharing
    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, EventSpeakerApprovals__c> newMap = filterAutomatedApprovalsMap(
            (Map<Id, EventSpeakerApprovals__c>) newItems
        );
        Map<Id, EventSpeakerApprovals__c> oldMap = filterOldMap(
            (Map<Id, EventSpeakerApprovals__c>) oldItems,
            newMap.keySet()
        );

        if (newMap.isEmpty()) return;

        EventSpeakerApprovalsService.submitForSpeakerApproval(newMap.values(), oldMap);
        EventSpeakerApprovalsService.manageRollupOnUpdate(newMap, oldMap);
       // EventSpeakerApprovalsSharingService.refreshEventSharingFromApprovals(newMap.values(), oldMap);
    }

    // No logic required before delete
    public void BeforeDelete(Map<Id, SObject> oldItems) { /* no-op */ }

    // After delete: refresh sharing from remaining approvals
    public void AfterDelete(Map<Id, SObject> oldItems) {
        /*EventSpeakerApprovalsSharingService.refreshEventSharingFromApprovals(
            null,
            (Map<Id, EventSpeakerApprovals__c>) oldItems
        );*/
    }

    // After undelete: restore sharing if needed
    public void AfterUndelete(Map<Id, SObject> oldItems) {
        Map<Id, EventSpeakerApprovals__c> restoredMap = filterAutomatedApprovalsMap(
            (Map<Id, EventSpeakerApprovals__c>) oldItems
        );

        if (restoredMap.isEmpty()) return;

        /*EventSpeakerApprovalsSharingService.refreshEventSharingFromApprovals(
            restoredMap.values(),
            null
        );*/
    }

    // Central enable/disable guard
    public Boolean isDisabled() {
        return EventSpeakerApprovalsService.isDisabled(triggerDisabled);
    }

    private static List<EventSpeakerApprovals__c> filterAutomatedApprovals(List<EventSpeakerApprovals__c> approvals) {
        List<EventSpeakerApprovals__c> result = new List<EventSpeakerApprovals__c>();
        if (approvals == null || approvals.isEmpty()) return result;

        Map<Id, Boolean> eventBypassMap = loadEventAutomationFlags(approvals);

        for (EventSpeakerApprovals__c approval : approvals) {
            if (approval == null || approval.Event__c == null) {
                result.add(approval);
                continue;
            }

            if (eventBypassMap.get(approval.Event__c) != true) {
                result.add(approval);
            }
        }
        return result;
    }

    private static Map<Id, EventSpeakerApprovals__c> filterAutomatedApprovalsMap(
        Map<Id, EventSpeakerApprovals__c> approvals
    ) {
        Map<Id, EventSpeakerApprovals__c> result = new Map<Id, EventSpeakerApprovals__c>();
        if (approvals == null || approvals.isEmpty()) return result;

        Map<Id, Boolean> eventBypassMap = loadEventAutomationFlags(approvals.values());

        for (Id approvalId : approvals.keySet()) {
            EventSpeakerApprovals__c approval = approvals.get(approvalId);

            if (approval == null || approval.Event__c == null) {
                result.put(approvalId, approval);
                continue;
            }

            if (eventBypassMap.get(approval.Event__c) != true) {
                result.put(approvalId, approval);
            }
        }
        return result;
    }

    private static Map<Id, EventSpeakerApprovals__c> filterOldMap(
        Map<Id, EventSpeakerApprovals__c> oldMap,
        Set<Id> idsToKeep
    ) {
        Map<Id, EventSpeakerApprovals__c> result = new Map<Id, EventSpeakerApprovals__c>();
        if (oldMap == null || oldMap.isEmpty() || idsToKeep == null || idsToKeep.isEmpty()) {
            return result;
        }

        for (Id approvalId : idsToKeep) {
            if (oldMap.containsKey(approvalId)) {
                result.put(approvalId, oldMap.get(approvalId));
            }
        }
        return result;
    }

    private static Map<Id, Boolean> loadEventAutomationFlags(List<EventSpeakerApprovals__c> approvals) {
        Map<Id, Boolean> result = new Map<Id, Boolean>();
        Set<Id> eventIds = new Set<Id>();

        for (EventSpeakerApprovals__c approval : approvals) {
            if (approval != null && approval.Event__c != null) {
                eventIds.add(approval.Event__c);
            }
        }

        if (eventIds.isEmpty()) return result;

        for (Event__c evt : [
            SELECT Id, noAutomations__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]) {
            result.put(evt.Id, evt.noAutomations__c);
        }

        return result;
    }
}