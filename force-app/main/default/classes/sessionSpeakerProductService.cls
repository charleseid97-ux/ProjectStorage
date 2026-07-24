public without sharing class sessionSpeakerProductService {
    private static final String WAITING_STATUS = customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS;
    private static final String SUBMITTED_STATUS = 'Submitted';
    private static final String PRES_REQUESTED_STATUS = 'requested';
    private static final String PRES_REQUIRED_STATUS = 'required';

    public class SspApprovalSyncException extends Exception {}

    /**
     * Recalcul complet des approvals pour un Event, basé sur l'état FINAL en base.
     * - Ne fait rien si l'Event n'est pas en WaitingForSpeakerApprovals
     * - Crée les approvals manquantes (Event, Speaker)
     * - Supprime les approvals devenues orphelines (plus aucun SSP pour ce speaker)
     * - Ne supprime pas les approvals "Approved" (conforme au comportement existant)
     */
    public static void recalcApprovals(Id eventId) {
        if (eventId == null) return;
        if (!isWaitingEvent(eventId)) return;

        RecalcData data = buildRecalcData(eventId);

        insertMissingApprovals(eventId, data);

        deleteOrphanApprovals(eventId, data.desiredKeys);

        System.debug(LoggingLevel.INFO, '[SSP Sync] Recalc completed eventId=' + eventId);
    }

    // -----------------------
    // Data build (source of truth = DB)
    // -----------------------

    private class RecalcData {
        Set<String> desiredKeys = new Set<String>();               // eventId-speakerId
        Map<String, Set<String>> productsByKey = new Map<String, Set<String>>();
        Set<Id> speakerIds = new Set<Id>();
    }

    public static void updateSSPName(
        List<SessionSpeakerProduct__c> newSsps,
        Map<Id, SessionSpeakerProduct__c> oldSsps
    ) {
        List<SessionSpeakerProduct__c> records = new List<SessionSpeakerProduct__c>();

        if (newSsps != null) records.addAll(newSsps);
        else if (oldSsps != null) records.addAll(oldSsps.values());

        if (records.isEmpty()) return;

        Set<Id> strategyIds = new Set<Id>();
        Set<Id> speakerIds  = new Set<Id>();
        Set<Id> sessionIds  = new Set<Id>();

        for (SessionSpeakerProduct__c s : records) {
            if (s.Strategy__c != null) strategyIds.add(s.Strategy__c);
            if (s.SpeakerContact__c != null) speakerIds.add(s.SpeakerContact__c);
            if (s.Session__c != null) sessionIds.add(s.Session__c);
        }

        Map<Id, Strategy__c> strategies = new Map<Id, Strategy__c>([
            SELECT Id, Name, AssetClass__c
            FROM Strategy__c
            WHERE Id IN :strategyIds
        ]);

        Map<Id, Contact> speakers = new Map<Id, Contact>([
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id IN :speakerIds
        ]);

        Map<Id, Event__c> sessions = new Map<Id, Event__c>([
            SELECT Id, RecordType.Name
            FROM Event__c
            WHERE Id IN :sessionIds
        ]);

        for (SessionSpeakerProduct__c s : records) {

            Strategy__c strat = strategies.get(s.Strategy__c);
            Contact c         = speakers.get(s.SpeakerContact__c);
            Event__c ev       = sessions.get(s.Session__c);

            String rangePart    = strat != null ? strat.AssetClass__c : null;
            String strategyPart = strat != null ? strat.Name : null;

            String speakerPart;
            if (c != null && !String.isBlank(c.FirstName) && !String.isBlank(c.LastName)) {
                speakerPart = (c.FirstName.substring(0,1) + c.LastName.substring(0,1)).toUpperCase();
            }

            String requestTypePart = ev != null ? ev.RecordType.Name : null;
            String languagePart    = s.Language__c;

            s.Name = String.join(
                new List<String>{
                    rangePart,
                    strategyPart,
                    speakerPart,
                    requestTypePart,
                    languagePart
                },
                ' – '
            );
        }
    }

    private static RecalcData buildRecalcData(Id eventId) {
        RecalcData d = new RecalcData();

        List<SessionSpeakerProduct__c> lines = [
            SELECT Session__c, SpeakerContact__c, strategy__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c = :eventId
            AND SpeakerContact__c != null
            LIMIT 5000
        ];

        for (SessionSpeakerProduct__c l : lines) {
            if (l == null || l.SpeakerContact__c == null) continue;

            String key = buildKey(eventId, l.SpeakerContact__c);
            d.desiredKeys.add(key);
            d.speakerIds.add(l.SpeakerContact__c);

            if (!d.productsByKey.containsKey(key)) {
                d.productsByKey.put(key, new Set<String>());
            }
            if (l.strategy__r != null && String.isNotBlank(l.strategy__r.Name)) {
                d.productsByKey.get(key).add(l.strategy__r.Name);
            }
        }

        System.debug(LoggingLevel.INFO,
            '[SSP Sync] Recalc data: desiredKeys=' + d.desiredKeys.size() + ', speakers=' + d.speakerIds.size()
        );
        return d;
    }

    // -----------------------
    // Inserts
    // -----------------------

    private static void insertMissingApprovals(Id eventId, RecalcData data) {
        if (data == null || data.desiredKeys.isEmpty()) return;

        Map<String, EventSpeakerApprovals__c> existingByKey = loadApprovalsByKey(eventId);

        Set<String> missingKeys = new Set<String>(data.desiredKeys);
        missingKeys.removeAll(existingByKey.keySet());
        if (missingKeys.isEmpty()) return;

        Map<Id, Contact> speakerById = loadSpeakers(data.speakerIds);

        List<EventSpeakerApprovals__c> toInsert = new List<EventSpeakerApprovals__c>();

        for (String key : missingKeys) {
            Id speakerId = speakerIdFromKey(key);
            if (speakerId == null) continue;

            Id approverUserId = getApproverUserId(speakerById, speakerId, key);

            String summary = buildSummary(data.productsByKey.get(key));

            toInsert.add(new EventSpeakerApprovals__c(
                Key__c          = key,
                Event__c        = eventId,
                Speaker__c      = speakerId,
                ApproverUser__c = approverUserId,
                Status__c       = SUBMITTED_STATUS,
                Summary__c      = summary
            ));
        }

        if (toInsert.isEmpty()) return;

        System.debug(LoggingLevel.INFO, '[SSP Sync] Recalc inserting approvals=' + toInsert.size());
        insert toInsert;
    }

    private static Id getApproverUserId(Map<Id, Contact> speakerById, Id speakerId, String key) {
        Contact c = (speakerById != null) ? speakerById.get(speakerId) : null;

        // Non top speaker => pas besoin d'assistant
        if (c != null && c.IsTopSpeaker__c == false) {
            return null;
        }

        Id approverUserId = (c != null) ? c.SpeakerAssistant__c : null;

        if (approverUserId == null) {
            System.debug(LoggingLevel.ERROR,
                '[SSP Sync] Missing approver (SpeakerAssistant__c) for speaker=' + speakerId + ' key=' + key
            );
            throw new SspApprovalSyncException('Missing SpeakerAssistant__c for speaker ' + speakerId);
        }

        return approverUserId;
    }
    private static String buildSummary(Set<String> productNames) {
        if (productNames == null || productNames.isEmpty()) return null;

        List<String> names = new List<String>();
        names.addAll(productNames);
        names.sort();
        return String.join(names, ', ');
    }

    // -----------------------
    // Deletes
    // -----------------------

    private static void deleteOrphanApprovals(Id eventId, Set<String> desiredKeys) {
        Map<String, EventSpeakerApprovals__c> existingByKey = loadApprovalsByKey(eventId);
        if (existingByKey.isEmpty()) return;

        Set<String> keysToDelete = new Set<String>(existingByKey.keySet());
        if (desiredKeys != null) keysToDelete.removeAll(desiredKeys);

        if (keysToDelete.isEmpty()) return;

        List<EventSpeakerApprovals__c> toDelete = new List<EventSpeakerApprovals__c>();
        for (String key : keysToDelete) {
            EventSpeakerApprovals__c a = existingByKey.get(key);
            if (a == null) continue;

            if (isApproved(a)) {
                System.debug(LoggingLevel.WARN, '[SSP Sync] Recalc skipping delete Approved key=' + key);
                continue;
            }
            toDelete.add(a);
        }

        if (toDelete.isEmpty()) return;

        System.debug(LoggingLevel.INFO, '[SSP Sync] Recalc deleting approvals=' + toDelete.size());
        delete toDelete;
    }

    private static Boolean isApproved(EventSpeakerApprovals__c a) {
        return a != null
            && a.Status__c != null
            && String.valueOf(a.Status__c).equalsIgnoreCase('Approved');
    }

    // -----------------------
    // Queries
    // -----------------------

    private static Boolean isWaitingEvent(Id eventId) {
        Event__c e = [
            SELECT Id, Status__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        Boolean waiting = (e.Status__c == WAITING_STATUS);

        System.debug(LoggingLevel.INFO,
            '[SSP Sync] Recalc event status=' + e.Status__c + ' waiting=' + waiting + ' eventId=' + eventId
        );
        return waiting;
    }

    private static Map<String, EventSpeakerApprovals__c> loadApprovalsByKey(Id eventId) {
        Map<String, EventSpeakerApprovals__c> out = new Map<String, EventSpeakerApprovals__c>();

        for (EventSpeakerApprovals__c a : [
            SELECT Id, Key__c, Status__c, Speaker__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :eventId
        ]) {
            if (a.Key__c != null) out.put(a.Key__c, a);
        }

        return out;
    }

    private static Map<Id, Contact> loadSpeakers(Set<Id> speakerIds) {
        if (speakerIds == null || speakerIds.isEmpty()) return new Map<Id, Contact>();

        return new Map<Id, Contact>([
            SELECT Id, SpeakerAssistant__c
            FROM Contact
            WHERE Id IN :speakerIds
        ]);
    }

    // -----------------------
    // Key helpers
    // -----------------------

    private static String buildKey(Id eventId, Id speakerId) {
        return String.valueOf(eventId) + '-' + String.valueOf(speakerId);
    }

    private static Id speakerIdFromKey(String key) {
        if (String.isBlank(key)) return null;

        List<String> parts = key.split('-');
        if (parts == null || parts.size() != 2) return null;

        return (Id) parts[1];
    }


    public static void setPresentationStatusForTopSpeakers(List<SessionSpeakerProduct__c> ssps) {
        if (ssps == null || ssps.isEmpty()) {
            return;
        }

        Set<Id> speakerIds = new Set<Id>();
        Set<Id> sessionIds = new Set<Id>();

        for (SessionSpeakerProduct__c ssp : ssps) {
            if (ssp == null) continue;

            if (ssp.SpeakerContact__c != null) {
                speakerIds.add(ssp.SpeakerContact__c);
            }
            if (ssp.Session__c != null) {
                sessionIds.add(ssp.Session__c);
            }
        }

        if (speakerIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> speakersById = new Map<Id, Contact>([
            SELECT Id, IsTopSpeaker__c,SpeakerAssistant__c
            FROM Contact
            WHERE Id IN :speakerIds
        ]);

        Map<Id, Event__c> sessionsById = new Map<Id, Event__c>();
        if (!sessionIds.isEmpty()) {
            sessionsById = new Map<Id, Event__c>([
                SELECT Id, RecordTypeId
                FROM Event__c
                WHERE Id IN :sessionIds
            ]);
        }

        Id meetingDaysRtId = Schema.SObjectType.Event__c
            .getRecordTypeInfosByDeveloperName()
            .get('MeetingDays')
            .getRecordTypeId();

        for (SessionSpeakerProduct__c ssp : ssps) {
            if (ssp == null || ssp.SpeakerContact__c == null) {
                continue;
            }

            Contact speaker = speakersById.get(ssp.SpeakerContact__c);
            Event__c session = sessionsById.get(ssp.Session__c);

            Boolean isTopSpeaker = speaker != null && speaker.IsTopSpeaker__c == true;
            //Boolean isMeetingDays = session != null && session.RecordTypeId == meetingDaysRtId;

            if (isTopSpeaker){// && !isMeetingDays) {
                ssp.PresentationStatus__c = PRES_REQUIRED_STATUS;
            }
        }
    }

    public static void handleRequestedPresentationNotifications(
        Map<Id, SessionSpeakerProduct__c> newMap,
        Map<Id, SessionSpeakerProduct__c> oldMap
    ) {
        system.debug('==============handleRequestedPresentationNotifications=======');
        if (newMap == null || newMap.isEmpty()) {
            return;
        }

        List<SessionSpeakerProduct__c> toNotify = new List<SessionSpeakerProduct__c>();

        for (SessionSpeakerProduct__c newRec : newMap.values()) {

            if (newRec.PresentationStatus__c != PRES_REQUIRED_STATUS) {
                continue;
            }

            // Insert case
            if (oldMap == null) {
                toNotify.add(newRec);
                continue;
            }

            SessionSpeakerProduct__c oldRec = oldMap.get(newRec.Id);

            if (oldRec == null || oldRec.PresentationStatus__c != PRES_REQUIRED_STATUS) {
                toNotify.add(newRec);
            }
        }
        system.debug('==============handleRequestedPresentationNotifications======toNotify='+toNotify);

        if (!toNotify.isEmpty()) {
            customEventNotificationManager.requestPresentation(toNotify);
        }
    }

    public static void requestRequiredPresentationsForWaitingEvents(Map<Id, Event__c> newEvents,Map<Id, Event__c> oldEvents) {
        if (newEvents == null || newEvents.isEmpty()) {
            return;
        }

        Set<Id> eventIdsToProcess = new Set<Id>();

        for (Id eventId : newEvents.keySet()) {
            Event__c newEvent = newEvents.get(eventId);
            Event__c oldEvent = oldEvents != null ? oldEvents.get(eventId) : null;

            if (newEvent == null) {
                continue;
            }

            // On garde seulement les events qui viennent de passer
            // au statut WAITING_FOR_SPEAKER_APPROVALS
            if (
                newEvent.Status__c == customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS &&
                oldEvent != null &&
                oldEvent.Status__c != customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS
            ) {
                eventIdsToProcess.add(eventId);
            }
        }

        if (eventIdsToProcess.isEmpty()) {
            return;
        }

        List<SessionSpeakerProduct__c> sspsToUpdate = [
            SELECT Id, PresentationStatus__c
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIdsToProcess
            AND PresentationStatus__c = :PRES_REQUIRED_STATUS
            LIMIT 5000
        ];

        if (sspsToUpdate.isEmpty()) {
            return;
        }

        for (SessionSpeakerProduct__c ssp : sspsToUpdate) {
            ssp.PresentationStatus__c = PRES_REQUESTED_STATUS;
        }

        update sspsToUpdate;
    }

    public static void updateEventNamesFromSSP(List<SessionSpeakerProduct__c> ssps) {
        if (ssps == null || ssps.isEmpty()) return;

        Set<Id> eventIds = new Set<Id>();
        for (SessionSpeakerProduct__c s : ssps) {
            if (s.Session__c != null) eventIds.add(s.Session__c);
        }

        if (eventIds.isEmpty()) return;

        List<Event__c> events = [
            SELECT Id, Name, startDate__c, SalesTeam__c, Title__c
            FROM Event__c
            WHERE Id IN :eventIds
        ];

    if (events.isEmpty()) return;

    List<SessionSpeakerProduct__c> speakers = [
        SELECT Session__c, SpeakerContact__c,
            SpeakerContact__r.Name, SpeakerContact__r.Account.Name,
            Language__c, speakerLanguage__c, PresentationStatus__c, Date__c,
            startTime__c, endTime__c,
            strategy__c, strategy__r.Name
        FROM SessionSpeakerProduct__c
        WHERE Session__c IN :eventIds
        AND SpeakerContact__c != null
        ORDER BY Session__c, SpeakerContact__c
    ];

    Map<Id, List<SessionSpeakerProduct__c>> eventToSpeakers = new Map<Id, List<SessionSpeakerProduct__c>>();
    for (SessionSpeakerProduct__c speaker : speakers) {
        if (!eventToSpeakers.containsKey(speaker.Session__c)) {
            eventToSpeakers.put(speaker.Session__c, new List<SessionSpeakerProduct__c>());
        }

        eventToSpeakers.get(speaker.Session__c).add(speaker);
    }

        Map<Id, String> oldNames = new Map<Id, String>();
        for (Event__c e : events) {
            oldNames.put(e.Id, e.Name);
        }

        customEventService.setEventName(events, false);

        List<Event__c> toUpdate = new List<Event__c>();
        for (Event__c e : events) {
            if (oldNames.get(e.Id) != e.Name) {
                toUpdate.add(e);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR,
                    'ERROR updating Event names from SSP - ' +
                    'EventIds=' + eventIds +
                    ' | toUpdate=' + toUpdate +
                    ' | Message=' + ex.getMessage() +
                    ' | Stack=' + ex.getStackTraceString()
                );
            }
        }
    }

    public static void updateStatus(
        List<SessionSpeakerProduct__c> newSsps,
        Map<Id, SessionSpeakerProduct__c> oldSsps
    ) {
        if (newSsps == null || newSsps.isEmpty()) return;

        Set<Id> sessionIds = new Set<Id>();
        for (SessionSpeakerProduct__c s : newSsps) {
            if (s.Session__c != null) {
                sessionIds.add(s.Session__c);
            }
        }

        if (sessionIds.isEmpty()) return;

        Map<Id, Event__c> sessions = new Map<Id, Event__c>([
            SELECT Id, ParentEvent__r.Status__c
            FROM Event__c
            WHERE Id IN :sessionIds
        ]);

        for (SessionSpeakerProduct__c s : newSsps) {
            if (s.Session__c == null) continue;

            Event__c session = sessions.get(s.Session__c);
            if (
                session == null ||
                session.ParentEvent__r == null ||
                session.ParentEvent__r.Status__c != 'FullyApproved'
            ) {
                continue;
            }

            // Évite override inutile en update
            if (oldSsps != null && oldSsps.containsKey(s.Id)) {
                SessionSpeakerProduct__c oldRec = oldSsps.get(s.Id);
                if (oldRec.presentationStatus__c == 'requested') {
                    continue;
                }
            }

            // Set seulement si différent
            if (s.presentationStatus__c != 'requested') {
                s.presentationStatus__c = 'requested';
            }
        }
    }
}