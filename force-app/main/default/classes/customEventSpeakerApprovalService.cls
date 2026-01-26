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

        Set<Id> eventIdsToProcess = new Set<Id>();

        // Detect events created directly or transitioning to WaitingForSpeakerApprovals
        for (Event__c newEvt : newEvents.values()) {
            if (newEvt == null || newEvt.Id == null) continue;

            if (oldEvents == null) {
                if (newEvt.Status__c == 'WaitingForSpeakerApprovals') {
                    eventIdsToProcess.add(newEvt.Id);
                }
            } else {
                Event__c oldEvt = oldEvents.get(newEvt.Id);
                if (
                    newEvt.Status__c == 'WaitingForSpeakerApprovals' &&
                    (oldEvt == null || oldEvt.Status__c != 'WaitingForSpeakerApprovals')
                ) {
                    eventIdsToProcess.add(newEvt.Id);
                }
            }
        }

        if (eventIdsToProcess.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'ESA: no events entering WaitingForSpeakerApprovals');
            return;
        }

        // Recursion guard
        eventIdsToProcess.removeAll(PROCESSED_EVENT_IDS);
        if (eventIdsToProcess.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'ESA: events already processed in this transaction (recursion guard)');
            return;
        }
        PROCESSED_EVENT_IDS.addAll(eventIdsToProcess);

        System.debug(LoggingLevel.INFO, 'ESA: processing events ' + eventIdsToProcess);

        // Load all speaker-product lines linked to the events
        List<SessionSpeakerProduct__c> lines = [
            SELECT Session__c, SpeakerContact__c, Product__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIdsToProcess
            AND SpeakerContact__c != null
        ];
        if (lines.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ESA: no SessionSpeakerProduct__c found');
            return;
        }

        // Collect distinct speaker contacts
        Set<Id> speakerContactIds = new Set<Id>();
        for (SessionSpeakerProduct__c l : lines) {
            speakerContactIds.add(l.SpeakerContact__c);
        }

        // Load speakers and their assistants (assistant is a USER lookup) + assistant username
        Map<Id, Contact> speakerById = new Map<Id, Contact>([
            SELECT Id, SpeakerAssistant__c, SpeakerAssistant__r.Username
            FROM Contact
            WHERE Id IN :speakerContactIds
        ]);

        // Group product names by (Event, SpeakerContact)
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

        // Build approval records (upserted by unique Key__c)
        List<EventSpeakerApprovals__c> approvals = new List<EventSpeakerApprovals__c>();

        for (String key : productsByKey.keySet()) {
            Integer sep = key.indexOf('-');
            if (sep <= 0) continue;

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

            List<String> names = new List<String>(productsByKey.get(key));
            names.sort();

            approvals.add(new EventSpeakerApprovals__c(
                Key__c              = key,
                Event__c            = eventId,
                Speaker__c          = speakerId,
                ApproverUserName__c = approverUserName,
                Status__c           = 'Submitted',
                Summary__c          = String.join(names, ', ')
            ));

            System.debug(LoggingLevel.DEBUG,
                'ESA: prepared approval for event=' + eventId +
                ', speaker=' + speakerId +
                ', approverUserName=' + approverUserName
            );
        }

        if (!approvals.isEmpty()) {
            try {
                upsert approvals Key__c;
                System.debug(LoggingLevel.INFO, 'ESA: upserted approvals count=' + approvals.size());
            } catch (DmlException de) {
                System.debug(LoggingLevel.ERROR, 'ESA: DmlException on upsert approvals. message=' + de.getMessage());

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

                throw new SpeakerApprovalUpsertException(
                    'Upsert failed due to Flow fault (EventSpeakerApprovalFlow). ' +
                    'See debug logs for payload and Flow error ID. Original: ' + de.getMessage()
                );
            }
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
            if (rec.Event__c == null) continue;

            String oldStatus = (oldMap != null && oldMap.containsKey(rec.Id))
                ? oldMap.get(rec.Id).Status__c
                : null;

            if (rec.Status__c == 'Approved' && oldStatus != 'Approved') {
                eventIds.add(rec.Event__c);

                System.debug(LoggingLevel.INFO,
                    'ESA: speaker approval approved, event=' + rec.Event__c
                );
            }
        }

        return eventIds;
    }

    /**
     * Updates Event__c to EventFullyApproved if all speaker approvals are approved.
     */
    public static void updateEventStatusIfAllApproved(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        // Count total approvals per event
        Map<Id, Integer> totalByEvent = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c evt, COUNT(Id) cnt
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :eventIds
            GROUP BY Event__c
        ]) {
            totalByEvent.put((Id) ar.get('evt'), (Integer) ar.get('cnt'));
        }

        // Count approved approvals per event
        Map<Id, Integer> approvedByEvent = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c evt, COUNT(Id) cnt
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :eventIds
            AND Status__c = 'Approved'
            GROUP BY Event__c
        ]) {
            approvedByEvent.put((Id) ar.get('evt'), (Integer) ar.get('cnt'));
        }

        List<Event__c> toUpdate = new List<Event__c>();

        for (Id evtId : totalByEvent.keySet()) {
            Integer total = totalByEvent.get(evtId);
            Integer approved = approvedByEvent.get(evtId);

            if (total != null && total > 0 && total == approved) {
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
}