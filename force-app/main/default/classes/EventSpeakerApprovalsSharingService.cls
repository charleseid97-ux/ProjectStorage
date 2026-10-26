public without sharing class EventSpeakerApprovalsSharingService {

    private static final String SHARE_ROW_CAUSE = 'AppexShare_approval__c';
    private static final String SHARE_ACCESS_LEVEL = 'Read';

    // Prevent multiple recalculations on same events in one transaction
    private static Set<Id> PROCESSED_EVENT_IDS = new Set<Id>();

    public static Boolean serviceDisabled = false;

    public static Boolean isDisabled(Boolean localFlag) {
        return EventSpeakerApprovalsService.isDisabled(localFlag || serviceDisabled);
    }

    /**
     * Recalculates Event__c sharing based on current approvals.
     */
    public static void OLD_refreshEventSharingFromApprovals(
        List<EventSpeakerApprovals__c> newList,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (isDisabled(false)) return;

        Set<Id> eventIds = collectImpactedEventIds(newList, oldMap);
        if (eventIds.isEmpty()) return;

        eventIds.removeAll(PROCESSED_EVENT_IDS);
        if (eventIds.isEmpty()) return;
        PROCESSED_EVENT_IDS.addAll(eventIds);

        Map<Id, Set<Id>> expectedApproversByEvent = loadExpectedApproversByEvent(eventIds);
        Map<Id, Map<Id, Event__Share>> existingSharesByEvent = loadExistingManagedShares(eventIds);

        syncShares(eventIds, expectedApproversByEvent, existingSharesByEvent);
    }

    // Collect impacted parent events from trigger context
    private static Set<Id> collectImpactedEventIds(
        List<EventSpeakerApprovals__c> newList,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        Set<Id> eventIds = new Set<Id>();

        if (newList != null) {
            for (EventSpeakerApprovals__c rec : newList) {
                if (rec != null && rec.Event__c != null) {
                    eventIds.add(rec.Event__c);
                }
            }
        }

        if (oldMap != null) {
            for (EventSpeakerApprovals__c rec : oldMap.values()) {
                if (rec != null && rec.Event__c != null) {
                    eventIds.add(rec.Event__c);
                }
            }
        }

        return eventIds;
    }

    // Build final approver set per event from persisted approvals
    private static Map<Id, Set<Id>> loadExpectedApproversByEvent(Set<Id> eventIds) {
        Map<Id, Set<Id>> out = new Map<Id, Set<Id>>();

        for (EventSpeakerApprovals__c approval : [
            SELECT Event__c, ApproverUser__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :eventIds
            AND ApproverUser__c != null
        ]) {
            if (!out.containsKey(approval.Event__c)) {
                out.put(approval.Event__c, new Set<Id>());
            }
            out.get(approval.Event__c).add(approval.ApproverUser__c);
        }

        return out;
    }

    // Load only shares managed by this service
    private static Map<Id, Map<Id, Event__Share>> loadExistingManagedShares(Set<Id> eventIds) {
        Map<Id, Map<Id, Event__Share>> out = new Map<Id, Map<Id, Event__Share>>();

        for (Event__Share shareRec : [
            SELECT Id, ParentId, UserOrGroupId
            FROM Event__Share
            WHERE ParentId IN :eventIds
            AND RowCause = :SHARE_ROW_CAUSE
        ]) {
            if (!out.containsKey(shareRec.ParentId)) {
                out.put(shareRec.ParentId, new Map<Id, Event__Share>());
            }
            out.get(shareRec.ParentId).put(shareRec.UserOrGroupId, shareRec);
        }

        return out;
    }

    /**
     * Applies the delta between expected approvers and existing Apex shares.
     */
    private static void syncShares(
        Set<Id> eventIds,
        Map<Id, Set<Id>> expectedApproversByEvent,
        Map<Id, Map<Id, Event__Share>> existingSharesByEvent
    ) {
        List<Event__Share> toInsert = new List<Event__Share>();
        List<Event__Share> toDelete = new List<Event__Share>();

        for (Id eventId : eventIds) {
            Set<Id> expectedUsers = expectedApproversByEvent.containsKey(eventId)
                ? expectedApproversByEvent.get(eventId)
                : new Set<Id>();

            Map<Id, Event__Share> existingByUser = existingSharesByEvent.containsKey(eventId)
                ? existingSharesByEvent.get(eventId)
                : new Map<Id, Event__Share>();

            for (Id userId : expectedUsers) {
                if (!existingByUser.containsKey(userId)) {
                    toInsert.add(new Event__Share(
                        ParentId = eventId,
                        UserOrGroupId = userId,
                        AccessLevel = SHARE_ACCESS_LEVEL,
                        RowCause = SHARE_ROW_CAUSE
                    ));
                }
            }

            for (Id userId : existingByUser.keySet()) {
                if (!expectedUsers.contains(userId)) {
                    toDelete.add(existingByUser.get(userId));
                }
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }
}