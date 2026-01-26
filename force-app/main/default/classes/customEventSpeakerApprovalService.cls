public with sharing class customEventSpeakerApprovalService {

    // Prevent processing the same Event multiple times in the same transaction (Flow/automation recursion)
    private static Set<Id> PROCESSED_EVENT_IDS = new Set<Id>();

    // Custom exception to rethrow with a clearer message (do not instantiate DmlException directly)
    public class SpeakerApprovalUpsertException extends Exception {}

    /**
     * Creates or updates one EventSpeakerApprovals__c per (Event, SpeakerContact)
     * when an Event enters WaitingForSpeakerApprovals.
     */
    public static void createOrUpdateSpeakerApprovals(
        Map<Id, Event__c> newEvents,
        Map<Id, Event__c> oldEvents
    ) {
        if (newEvents == null || newEvents.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'ESA: no events provided');
            return;
        }

        Set<Id> eventIdsToProcess = collectEventIdsToProcess(newEvents, oldEvents);
        if (eventIdsToProcess.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'ESA: no events entering WaitingForSpeakerApprovals');
            return;
        }

        // Recursion guard
        if (!applyRecursionGuard(eventIdsToProcess)) {
            System.debug(LoggingLevel.DEBUG, 'ESA: events already processed in this transaction (recursion guard)');
            return;
        }

        System.debug(LoggingLevel.INFO, 'ESA: processing events ' + eventIdsToProcess);

        // Load all speaker-product lines linked to the events
        List<SessionSpeakerProduct__c> lines = querySpeakerProductLines(eventIdsToProcess);
        if (lines.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ESA: no SessionSpeakerProduct__c found');
            return;
        }

        // Collect distinct speaker contacts
        Set<Id> speakerContactIds = collectSpeakerContactIds(lines);

        // Load speakers and their assistants (assistant is a USER lookup) + assistant username
        Map<Id, Contact> speakerById = loadSpeakers(speakerContactIds);

        // Group product names by (Event, SpeakerContact)
        Map<String, Set<String>> productsByKey = groupProductsByKey(lines);

        // Build approval records (upserted by unique Key__c)
        List<EventSpeakerApprovals__c> approvals = buildApprovals(productsByKey, speakerById);

        upsertApprovals(approvals);
    }

    private static Set<Id> collectEventIdsToProcess(Map<Id, Event__c> newEvents, Map<Id, Event__c> oldEvents) {
        Set<Id> eventIdsToProcess = new Set<Id>();

        // Detect events created directly or transitioning to WaitingForSpeakerApprovals
        for (Event__c newEvt : newEvents.values()) {
            if (isEnteringWaitingForSpeakerApprovals(newEvt, oldEvents)) {
                eventIdsToProcess.add(newEvt.Id);
            }
        }

        return eventIdsToProcess;
    }

    // Detect events created directly or transitioning to WaitingForSpeakerApprovals
    private static Boolean isEnteringWaitingForSpeakerApprovals(Event__c newEvt, Map<Id, Event__c> oldEvents) {
        if (newEvt == null || newEvt.Id == null) return false;
        if (newEvt.Status__c != 'WaitingForSpeakerApprovals') return false;

        if (oldEvents == null) return true;

        Event__c oldEvt = oldEvents.get(newEvt.Id);
        return (oldEvt == null || oldEvt.Status__c != 'WaitingForSpeakerApprovals');
    }

    // Recursion guard
    private static Boolean applyRecursionGuard(Set<Id> eventIdsToProcess) {
        eventIdsToProcess.removeAll(PROCESSED_EVENT_IDS);
        if (eventIdsToProcess.isEmpty()) return false;
        PROCESSED_EVENT_IDS.addAll(eventIdsToProcess);
        return true;
    }

    // Load all speaker-product lines linked to the events
    private static List<SessionSpeakerProduct__c> querySpeakerProductLines(Set<Id> eventIdsToProcess) {
        return [
            SELECT Session__c, SpeakerContact__c, Product__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIdsToProcess
            AND SpeakerContact__c != null
        ];
    }

    // Collect distinct speaker contacts
    private static Set<Id> collectSpeakerContactIds(List<SessionSpeakerProduct__c> lines) {
        Set<Id> speakerContactIds = new Set<Id>();
        for (SessionSpeakerProduct__c l : lines) {
            speakerContactIds.add(l.SpeakerContact__c);
        }
        return speakerContactIds;
    }

    // Load speakers and their assistants (assistant is a USER lookup) + assistant username
    private static Map<Id, Contact> loadSpeakers(Set<Id> speakerContactIds) {
        return new Map<Id, Contact>([
            SELECT Id, SpeakerAssistant__c, SpeakerAssistant__r.Username
            FROM Contact
            WHERE Id IN :speakerContactIds
        ]);
    }

    // Group product names by (Event, SpeakerContact)
    private static Map<String, Set<String>> groupProductsByKey(List<SessionSpeakerProduct__c> lines) {
        Map<String, Set<String>> productsByKey = new Map<String, Set<String>>();

        for (SessionSpeakerProduct__c l : lines) {
            String key = l.Session__c + '-' + l.SpeakerContact__c;
            if (!productsByKey.containsKey(key)) {
                productsByKey.put(key, new Set<String>());
            }
            if (l.Product__r != null && String.isNotBlank(l.Product__r.Name)) {
                productsByKey.get(key).add(l.Product__r.Name);
            }
        }

        return productsByKey;
    }

    // Build approval records (upserted by unique Key__c)
    private static List<EventSpeakerApprovals__c> buildApprovals(
        Map<String, Set<String>> productsByKey,
        Map<Id, Contact> speakerById
    ) {
        List<EventSpeakerApprovals__c> approvals = new List<EventSpeakerApprovals__c>();

        for (String key : productsByKey.keySet()) {
            ApprovalBuildResult built = buildApproval(key, productsByKey.get(key), speakerById);
            if (built == null) continue;

            approvals.add(built.record);

            System.debug(LoggingLevel.DEBUG,
                'ESA: prepared approval for event=' + built.eventId +
                ', speaker=' + built.speakerId +
                ', approverUserName=' + built.approverUserName
            );
        }

        return approvals;
    }

    private class ApprovalBuildResult {
        Id eventId;
        Id speakerId;
        String approverUserName;
        EventSpeakerApprovals__c record;
    }

    private static ApprovalBuildResult buildApproval(
        String key,
        Set<String> productNames,
        Map<Id, Contact> speakerById
    ) {
        Integer sep = key.indexOf('-');
        if (sep <= 0) return null;

        Id eventId = (Id) key.substring(0, sep);
        Id speakerId = (Id) key.substring(sep + 1);

        Contact speaker = speakerById.get(speakerId);

        // Approver username must come from speaker's assistant username
        String approverUserName = (speaker != null && speaker.SpeakerAssistant__c != null)
            ? speaker.SpeakerAssistant__r.Username
            : null;

        // Safety: abort if missing approver username
        if (String.isBlank(approverUserName)) {
            System.debug(LoggingLevel.ERROR,
                '=====record aborted due to missing approver' +
                ' | event=' + eventId +
                ' | speaker=' + speakerId +
                ' | assistantUserId=' + (speaker != null ? speaker.SpeakerAssistant__c : null) +
                ' | key=' + key
            );
            throw new SpeakerApprovalUpsertException(
                '=====record aborted due to missing approver'
            );
        }

        List<String> names = (productNames == null) ? new List<String>() : new List<String>(productNames);
        names.sort();

        EventSpeakerApprovals__c rec = new EventSpeakerApprovals__c(
            Key__c              = key,
            Event__c            = eventId,
            Speaker__c          = speakerId,
            ApproverUserName__c = approverUserName,
            Status__c           = 'Submitted',
            Summary__c          = String.join(names, ', ')
        );

        ApprovalBuildResult out = new ApprovalBuildResult();
        out.eventId = eventId;
        out.speakerId = speakerId;
        out.approverUserName = approverUserName;
        out.record = rec;
        return out;
    }

    private static void upsertApprovals(List<EventSpeakerApprovals__c> approvals) {
        if (approvals.isEmpty()) return;

        try {
            upsert approvals Key__c;
            System.debug(LoggingLevel.INFO, 'ESA: upserted approvals count=' + approvals.size());
        } catch (DmlException de) {
            System.debug(LoggingLevel.ERROR, 'ESA: DmlException on upsert approvals. message=' + de.getMessage());

            logUpsertPayload(approvals);

            throw new SpeakerApprovalUpsertException(
                'Upsert failed due to Flow fault (EventSpeakerApprovalFlow). ' +
                'See debug logs for payload and Flow error ID. Original: ' + de.getMessage()
            );
        }
    }

    private static void logUpsertPayload(List<EventSpeakerApprovals__c> approvals) {
        try {
            System.debug(LoggingLevel.ERROR, 'ESA: upsert payload size=' + approvals.size());
            for (Integer i = 0; i < approvals.size() && i < 50; i++) {
                EventSpeakerApprovals__c a = approvals[i];
                System.debug(LoggingLevel.ERROR,
                    '  payload[' + i + ']: Id=' + a.Id +
                    ', Key__c=' + a.Key__c +
                    ', Event__c=' + a.Event__c +
                    ', Speaker__c=' + a.Speaker__c +
                    ', ApproverUserName__c=' + a.ApproverUserName__c +
                    ', Status__c=' + a.Status__c
                );
            }
        } catch (Exception px) {
            System.debug(LoggingLevel.ERROR, 'ESA: failed to log payload details: ' + px.getMessage());
        }
    }

    /* =========================================================
       ROLLUP AFTER SPEAKER APPROVAL
       ========================================================= */

    /**
     * Collects Event Ids impacted by a speaker approval moving to Approved.
     */
    public static Set<Id> collectImpactedEventIds(
        List<EventSpeakerApprovals__c> newList,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        Set<Id> eventIds = new Set<Id>();
        if (newList == null) return eventIds;

        for (EventSpeakerApprovals__c rec : newList) {
            if (isApprovalTransitioningToApproved(rec, oldMap)) {
                eventIds.add(rec.Event__c);

                System.debug(LoggingLevel.INFO,
                    'ESA: speaker approval approved, event=' + rec.Event__c
                );
            }
        }

        return eventIds;
    }

    private static Boolean isApprovalTransitioningToApproved(
        EventSpeakerApprovals__c rec,
        Map<Id, EventSpeakerApprovals__c> oldMap
    ) {
        if (rec == null || rec.Event__c == null) return false;

        String oldStatus = (oldMap != null && oldMap.containsKey(rec.Id))
            ? oldMap.get(rec.Id).Status__c
            : null;

        return (rec.Status__c == 'Approved' && oldStatus != 'Approved');
    }

    /**
     * Updates Event__c to EventFullyApproved if all speaker approvals are approved.
     */
    public static void updateEventStatusIfAllApproved(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        // Count total approvals per event
        Map<Id, Integer> totalByEvent = queryApprovalCounts(eventIds, false);

        // Count approved approvals per event
        Map<Id, Integer> approvedByEvent = queryApprovalCounts(eventIds, true);

        List<Event__c> toUpdate = new List<Event__c>();

        for (Id evtId : totalByEvent.keySet()) {
            Integer total = totalByEvent.get(evtId);
            Integer approved = approvedByEvent.get(evtId);

            if (shouldMarkFullyApproved(total, approved)) {
                toUpdate.add(new Event__c(
                    Id = evtId,
                    Status__c = 'EventFullyApproved'
                ));

                System.debug(LoggingLevel.INFO,
                    'ESA: event fully approved, event=' + evtId
                );
            } else {
                System.debug(LoggingLevel.DEBUG,
                    'ESA: event not fully approved, event=' + evtId +
                    ', approved=' + approved + ', total=' + total
                );
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug(LoggingLevel.INFO,
                'ESA: updated events count=' + toUpdate.size()
            );
        }
    }

    // Count total approvals per event
    // Count approved approvals per event
    private static Map<Id, Integer> queryApprovalCounts(Set<Id> eventIds, Boolean onlyApproved) {
        String base =
            'SELECT Event__c evt, COUNT(Id) cnt ' +
            'FROM EventSpeakerApprovals__c ' +
            'WHERE Event__c IN :eventIds ';
        if (onlyApproved) {
            base += 'AND Status__c = \'Approved\' ';
        }
        base += 'GROUP BY Event__c';

        Map<Id, Integer> out = new Map<Id, Integer>();
        for (AggregateResult ar : Database.query(base)) {
            out.put((Id) ar.get('evt'), (Integer) ar.get('cnt'));
        }
        return out;
    }

    private static Boolean shouldMarkFullyApproved(Integer total, Integer approved) {
        if (total == null || total <= 0) return false;
        if (approved == null) approved = 0;
        return total == approved;
    }
}
