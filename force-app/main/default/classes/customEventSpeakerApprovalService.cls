public without sharing class customEventSpeakerApprovalService {

    // Prevent processing the same Event multiple times in the same transaction (Flow/automation recursion)
    private static Set<Id> PROCESSED_HTML_EVENT_IDS = new Set<Id>();
    private static Set<Id> PROCESSED_APPROVAL_EVENT_IDS = new Set<Id>();
    private static Set<Id> PROCESSED_MARK_FULLY_APPROVED_EVENT_IDS = new Set<Id>();
    private static final String TD_STYLE = 'style="padding:6px 0;border-bottom:1px solid #f3f4f6;"';
    // Custom exception to rethrow with a clearer message (do not instantiate DmlException directly)
    public class SpeakerApprovalUpsertException extends Exception {}

    private static Boolean applyRecursionGuard(Set<Id> ids, Set<Id> processed) {
        ids.removeAll(processed);
        if (ids.isEmpty()) return false;
        processed.addAll(ids);
        return true;
    }
    
    /**
     * Compact : génère SpeakersHTML__c pour les events entrants en WaitingForSpeakerApprovals.
     * Appel prévu depuis before update -> pas de DML ici.
     */
    public static void prepareSpeakerHTMLforNotifications(Map<Id, Event__c> newEvents,Map<Id, Event__c> oldEvents) {
        System.debug(LoggingLevel.INFO, '==+=======prepareSpeakerHTMLforNotifications: start processing 1');
        if (newEvents == null || newEvents.isEmpty()) return;

        Set<Id> eventIds = collectEventIdsForEmptyHtmlOnUpdate(newEvents, oldEvents);
        if (eventIds.isEmpty()) return;
        System.debug(LoggingLevel.INFO, '==+=======prepareSpeakerHTMLforNotifications: start processing 2');

        if (!applyRecursionGuard(eventIds, PROCESSED_HTML_EVENT_IDS)) return;
        System.debug(LoggingLevel.INFO, '==+=======prepareSpeakerHTMLforNotifications: start processing 3');

        List<SessionSpeakerProduct__c> ssp = [
            SELECT Session__c, SpeakerContact__c,
                SpeakerContact__r.Name, SpeakerContact__r.Account.Name,
                Language__c, PresentationStatus__c,startTime__c,endTime__c,
                strategy__c, strategy__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
            ORDER BY Session__c, SpeakerContact__c
        ];

        Map<Id, List<SessionSpeakerProduct__c>> eventToSpeakers = new Map<Id, List<SessionSpeakerProduct__c>>();
        for (SessionSpeakerProduct__c s : ssp) {
            system.debug('=prepareSpeakerHTMLforNotifications===s=='+s);
            system.debug('=prepareSpeakerHTMLforNotifications===s.strategy__c=='+s.strategy__c);
            if (s == null || s.Session__c == null) continue;
            if (!eventToSpeakers.containsKey(s.Session__c)) {
                eventToSpeakers.put(s.Session__c, new List<SessionSpeakerProduct__c>());
            }
            eventToSpeakers.get(s.Session__c).add(s);
        }

        for (Id evtId : eventIds) {
            Event__c e = newEvents.get(evtId);
            if (e == null) continue;

            e.SpeakersHTML__c = buildSpeakersHtmlSingleSection('Speakers',eventToSpeakers.get(evtId));
            e.Speakers__c = buildSpeakersText(eventToSpeakers.get(evtId));
        }
    }

      // petit util minimal d'échappement (prévenir HTML break)
    private static String esc(String v) {
        if (v == null) return '';
        return v.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;').replace('\'','&#39;');
    }
    // Construit le format texte des speakers avec leurs produits.
    public static String buildSpeakersText(List<SessionSpeakerProduct__c> speakers) {
        List<SpeakerHtmlRow> groupedRows = groupSpeakersForHtml(speakers);
        List<String> speakerTexts = new List<String>();

        // Une entrée texte par speaker groupé.
        for (SpeakerHtmlRow row : groupedRows) {
            List<String> productNames = new List<String>();
            productNames.addAll(row.products);
            productNames.sort();

            // Format final : speaker (strategy1,strategy2)
            speakerTexts.add(
                row.speakerName + ' (' + String.join(productNames, ',') + ')'
            );
        }

        return String.join(speakerTexts, ', ');
    }
   /**
     * Vérifie les events qui viennent d'entrer en WaitingForSpeakerApprovals.
     * Si aucun SessionSpeakerProduct__c n'est lié à l'event, force le statut
     * de l'Event__c à customEventConstants.STATUS_FULLY_APPROVED.
     *
     * Conçu pour être appelé depuis un trigger BEFORE UPDATE : on modifie directement
     * les enregistrements dans la map newEvents (pas de DML).
     */
    public static void markEventFullyApprovedIfNoSSP(
        Map<Id, Event__c> newEvents,
        Map<Id, Event__c> oldEvents
    ) {
        System.debug(LoggingLevel.INFO, '======markEventFullyApprovedIfNoSSP: start processing');
        if (newEvents == null || newEvents.isEmpty()) return;

        // 1) Déterminer les events concernés (entrants en WaitingForSpeakerApprovals)
        Set<Id> eventIds = collectEventIdsToProcess(newEvents, oldEvents);

        for (Event__c newEvt : newEvents.values()) {
            if (isOrganizerDecisionApproved(newEvt, oldEvents)) {
                eventIds.add(newEvt.Id);
            }
        }
        if (eventIds.isEmpty()) return;

        // 2) Recursion guard (évite double traitement dans la même transaction)
        if (!applyRecursionGuard(eventIds, PROCESSED_MARK_FULLY_APPROVED_EVENT_IDS)) {
            System.debug(LoggingLevel.DEBUG, 'markEventFullyApprovedIfNoSSP: events already processed in this tx');
            return;
        }

        System.debug(LoggingLevel.INFO, 'markEventFullyApprovedIfNoSSP: checking events ' + eventIds);

        // 3) Charger les lignes SSP pour ces events
        List<SessionSpeakerProduct__c> lines = querySpeakerProductLines(eventIds);

        // 4) Construire un set d'events ayant au moins une SSP
        Set<Id> eventsWithSSP = new Set<Id>();
        if (lines != null && !lines.isEmpty()) {
            for (SessionSpeakerProduct__c l : lines) {
                if (l != null && l.Session__c != null) eventsWithSSP.add(l.Session__c);
            }
        }

        // 5) Pour chaque event entrant, si absence de SSP -> modifier la map newEvents
        for (Id evtId : eventIds) {
            if (!eventsWithSSP.contains(evtId)) {
                Event__c newEvt = newEvents.get(evtId);
                if (newEvt == null) continue;

                // Do not bypass organizer approval when it is required.
                if (
                    newEvt.OrganizerApprovalRequired__c == true &&
                    newEvt.OrganizerDecision__c != 'Approved'
                ) {
                    System.debug(LoggingLevel.INFO,
                        'markEventFullyApprovedIfNoSSP: organizer approval required, keep WaitingForSpeakerApprovals event=' + evtId
                    );
                    continue;
                }
                

                String currentStatus = newEvt.Status__c;
                if (currentStatus == null || !currentStatus.equalsIgnoreCase(customEventConstants.STATUS_FULLY_APPROVED)) {
                    // Modification directe dans la map pour BEFORE trigger (pas de DML)
                    newEvt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;
                    System.debug(LoggingLevel.INFO, 'markEventFullyApprovedIfNoSSP: set Status__c to FullyApproved for event=' + evtId);
                } else {
                    System.debug(LoggingLevel.DEBUG, 'markEventFullyApprovedIfNoSSP: already FullyApproved, event=' + evtId);
                }
            } else {
                System.debug(LoggingLevel.DEBUG, 'markEventFullyApprovedIfNoSSP: SSP found, event=' + evtId);
            }
        }

        // Pas de persist ici : les changements sur newEvents seront sauvegardés par le trigger BEFORE
        System.debug(LoggingLevel.INFO, 'markEventFullyApprovedIfNoSSP: processing finished');
    }
    /**
     * Creates or updates one EventSpeakerApprovals__c per (Event, SpeakerContact)
     * when an Event enters WaitingForSpeakerApprovals for first time.
     * from Draft,SubmittedToEventTeam to SubmittedToEventTeam
     */
    public static void createOrUpdateSpeakerApprovals(
        Map<Id, Event__c> newEvents,
        Map<Id, Event__c> oldEvents
    ) {
        System.debug(LoggingLevel.INFO, 'ESA: createOrUpdateSpeakerApprovals start processing');
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
        if (!applyRecursionGuard(eventIdsToProcess, PROCESSED_APPROVAL_EVENT_IDS)) {
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

        // Load speakers and their assistants (assistant is a USER lookup)
        Map<Id, Contact> speakerById = loadSpeakers(speakerContactIds);

        // Group product names by (Event, SpeakerContact)
        GroupResult gr = groupProductsByKey(lines);
        List<EventSpeakerApprovals__c> approvals = buildApprovals(
            gr.productsByKey,
            speakerById,
            gr.bestSSPByKey
        );
        deleteOrphanApprovals(eventIdsToProcess, speakerContactIds);

        upsertApprovals(approvals);
    }

    // -------------------------
    // Helper & query methods
    // -------------------------

    private static Set<Id> collectEventIdsToProcess(Map<Id, Event__c> newEvents, Map<Id, Event__c> oldEvents) {
        Set<Id> eventIdsToProcess = new Set<Id>();

        // Detect events created directly or transitioning to WaitingForSpeakerApprovals
        for (Event__c newEvt : newEvents.values()) {
            system.debug(LoggingLevel.DEBUG, '===Checking event for processing, eventId=' + newEvt.Id + ', status=' + newEvt.Status__c);
            if (isEnteringWaitingForSpeakerApprovals(newEvt, oldEvents)) {
                system.debug(LoggingLevel.INFO, '===Event entering WaitingForSpeakerApprovals detected, eventId=' + newEvt.Id);
                eventIdsToProcess.add(newEvt.Id);
            }
        }

        return eventIdsToProcess;
    }

    // Detect events created directly or transitioning to WaitingForSpeakerApprovals 
    // from Draft or SubmittedToEventTeam
    private static Boolean isEnteringWaitingForSpeakerApprovals(Event__c newEvt, Map<Id, Event__c> oldEvents) {

        if (newEvt == null) return false;
        if (newEvt.Status__c != customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS) return false;

        // Insert case
        if (oldEvents == null) return true;

        Event__c oldEvt = oldEvents.get(newEvt.Id);

        if (oldEvt == null) return true;
        system.debug(LoggingLevel.DEBUG, '===Old event status=' + oldEvt.Status__c);
        return oldEvt.Status__c == customEventConstants.STATUS_DRAFT
            || oldEvt.Status__c == customEventConstants.STATUS_REJECTED
            || oldEvt.Status__c == customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM;
    }

 

    // Load all speaker-product lines linked to the events
    private static List<SessionSpeakerProduct__c> querySpeakerProductLines(Set<Id> eventIdsToProcess) {
        List<SessionSpeakerProduct__c> lines = [
            SELECT Session__c, SpeakerContact__c,
                    strategy__r.Name, strategy__r.AssetClass__c,
                    Session__r.RecordType.Name,
                    Language__c,presentationStatus__c,
                    startTime__c, endTime__c
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIdsToProcess
            AND SpeakerContact__c != null
        ];
        return  lines;
    }

    // Collect distinct speaker contacts
    private static Set<Id> collectSpeakerContactIds(List<SessionSpeakerProduct__c> lines) {
        Set<Id> speakerContactIds = new Set<Id>();
        if (lines == null) return speakerContactIds;
        for (SessionSpeakerProduct__c l : lines) {
            if (l != null && l.SpeakerContact__c != null) speakerContactIds.add(l.SpeakerContact__c);
        }
        return speakerContactIds;
    }

    // Load speakers and their assistants (assistant is a USER lookup)
    private static Map<Id, Contact> loadSpeakers(Set<Id> speakerContactIds) {
        if (speakerContactIds == null || speakerContactIds.isEmpty()) return new Map<Id, Contact>();
        List<Contact> speakers = [
            SELECT Id, Name, SpeakerAssistant__c, isTopSpeaker__c            
            FROM Contact
            WHERE Id IN :speakerContactIds
        ];
        return new Map<Id, Contact>(speakers);
    }

    // Group product names by (Event, SpeakerContact)
    private static GroupResult groupProductsByKey(List<SessionSpeakerProduct__c> lines) {
        GroupResult res = new GroupResult();
        res.productsByKey = new Map<String, Set<String>>();
        res.maxDurationByKey = new Map<String, Integer>();
        res.bestSSPByKey = new Map<String, SessionSpeakerProduct__c>();

        for (SessionSpeakerProduct__c l : lines) {
            if (l == null || l.Session__c == null || l.SpeakerContact__c == null) continue;

            String key = String.valueOf(l.Session__c) + '-' + String.valueOf(l.SpeakerContact__c);

            Integer duration = 0;
            if (l.startTime__c != null && l.endTime__c != null) {
                duration =
                    ((l.endTime__c.hour() * 60) + l.endTime__c.minute())
                    - ((l.startTime__c.hour() * 60) + l.startTime__c.minute());
            }

            if (!res.maxDurationByKey.containsKey(key) || duration > res.maxDurationByKey.get(key)) {
                res.maxDurationByKey.put(key, duration);
                res.bestSSPByKey.put(key, l);
            }

            if (!res.productsByKey.containsKey(key)) {
                res.productsByKey.put(key, new Set<String>());
            }

            if (l.strategy__r != null && String.isNotBlank(l.strategy__r.Name)) {
                res.productsByKey.get(key).add(l.strategy__r.Name);
            }
        }

        return res;
    }
    /**
     * Builds speaker initials like A.ELH from Contact Name.
     */
    private static String buildSpeakerInitials(String fullName) {
        if (String.isBlank(fullName)) return 'UNK';

        List<String> parts = fullName.trim().split(' ');
        if (parts.isEmpty()) return 'UNK';

        String firstInitial = parts[0].substring(0,1).toUpperCase();

        String lastPart = parts.size() > 1 ? parts[parts.size()-1] : parts[0];
        String last = lastPart.length() >= 3 ? lastPart.substring(0,3) : lastPart;

        return firstInitial + '.' + last.toUpperCase();
    }
    // Build approval records (upserted by unique Key__c)
    private static List<EventSpeakerApprovals__c> buildApprovals(
        Map<String, Set<String>> productsByKey,
        Map<Id, Contact> speakerById,
        Map<String, SessionSpeakerProduct__c> bestSSPByKey
    ) {
        List<EventSpeakerApprovals__c> approvals = new List<EventSpeakerApprovals__c>();
        if (productsByKey == null || productsByKey.isEmpty()) return approvals;

        for (String baseKey : productsByKey.keySet()) {
            Integer sep = baseKey.indexOf('-');
            Id eventId = (Id) baseKey.substring(0, sep);
            Id speakerId = (Id) baseKey.substring(sep + 1);

            Contact speaker = (speakerById == null) ? null : speakerById.get(speakerId);
            Boolean isTop = speaker != null && speaker.isTopSpeaker__c;
            Boolean hasAssistant = speaker != null && speaker.SpeakerAssistant__c != null;

            Set<String> productNames = productsByKey.get(baseKey);

            if (isTop) {
                // HOP toujours créé normalement
                EventSpeakerApprovals__c hopApproval = buildApproval(
                    eventId,
                    speakerId,
                    'HOP',
                    productNames,
                    speakerById,
                    bestSSPByKey
                );
                if (hopApproval != null) approvals.add(hopApproval);

                // Speaker approval normal si assistant, sinon auto
                EventSpeakerApprovals__c speakerApproval = buildApproval(
                    eventId,
                    speakerId,
                    hasAssistant ? 'Speaker' : 'SpeakerAuto',
                    productNames,
                    speakerById,
                    bestSSPByKey
                );
                if (speakerApproval != null) approvals.add(speakerApproval);

            } else {
                EventSpeakerApprovals__c autoApproval = buildApproval(
                    eventId,
                    speakerId,
                    'Auto',
                    productNames,
                    speakerById,
                    bestSSPByKey
                );
                if (autoApproval != null) approvals.add(autoApproval);
            }
        }

        return approvals;
    }
    

    private static EventSpeakerApprovals__c buildApproval(
        Id eventId,
        Id speakerId,
        String approvalType,
        Set<String> productNames,
        Map<Id, Contact> speakerById,
        Map<String, SessionSpeakerProduct__c> bestSSPByKey
    ) {
        if (eventId == null || speakerId == null || String.isBlank(approvalType)) return null;

        Contact speaker = (speakerById == null) ? null : speakerById.get(speakerId);

        Boolean isAutoApproval =
            approvalType == 'Auto' ||
            approvalType == 'SpeakerAuto';

        Id approverUserId = null;

        // Speaker approval manuel uniquement si assistant présent
        if (approvalType == 'Speaker') {
            approverUserId = (speaker != null) ? speaker.SpeakerAssistant__c : null;

            if (approverUserId == null) {
                System.debug(LoggingLevel.WARN,
                    'Speaker approval switched to auto because assistant is missing' +
                    ' | event=' + eventId +
                    ' | speaker=' + speakerId
                );
                approvalType = 'SpeakerAuto';
                isAutoApproval = true;
            }
        }

        // HOP : soumis à une queue, donc pas d'approver user obligatoire ici
        if (approvalType == 'HOP') {
            approverUserId = null;
        }

        List<String> names = (productNames == null) ? new List<String>() : new List<String>(productNames);
        names.sort();

        String baseKey = String.valueOf(eventId) + '-' + String.valueOf(speakerId);
        String fullKey = baseKey + '-' + approvalType;

        SessionSpeakerProduct__c best = bestSSPByKey.get(baseKey);
        String speakerInitials = (speaker != null) ? buildSpeakerInitials(speaker.Name) : 'UNK';

        String nameValue =
            (best != null && best.strategy__r != null ? best.strategy__r.AssetClass__c : '') + ' - ' +
            (best != null && best.strategy__r != null ? best.strategy__r.Name : '') + ' - ' +
            speakerInitials + ' - ' +
            (best != null && best.Session__r != null ? best.Session__r.RecordType.Name : '') + ' - ' +
            (best != null ? best.Language__c : '');

        if (nameValue.length() > 80) {
            nameValue = nameValue.substring(0, 80);
        }

        EventSpeakerApprovals__c rec = new EventSpeakerApprovals__c(
            Name            = nameValue,
            Key__c          = fullKey,
            Event__c        = eventId,
            Speaker__c      = speakerId,
            approvalType__c = approvalType,
            ApproverUser__c = isAutoApproval ? null : approverUserId,
            Status__c       = isAutoApproval
                ? 'AutoApproved'
                : customEventConstants.APPROVAL_STATUS_SUBMITTED,
            Summary__c      = String.join(names, ', ')
        );

        if (best != null) {
            rec.start__c = best.startTime__c;
            rec.end__c = best.endTime__c;
        }

        return rec;
    }

   /**
     * Supprime les EventSpeakerApprovals__c orphelines :
     * - pour les events donnés
     * - si le Speaker__c n'est plus présent dans les SSP de l'event
     *
     * NB : les approvals déjà "Approved" ne sont jamais supprimées.
     */
    private static void deleteOrphanApprovals(
        Set<Id> eventIds,
        Set<Id> speakerContactIds
    ) {
        if (eventIds == null || eventIds.isEmpty()) return;

        List<EventSpeakerApprovals__c> toDelete = new List<EventSpeakerApprovals__c>();

        for (EventSpeakerApprovals__c ex : [
            SELECT Id, Speaker__c, Status__c,Event__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :eventIds
        ]) {
            if (ex.Speaker__c != null && speakerContactIds != null && speakerContactIds.contains(ex.Speaker__c)) {
                continue;
            }

            // Ne jamais supprimer une approval déjà approuvée.
            if (
                isTerminalApprovalStatus(ex.Status__c)
            ) {
                continue;
            }
            system.debug(LoggingLevel.INFO, 'ESA: marking approval for deletion, event=' + ex.Event__c + ', speaker=' + ex.Speaker__c + ', status=' + ex.Status__c);
            toDelete.add(ex);
        }

        if (toDelete.isEmpty()) return;
        system.debug(LoggingLevel.INFO, 'ESA: deleting orphan approvals count=' + toDelete.size());
        delete toDelete;
    }

    private static void upsertApprovals(List<EventSpeakerApprovals__c> approvals) {
        if (approvals == null || approvals.isEmpty()) return;

        // 1) Collect Keys to check existing records
        Set<String> keys = new Set<String>();
        for (EventSpeakerApprovals__c a : approvals) {
            if (a.Key__c != null) keys.add(a.Key__c);
        }

        // 2) Query existing approvals by Key__c (only what's necessary)
        Map<String, EventSpeakerApprovals__c> existingByKey = new Map<String, EventSpeakerApprovals__c>();
        if (!keys.isEmpty()) {
            for (EventSpeakerApprovals__c ex :  [
                SELECT Id, Key__c, Status__c
                FROM EventSpeakerApprovals__c
                WHERE Key__c IN :keys
            ]) {
                existingByKey.put(ex.Key__c, ex);
            }
        }

        // 3) Build list to upsert: skip only if existing.Status__c == 'Approved'
        List<EventSpeakerApprovals__c> toUpsert = new List<EventSpeakerApprovals__c>();
        Integer skipped = 0;
        Integer queued = 0;

        for (EventSpeakerApprovals__c a : approvals) {
            if (a.Key__c == null) {
                // Safety: skip entries without Key__c (shouldn't happen normally)
                System.debug(LoggingLevel.WARN, 'ESA: skipping approval without Key__c, Event=' + a.Event__c + ', Speaker=' + a.Speaker__c);
                continue;
            }

            EventSpeakerApprovals__c existing = existingByKey.get(a.Key__c);
            if (
                existing != null &&
                (
                    isTerminalApprovalStatus(existing.Status__c)
                )
            ) {
                // terminal approved -> do not upsert
                skipped++;
                continue;
            }

            // New or existing non-approved -> keep status from builder and queue for upsert
            toUpsert.add(a);
            queued++;
        }

        System.debug(LoggingLevel.INFO, 'ESA: approvals total=' + approvals.size() + ', queued=' + queued + ', skippedApproved=' + skipped);

        if (toUpsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ESA: nothing to upsert after filtering approved records');
            return;
        }

        try {
            List<EventSpeakerApprovals__c> sanitizedToUpsert = toUpsert;
            upsert sanitizedToUpsert Key__c;            
            System.debug(LoggingLevel.INFO, 'ESA: upserted approvals count=' + toUpsert.size());
        } catch (DmlException de) {
            System.debug(LoggingLevel.ERROR, 'ESA: DmlException on upsert approvals. message=' + de.getMessage());
            logUpsertPayload(toUpsert);
            throw new SpeakerApprovalUpsertException(
                'Upsert failed due to Flow fault (EventSpeakerApprovalFlow). ' +
                'See debug logs for payload and Flow error ID. Original: ' + de.getMessage()
            );
        }
    }
    // Vérifie si une approval est dans un statut final à ne jamais écraser.
    private static Boolean isTerminalApprovalStatus(String status) {
        if (String.isBlank(status)) return false;

        return status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED)
            || status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED_SPEAKER)
            || status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED_HOP)
            || status.equalsIgnoreCase('AutoApproved');
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
                    ', ApproverUser__c=' + a.ApproverUser__c +
                    ', Status__c=' + a.Status__c
                );
            }
        } catch (Exception px) {
            System.debug(LoggingLevel.ERROR, 'ESA: failed to log payload details: ' + px.getMessage());
        }
    }

    
   
    /**
     * Updates Event__c to FullyApproved / Rejected / PartiallyApproved
     * if all speaker approvals are processed.
     * If at least one approval is Recalled, the Event goes back to WaitingForSpeakerApprovals.
     */
    public static void updateEventStatusIfAllApproved(List<EventSpeakerApprovals__c> approvals) {
        Set<Id> eventIds = new Set<Id>();
        for (EventSpeakerApprovals__c a : approvals) {
            if (a != null && a.Event__c != null) {
                eventIds.add(a.Event__c);
            }
        }

        System.debug(LoggingLevel.INFO, 'ESA: updateEventStatusIfAllApproved for events ' + eventIds);
        if (eventIds.isEmpty()) return;

        Map<Id, Map<String, Integer>> countsByEventAndStatus = queryApprovalCounts(eventIds);

        List<Event__c> toUpdate = new List<Event__c>();

        for (Id evtId : countsByEventAndStatus.keySet()) {
            Map<String, Integer> statusCounts = countsByEventAndStatus.get(evtId);

            Integer total = 0;
            Integer approved = 0;
            Integer rejected = 0;
            Integer recalled = 0;

            if (statusCounts != null) {
                for (String status : statusCounts.keySet()) {
                    Integer countValue = statusCounts.get(status);
                    if (countValue == null) continue;

                    if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED_SPEAKER)) {
                        approved += countValue;
                        total += countValue;
                    } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_REJECTED)) {
                        rejected += countValue;
                        total += countValue;
                                        } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_SUBMITTED)) {
                        total += countValue;
                    } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_RECALLED)) {
                        recalled += countValue;
                    } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED_HOP)) {
                        approved += countValue;
                        total += countValue;
                    } else if (status != null && status.equalsIgnoreCase('AutoApproved')) {
                        approved += countValue;
                        total += countValue;
                    }
                }
            }

            String newStatus;
            if (recalled > 0) {
                newStatus = customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS;
            } else {
                newStatus = shouldMarkFullyApproved(total, approved, rejected);
            }

            System.debug(LoggingLevel.INFO,
                'ESA: updateEventStatusIfAllApproved newStatus=' + newStatus +
                ', event =' + evtId +
                ', total =' + total +
                ', approvedd=' + approved +
                ', rejectedd=' + rejected +
                ', recalledd=' + recalled
            );

            if (newStatus != null) {
                toUpdate.add(new Event__c(
                    Id = evtId,
                    Status__c = newStatus
                ));
            } else {
                System.debug(LoggingLevel.DEBUG,
                    'ESA: event not ready for final status, event=' + evtId +
                    ', approved=' + approved +
                    ', rejected=' + rejected +
                    ', recalled=' + recalled +
                    ', total=' + total
                );
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug(LoggingLevel.INFO, 'ESA: updated events count=' + toUpdate.size());
        }
    }

    // Count items by Event and Status for the given events (only relevant statuses)
    private static Map<Id, Map<String, Integer>> queryApprovalCounts(Set<Id> eventIds) {
        Map<Id, Map<String, Integer>> out = new Map<Id, Map<String, Integer>>();

        if (eventIds == null || eventIds.isEmpty()) {
            return out;
        }

        Set<String> approvalStatuses = new Set<String>{
            customEventConstants.APPROVAL_STATUS_SUBMITTED,
            customEventConstants.APPROVAL_STATUS_APPROVED_SPEAKER,
            customEventConstants.APPROVAL_STATUS_APPROVED_HOP,
            customEventConstants.APPROVAL_STATUS_REJECTED,
            customEventConstants.APPROVAL_STATUS_RECALLED,
            'AutoApproved'
        };

        for (AggregateResult ar : [
            SELECT Event__c evt, Status__c status, COUNT(Id) cnt
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :eventIds
            AND Status__c IN :approvalStatuses
            GROUP BY Event__c, Status__c
        ]) {
            Id eventId = (Id) ar.get('evt');
            String status = (String) ar.get('status');
            Integer countValue = (Integer) ar.get('cnt');

            if (!out.containsKey(eventId)) {
                out.put(eventId, new Map<String, Integer>());
            }

            out.get(eventId).put(status, countValue);
        }
        System.debug(LoggingLevel.INFO, 'ESA: queryApprovalCounts result=' + out);
        return out;
    }

    private static String shouldMarkFullyApproved(Integer total, Integer approved, Integer rejected) {
        System.debug(LoggingLevel.INFO, 'ESA: shouldMarkFullyApproved total=' + total + ', approved=' + approved + ', rejected=' + rejected);
        if (total == null || total <= 0) {
            return null;
        }

        if (approved == null) approved = 0;
        if (rejected == null) rejected = 0;

        if (total == approved) {
            return customEventConstants.STATUS_FULLY_APPROVED;
        } 
        else if (total == rejected) {
            return customEventConstants.STATUS_REJECTED;
        } 
        else if (total == approved + rejected) {
            return customEventConstants.STATUS_PARTIALLY_APPROVED;
        }

        return customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS; // cas par défaut obligatoire
    }


    /**
     * Construit une section HTML (sans titre) pour une liste de SessionSpeakerProduct__c.
     * Signature conservée (sectionTitle, speakers) pour évolution future.
     */
    public static String buildSpeakersHtmlSingleSection(String sectionTitle, List<SessionSpeakerProduct__c> speakers) {
        system.debug('======buildSpeakersHtmlSingleSection===========' +speakers  );
        List<String> parts = new List<String>();
        parts.add('<div style="margin:0 0 12px 0;">');

        if (speakers == null || speakers.isEmpty()) {
            parts.add('<div style="font-size:13px;color:#6b7280;">No speakers selected.</div>');
            parts.add('</div>');
            return String.join(parts, '');
        }

        parts.add(buildSpeakersTableHtml(speakers));
        parts.add('</div>');
        return String.join(parts, '');
    }

    private static Set<Id> collectEventIdsForEmptyHtmlOnUpdate(
        Map<Id, Event__c> newEvents,
        Map<Id, Event__c> oldEvents
    ) {
        Set<Id> ids = new Set<Id>();

        if (newEvents == null || oldEvents == null) return ids;

        for (Event__c e : newEvents.values()) {
            if (e == null || e.Id == null) continue;

            // Update only + SpeakersHTML__c empty
            if (String.isBlank(e.SpeakersHTML__c)) {
                ids.add(e.Id);
            }
        }

        return ids;
    }

    /**
     * Rend une table HTML groupée par speaker :
     * une seule ligne par SpeakerContact__c avec les produits concaténés.
     */
    private static String buildSpeakersTableHtml(List<SessionSpeakerProduct__c> speakers) {
        system.debug('buildSpeakersTableHtml========speakers====='+ speakers  );
        List<String> parts = new List<String>();

        List<SpeakerHtmlRow> groupedRows = groupSpeakersForHtml(speakers);

        parts.add('<table style="width:100%; border-collapse:collapse; font-size:13px;">');
        parts.add(
            '<tr>' +
                '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Speaker</th>' +
                '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Time Slot</th>' +
                '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Language</th>' +
                '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Presentation</th>' +
                '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Products</th>' +
            '</tr>'
        );

        for (SpeakerHtmlRow row : groupedRows) {
            system.debug('buildSpeakersTableHtml========row====='+ row  );
            system.debug('buildSpeakersTableHtml========row.products====='+ row.products  );

            List<String> productNames = new List<String>();
            productNames.addAll(row.products);
            productNames.sort();

            String productsText = productNames.isEmpty()
                ? '—'
                : esc(String.join(productNames, ', '));
            String timeSlotText = buildTimeSlotText(row.startTime, row.endTime);
            parts.add(
                '<tr>' +
                '<td ' + TD_STYLE + '>' + esc(row.speakerName) + '</td>' +
                '<td ' + TD_STYLE + '>' + esc(timeSlotText) + '</td>' +
                '<td ' + TD_STYLE + '>' + esc(row.language) + '</td>' +
                '<td ' + TD_STYLE + '>' + esc(row.presentationStatus) + '</td>' +
                '<td ' + TD_STYLE + '>' + productsText + '</td>' +
                '</tr>'
            );
        }

        parts.add('</table>');
        return String.join(parts, '');
    }
    private static String buildTimeSlotText(Time startTime, Time endTime) {
        if (startTime == null || endTime == null) return '—';

        return formatTime(startTime) + ' - ' + formatTime(endTime);
    }

    private static String formatTime(Time t) {
        if (t == null) return '';

        String h = String.valueOf(t.hour()).leftPad(2, '0');
        String m = String.valueOf(t.minute()).leftPad(2, '0');

        return h + ':' + m;
    }
    private static Time parseTimeFromJson(Object value) {
        if (value == null) return null;

        String raw = String.valueOf(value);
        if (String.isBlank(raw)) return null;

        List<String> parts = raw.split(':');
        if (parts.size() < 2) return null;

        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);

        return Time.newInstance(hour, minute, 0, 0);
    }
    /* =========================================================
    FLOW INVOCABLE - BUILD SPEAKERS HTML (JSON = list of SSP)
    ========================================================= */

    public class SpeakersHtmlRequest {
        @InvocableVariable(required=true description='JSON string contenant une liste de sessionSpeakerProduct__c')
        public String jsonPayload;
    }

    public class SpeakersHtmlResponse {
        @InvocableVariable(description='HTML à copier dans Event__c.SpeakersHTML__c')
        public String speakersHtml;
    }

    @InvocableMethod(
        label='Build Speakers HTML (JSON List SSP)'
        description='Construit le HTML à partir d’un JSON contenant une liste de sessionSpeakerProduct__c'
    )
    public static List<SpeakersHtmlResponse> buildSpeakersHtmlFromFlow(List<SpeakersHtmlRequest> requests) {

        System.debug(LoggingLevel.DEBUG, '================buildSpeakersHtmlFromFlow == requests = ' + requests);

        List<SpeakersHtmlResponse> results = new List<SpeakersHtmlResponse>();
        if (requests == null || requests.isEmpty()) return results;

        for (SpeakersHtmlRequest r : requests) {
            SpeakersHtmlResponse out = new SpeakersHtmlResponse();
            List<SessionSpeakerProduct__c> speakers = new List<SessionSpeakerProduct__c>();

            if (r != null && String.isNotBlank(r.jsonPayload)) {
                try {
                    List<Object> rawList = (List<Object>) JSON.deserializeUntyped(r.jsonPayload);

                    Set<Id> speakerIdsToQuery = new Set<Id>();
                    Set<Id> strategyIdsToQuery = new Set<Id>();
                    List<Map<String, Object>> parsedRows = new List<Map<String, Object>>();

                    // 1) Parse JSON and collect ids
                    for (Object o : rawList) {
                        if (o == null) continue;

                        Map<String, Object> row = (Map<String, Object>) o;
                        parsedRows.add(row);

                        String speakerIdStr = (String) row.get('speakerContact__c');
                        if (String.isNotBlank(speakerIdStr)) {
                            speakerIdsToQuery.add((Id) speakerIdStr);
                        }

                        String strategyIdStr = (String) row.get('strategy__c');
                        if (String.isNotBlank(strategyIdStr)) {
                            strategyIdsToQuery.add((Id) strategyIdStr);
                        }
                    }

                    // 2) Load contacts
                    Map<Id, Contact> contactById = new Map<Id, Contact>();
                    if (!speakerIdsToQuery.isEmpty()) {
                        for (Contact c :[
                                SELECT Id, Name, Account.Name
                                FROM Contact
                                WHERE Id IN :speakerIdsToQuery
                            ]) {
                            contactById.put(c.Id, c);
                        }
                    }

                    // 3) Load strategies/products
                    Map<Id, strategy__c> strategyById = new Map<Id, strategy__c>();
                    if (!strategyIdsToQuery.isEmpty()) {
                        for (strategy__c s :[
                                SELECT Id, Name
                                FROM strategy__c
                                WHERE Id IN :strategyIdsToQuery
                            ]) {
                            strategyById.put(s.Id, s);
                        }
                    }

                    // 4) Rebuild SSP rows used by HTML renderer
                    for (Map<String, Object> row : parsedRows) {
                        String speakerIdStr = (String) row.get('speakerContact__c');
                        if (String.isBlank(speakerIdStr)) continue;

                        Id speakerId = (Id) speakerIdStr;

                        SessionSpeakerProduct__c fake = new SessionSpeakerProduct__c();
                        fake.SpeakerContact__c = speakerId;
                        fake.SpeakerContact__r = contactById.get(speakerId);

                        fake.Language__c = (String) row.get('Language__c');
                        fake.PresentationStatus__c = (String) row.get('PresentationStatus__c');
                        fake.startTime__c = parseTimeFromJson(row.get('startTime__c'));
                        fake.endTime__c = parseTimeFromJson(row.get('endTime__c'));
                        String strategyIdStr = (String) row.get('strategy__c');
                        if (String.isNotBlank(strategyIdStr)) {
                            Id strategyId = (Id) strategyIdStr;
                            fake.strategy__c = strategyId;
                            fake.strategy__r = strategyById.get(strategyId);
                        }

                        speakers.add(fake);
                    }

                } catch (Exception ex) {
                    throw new SpeakerApprovalUpsertException('Invalid JSON payload: ' + ex.getMessage());
                }
            }

            out.speakersHtml = buildSpeakersHtmlSingleSection('Speakers', speakers);
            results.add(out);
        }

        return results;
    }

    /**
     * Structure intermédiaire pour construire une seule ligne HTML par speaker.
     */
    private class SpeakerHtmlRow {
        public Id speakerId;
        public String speakerName;
        public String accountName;
        public String language;
        public String presentationStatus;
        public Time startTime;
        public Time endTime;
        public Set<String> products = new Set<String>();
    }

    /**
     * Groupe les SessionSpeakerProduct__c par SpeakerContact__c.
     * Pour un même speaker, les produits strategy__r.Name sont fusionnés.
     */
    private static List<SpeakerHtmlRow> groupSpeakersForHtml(List<SessionSpeakerProduct__c> speakers) {
        system.debug('==============groupSpeakersForHtml====speakers='+speakers);
        Map<Id, SpeakerHtmlRow> rowsBySpeakerId = new Map<Id, SpeakerHtmlRow>();
        List<SpeakerHtmlRow> rowsWithoutSpeakerId = new List<SpeakerHtmlRow>();

        if (speakers == null) return new List<SpeakerHtmlRow>();

        for (SessionSpeakerProduct__c s : speakers) {
            if (s == null) continue;

            // Cas nominal : speaker renseigné => groupement par SpeakerContact__c
            if (s.SpeakerContact__c != null) {
                SpeakerHtmlRow row = rowsBySpeakerId.get(s.SpeakerContact__c);

                if (row == null) {
                    row = new SpeakerHtmlRow();
                    row.startTime = s.startTime__c;
                    row.endTime = s.endTime__c;
                    row.speakerId = s.SpeakerContact__c;
                    row.speakerName = (s.SpeakerContact__r != null && String.isNotBlank(s.SpeakerContact__r.Name))
                        ? s.SpeakerContact__r.Name
                        : 'Unknown';
                    row.accountName = (s.SpeakerContact__r != null && s.SpeakerContact__r.Account != null)
                        ? s.SpeakerContact__r.Account.Name
                        : '';
                    row.language = s.Language__c;
                    row.presentationStatus = s.PresentationStatus__c;

                    rowsBySpeakerId.put(s.SpeakerContact__c, row);
                }

                if (String.isBlank(row.language) && String.isNotBlank(s.Language__c)) {
                    row.language = s.Language__c;
                }
                if (String.isBlank(row.presentationStatus) && String.isNotBlank(s.PresentationStatus__c)) {
                    row.presentationStatus = s.PresentationStatus__c;
                }
                if (row.startTime == null && s.startTime__c != null) {
                    row.startTime = s.startTime__c;
                }
                if (row.endTime == null && s.endTime__c != null) {
                    row.endTime = s.endTime__c;
                }
                system.debug('==============groupSpeakersForHtml====s.strategy__r='+s.strategy__r);
                if (s.strategy__r != null && String.isNotBlank(s.strategy__r.Name)) {
                    system.debug('==============groupSpeakersForHtml====s.strategy__r.Name='+s.strategy__r.Name);

                    row.products.add(s.strategy__r.Name);
                }
            } else {
                // Fallback rare : pas de speaker => une ligne isolée
                SpeakerHtmlRow row = new SpeakerHtmlRow();
                row.speakerName = 'Unknown';
                row.accountName = '';
                row.language = s.Language__c;
                row.presentationStatus = s.PresentationStatus__c;
                if (s.strategy__r != null && String.isNotBlank(s.strategy__r.Name)) {
                    row.products.add(s.strategy__r.Name);
                }
                rowsWithoutSpeakerId.add(row);
            }
        }

        List<SpeakerHtmlRow> result = new List<SpeakerHtmlRow>();
        result.addAll(rowsBySpeakerId.values());
        result.addAll(rowsWithoutSpeakerId);

        result.sort(new SpeakerHtmlRowSorter());
        return result;
    }

    /**
     * Tri simple pour stabiliser l'affichage par nom de speaker.
     */
    private class SpeakerHtmlRowSorter implements System.Comparator<SpeakerHtmlRow> {
        public Integer compare(SpeakerHtmlRow left, SpeakerHtmlRow right) {
            String ln = (left == null || left.speakerName == null) ? '' : left.speakerName.toLowerCase();
            String rn = (right == null || right.speakerName == null) ? '' : right.speakerName.toLowerCase();

            if (ln == rn) return 0;
            return ln < rn ? -1 : 1;
        }
    }

    private class GroupResult {
        Map<String, Set<String>> productsByKey;
        Map<String, Integer> maxDurationByKey;
        Map<String, SessionSpeakerProduct__c> bestSSPByKey;
    }

    /**
     * Recalcule les EventSpeakerApprovals__c impactés après modification d’un SSP.
     * Détecte les changements de slot (start/end) ou de speaker/session et relance le calcul.
     */
    public static void updateApprovalSlots(
        Map<Id, SessionSpeakerProduct__c> oldMap,
        Map<Id, SessionSpeakerProduct__c> newMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;

        Set<Id> sessionIds = new Set<Id>();

        for (Id sspId : newMap.keySet()) {
            SessionSpeakerProduct__c oldRec = (oldMap != null) ? oldMap.get(sspId) : null;
            SessionSpeakerProduct__c newRec = newMap.get(sspId);

            if (newRec == null || newRec.Session__c == null) continue;

            Boolean slotChanged =
                oldRec == null ||
                oldRec.startTime__c != newRec.startTime__c ||
                oldRec.endTime__c != newRec.endTime__c ||
                oldRec.SpeakerContact__c != newRec.SpeakerContact__c ||
                oldRec.Session__c != newRec.Session__c;

            if (slotChanged) {
                sessionIds.add(newRec.Session__c);

                if (oldRec != null && oldRec.Session__c != null) {
                    sessionIds.add(oldRec.Session__c);
                }
            }
        }

        if (sessionIds.isEmpty()) return;

        refreshApprovalsFromSessions(sessionIds);
    }
    
    /**
     * Recharge les SSP d’une ou plusieurs sessions et synchronise les approvals.
     * Les approvals ne sont recalculées que pour les events en
     * WaitingForSpeakerApprovals.
     */
    public static void refreshApprovalsFromSessions(Set<Id> sessionIds) {
        if (sessionIds == null || sessionIds.isEmpty()) return;

        Set<Id> waitingEventIds = new Set<Id>();

        for (Event__c eventRecord : [
            SELECT Id, Status__c
            FROM Event__c
            WHERE Id IN :sessionIds
        ]) {
            if (eventRecord.Status__c == customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS) {
                waitingEventIds.add(eventRecord.Id);
            }
        }

        if (waitingEventIds.isEmpty()) return;

        List<SessionSpeakerProduct__c> lines = querySpeakerProductLines(waitingEventIds);

        Set<Id> speakerContactIds = collectSpeakerContactIds(lines);
        Map<Id, Contact> speakerById = loadSpeakers(speakerContactIds);

        GroupResult gr = groupProductsByKey(lines);

        List<EventSpeakerApprovals__c> approvals = buildApprovals(
            gr.productsByKey,
            speakerById,
            gr.bestSSPByKey
        );

        deleteOrphanApprovals(waitingEventIds, speakerContactIds);
        upsertApprovals(approvals);
    }

    // Garde uniquement les events en attente d'approbation speaker.
    private static Set<Id> filterWaitingForSpeakerApprovalEvents(Set<Id> eventIds) {
        Set<Id> result = new Set<Id>();

        for (Event__c eventRecord : [
            SELECT Id, Status__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]) {
            if (eventRecord.Status__c == customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS) {
                result.add(eventRecord.Id);
            }
        }

        return result;
    }

    // Calculates target Event status from speaker approvals
    public static Map<Id, String> calculateEventStatusFromApprovals(Set<Id> eventIds) {
        Map<Id, String> result = new Map<Id, String>();

        if (eventIds == null || eventIds.isEmpty()) return result;

        Map<Id, Map<String, Integer>> countsByEventAndStatus = queryApprovalCounts(eventIds);

        // Build target status per Event
        for (Id evtId : countsByEventAndStatus.keySet()) {
            Map<String, Integer> statusCounts = countsByEventAndStatus.get(evtId);

            Integer total = 0;
            Integer approved = 0;
            Integer rejected = 0;
            Integer recalled = 0;

            for (String status : statusCounts.keySet()) {
                Integer countValue = statusCounts.get(status);
                if (countValue == null) continue;

                if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED_SPEAKER)) {
                    approved += countValue;
                    total += countValue;
                } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_REJECTED)) {
                    rejected += countValue;
                    total += countValue;
                } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_SUBMITTED)) {
                    total += countValue;
                } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_RECALLED)) {
                    recalled += countValue;
                } else if (status != null && status.equalsIgnoreCase(customEventConstants.APPROVAL_STATUS_APPROVED_HOP)) {
                    approved += countValue;
                    total += countValue;
                } else if (status != null && status.equalsIgnoreCase('AutoApproved')) {
                    approved += countValue;
                    total += countValue;
                }
            }

            // Store calculated status
            result.put(
                evtId,
                recalled > 0
                    ? customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS
                    : shouldMarkFullyApproved(total, approved, rejected)
            );
        }

        return result;
    }
    /*public static void markFullyApprovedAfterOrganizerApprovalIfNoSSP(List<Event__c> newEvents) {
        if (newEvents == null || newEvents.isEmpty()) return;

        Set<Id> eventIds = new Set<Id>();

        // Events still waiting after organizer approval path.
        for (Event__c ev : newEvents) {
            if (
                ev != null &&
                ev.Id != null &&
                ev.Status__c == customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS &&
                ev.OrganizerApprovalRequired__c == true
            ) {
                eventIds.add(ev.Id);
            }
        }

        if (eventIds.isEmpty()) return;

        Set<Id> eventsWithSSP = new Set<Id>();
        for (SessionSpeakerProduct__c ssp : [
            SELECT Session__c
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
            eventsWithSSP.add(ssp.Session__c);
        }

        List<Event__c> toUpdate = new List<Event__c>();

        for (Id eventId : eventIds) {
            if (!eventsWithSSP.contains(eventId)) {
                toUpdate.add(new Event__c(
                    Id = eventId,
                    Status__c = customEventConstants.STATUS_FULLY_APPROVED
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }*/

    private static Boolean isOrganizerDecisionApproved(Event__c newEvt, Map<Id, Event__c> oldEvents) {
        if (newEvt == null || oldEvents == null) return false;

        Event__c oldEvt = oldEvents.get(newEvt.Id);
        if (oldEvt == null) return false;

        return oldEvt.OrganizerDecision__c != 'Approved'
            && newEvt.OrganizerDecision__c == 'Approved';
    }
}