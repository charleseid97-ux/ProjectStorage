public with sharing class customEventSpeakerApprovalService {

    // Prevent processing the same Event multiple times in the same transaction (Flow/automation recursion)
    private static Set<Id> PROCESSED_HTML_EVENT_IDS = new Set<Id>();
    private static Set<Id> PROCESSED_APPROVAL_EVENT_IDS = new Set<Id>();
    private static Set<Id> PROCESSED_MARK_FULLY_APPROVED_EVENT_IDS = new Set<Id>();

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
        System.debug(LoggingLevel.INFO, 'prepareSpeakerHTMLforNotifications: start processing');
        if (newEvents == null || newEvents.isEmpty()) return;

        Set<Id> eventIds = collectEventIdsToProcess(newEvents, oldEvents);
        if (eventIds.isEmpty()) return;

        if (!applyRecursionGuard(eventIds, PROCESSED_HTML_EVENT_IDS)) return;

        List<SessionSpeakerProduct__c> ssp = [
            SELECT Session__c, SpeakerContact__c,
                SpeakerContact__r.Name, SpeakerContact__r.Account.Name,
                Language__c, PresentationStatus__c, Product__c
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
            ORDER BY Session__c
        ];

        Map<Id, List<SessionSpeakerProduct__c>> eventToSpeakers = new Map<Id, List<SessionSpeakerProduct__c>>();
        for (SessionSpeakerProduct__c s : ssp) {
            if (s == null || s.Session__c == null) continue;
            if (!eventToSpeakers.containsKey(s.Session__c)) {
                eventToSpeakers.put(s.Session__c, new List<SessionSpeakerProduct__c>());
            }
            eventToSpeakers.get(s.Session__c).add(s);
        }

        for (Id evtId : eventIds) {
            Event__c e = newEvents.get(evtId);
            if (e == null) continue;

            e.SpeakersHTML__c = buildSpeakersHtmlSingleSection(
                'Speakers',
                eventToSpeakers.get(evtId)
            );
        }
    }

      // petit util minimal d'échappement (prévenir HTML break)
    private static String esc(String v) {
        if (v == null) return '';
        return v.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;').replace('\'','&#39;');
    }

   /**
     * Vérifie les events qui viennent d'entrer en WaitingForSpeakerApprovals.
     * Si aucun SessionSpeakerProduct__c n'est lié à l'event, force le statut
     * de l'Event__c à 'FullyApproved'.
     *
     * Conçu pour être appelé depuis un trigger BEFORE UPDATE : on modifie directement
     * les enregistrements dans la map newEvents (pas de DML).
     */
    public static void markEventFullyApprovedIfNoSSP(
        Map<Id, Event__c> newEvents,
        Map<Id, Event__c> oldEvents
    ) {
        System.debug(LoggingLevel.INFO, 'markEventFullyApprovedIfNoSSP: start processing');
        if (newEvents == null || newEvents.isEmpty()) return;

        // 1) Déterminer les events concernés (entrants en WaitingForSpeakerApprovals)
        Set<Id> eventIds = collectEventIdsToProcess(newEvents, oldEvents);
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
                if (newEvt == null) {
                    System.debug(LoggingLevel.WARN, 'markEventFullyApprovedIfNoSSP: event not found in newEvents map, event=' + evtId);
                    continue;
                }

                String currentStatus = newEvt.Status__c;
                if (currentStatus == null || !currentStatus.equalsIgnoreCase('FullyApproved')) {
                    // Modification directe dans la map pour BEFORE trigger (pas de DML)
                    newEvt.Status__c = 'FullyApproved';
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
     * when an Event enters WaitingForSpeakerApprovals.
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
        Map<String, Set<String>> productsByKey = groupProductsByKey(lines);

        // Build approval records (upserted by unique Key__c)
        List<EventSpeakerApprovals__c> approvals = buildApprovals(productsByKey, speakerById);

        // --- nettoyage: supprimer les approvals orphelines (non Approved)
        Set<String> validKeys = new Set<String>();
        for (EventSpeakerApprovals__c a : approvals) {
            if (a.Key__c != null) validKeys.add(a.Key__c);
        }
        deleteOrphanApprovals(eventIdsToProcess, speakerContactIds, validKeys);

        upsertApprovals(approvals);
    }

    // -------------------------
    // Helper & query methods
    // -------------------------

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
        if (lines == null) return speakerContactIds;
        for (SessionSpeakerProduct__c l : lines) {
            if (l != null && l.SpeakerContact__c != null) speakerContactIds.add(l.SpeakerContact__c);
        }
        return speakerContactIds;
    }

    // Load speakers and their assistants (assistant is a USER lookup)
    private static Map<Id, Contact> loadSpeakers(Set<Id> speakerContactIds) {
        if (speakerContactIds == null || speakerContactIds.isEmpty()) return new Map<Id, Contact>();
        return new Map<Id, Contact>([
            SELECT Id, SpeakerAssistant__c
            FROM Contact
            WHERE Id IN :speakerContactIds
        ]);
    }

    // Group product names by (Event, SpeakerContact)
    private static Map<String, Set<String>> groupProductsByKey(List<SessionSpeakerProduct__c> lines) {
        Map<String, Set<String>> productsByKey = new Map<String, Set<String>>();
        if (lines == null) return productsByKey;

        for (SessionSpeakerProduct__c l : lines) {
            if (l == null || l.Session__c == null || l.SpeakerContact__c == null) continue;
            String key = String.valueOf(l.Session__c) + '-' + String.valueOf(l.SpeakerContact__c);
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
        if (productsByKey == null || productsByKey.isEmpty()) return approvals;

        for (String key : productsByKey.keySet()) {
            ApprovalBuildResult built = buildApproval(key, productsByKey.get(key), speakerById);
            if (built == null) continue;

            approvals.add(built.record);

            System.debug(LoggingLevel.DEBUG,
                'ESA: prepared approval for event=' + built.eventId +
                ', speaker=' + built.speakerId +
                ', approverUserId=' + built.approverUserId
            );
        }

        return approvals;
    }

    // Small DTO used during approvals build
    private class ApprovalBuildResult {
        Id eventId;
        Id speakerId;
        Id approverUserId;
        EventSpeakerApprovals__c record;
    }

    private static ApprovalBuildResult buildApproval(
        String key,
        Set<String> productNames,
        Map<Id, Contact> speakerById
    ) {
        if (String.isBlank(key)) return null;
        Integer sep = key.indexOf('-');
        if (sep <= 0) return null;

        String eventIdStr = key.substring(0, sep);
        String speakerIdStr = key.substring(sep + 1);

        Id eventId;
        Id speakerId;
        try {
            eventId = (Id) eventIdStr;
            speakerId = (Id) speakerIdStr;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ESA: invalid key format, key=' + key);
            return null;
        }

        Contact speaker = (speakerById == null) ? null : speakerById.get(speakerId);

        // Approver must come from speaker's assistant (User lookup)
        Id approverUserId = (speaker != null) ? speaker.SpeakerAssistant__c : null;

        // Safety: abort if missing approver
        if (approverUserId == null) {
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
            Key__c          = key,
            Event__c        = eventId,
            Speaker__c      = speakerId,
            ApproverUser__c = approverUserId,
            Status__c       = 'Submitted',
            Summary__c      = String.join(names, ', ')
        );

        ApprovalBuildResult out = new ApprovalBuildResult();
        out.eventId = eventId;
        out.speakerId = speakerId;
        out.approverUserId = approverUserId;
        out.record = rec;
        return out;
    }

    /**
     * Supprime les EventSpeakerApprovals__c orphelines :
     * - pour les events donnés
     * - si le Speaker__c n'est plus présent dans speakerContactIds
     * - ou si le Key__c n'est plus dans validKeys (ex : produit/speaker modifié)
     *
     * NB : on évite de supprimer les enregistrements déjà 'Approved' par sécurité.
     */
    private static void deleteOrphanApprovals(
        Set<Id> eventIds,
        Set<Id> speakerContactIds,
        Set<String> validKeys
    ) {
        if (eventIds == null || eventIds.isEmpty()) return;

        List<EventSpeakerApprovals__c> toDelete = new List<EventSpeakerApprovals__c>();

        // Query approvals for these events (only fields needed)
        for (EventSpeakerApprovals__c ex : [
            SELECT Id, Key__c, Speaker__c, Status__c, Event__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :eventIds
        ]) {
            Boolean orphan = false;

            // If approval's speaker is not part of current speaker set -> orphan
            if (speakerContactIds != null && !speakerContactIds.contains(ex.Speaker__c)) {
                orphan = true;
            }

            // If approval key is not among valid keys -> orphan (handles product/name change)
            if (!orphan && validKeys != null && !validKeys.contains(ex.Key__c)) {
                orphan = true;
            }

            // Do not delete already Approved records (safety). If you want to delete them too, remove this check.
            if (orphan && (ex.Status__c == null || !String.valueOf(ex.Status__c).equalsIgnoreCase('Approved'))) {
                toDelete.add(ex);
            }
        }

        if (toDelete.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ESA: no orphan approvals to delete');
            return;
        }

        try {
            delete toDelete;
            System.debug(LoggingLevel.INFO, 'ESA: deleted orphan approvals count=' + toDelete.size());
        } catch (DmlException de) {
            System.debug(LoggingLevel.ERROR, 'ESA: DmlException when deleting orphan approvals: ' + de.getMessage());
            try {
                for (EventSpeakerApprovals__c a : toDelete) {
                    System.debug(LoggingLevel.ERROR, '  toDelete: Id=' + a.Id + ', Key__c=' + a.Key__c + ', Event__c=' + a.Event__c + ', Speaker__c=' + a.Speaker__c + ', Status__c=' + a.Status__c);
                }
            } catch (Exception px) {
                System.debug(LoggingLevel.ERROR, 'ESA: failed to log delete payload: ' + px.getMessage());
            }
            // Rethrow to surface the error to calling context
            throw de;
        }
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
            for (EventSpeakerApprovals__c ex : [
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
            if (existing != null && String.valueOf(existing.Status__c).equalsIgnoreCase('Approved')) {
                // terminal approved -> do not upsert
                skipped++;
                continue;
            }

            // New or existing non-approved -> force Submitted and queue for upsert
            a.Status__c = 'Submitted';
            toUpsert.add(a);
            queued++;
        }

        System.debug(LoggingLevel.INFO, 'ESA: approvals total=' + approvals.size() + ', queued=' + queued + ', skippedApproved=' + skipped);

        if (toUpsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ESA: nothing to upsert after filtering approved records');
            return;
        }

        try {
            upsert toUpsert Key__c;
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

        return (rec.Status__c == 'approved_speaker' && oldStatus != 'approved_speaker');
    }

    /**
     * Updates Event__c to FullyApproved if all speaker approvals are approved.
     */
    public static void updateEventStatusIfAllApproved(Set<Id> eventIds) {
        System.debug(LoggingLevel.INFO, 'ESA: updateEventStatusIfAllApproved for events ' + eventIds);
        if (eventIds == null || eventIds.isEmpty()) return;

        // Count total approvals per event
        Map<Id, Integer> totalByEvent = queryApprovalCounts(eventIds, null);

        // Count approved approvals per event
        Map<Id, Integer> approvedByEvent = queryApprovalCounts(eventIds, 'approved_speaker');
        Map<Id, Integer> rejectedByEvent = queryApprovalCounts(eventIds, 'rejected');

        List<Event__c> toUpdate = new List<Event__c>();

        for (Id evtId : totalByEvent.keySet()) {
            Integer total = totalByEvent.get(evtId);
            Integer approved = approvedByEvent.get(evtId);
            Integer rejected = rejectedByEvent.get(evtId);
            String newStatus = shouldMarkFullyApproved(total,approved,rejected);
            System.debug(LoggingLevel.INFO, 'ESA: updateEventStatusIfAllApproved  newStatus :' + newStatus);
            if ( newStatus!= null) {
                toUpdate.add(new Event__c(
                    Id = evtId,
                    Status__c = newStatus
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
    private static Map<Id, Integer> queryApprovalCounts(Set<Id> eventIds, String status) {
        String base =
            'SELECT Event__c evt, COUNT(Id) cnt ' +
            'FROM EventSpeakerApprovals__c ' +
            'WHERE Event__c IN :eventIds ';
        if (status != null) {
            base += 'AND Status__c = \''+status+'\' ';
        }
        base += 'GROUP BY Event__c';

        Map<Id, Integer> out = new Map<Id, Integer>();
        for (AggregateResult ar : Database.query(base)) {
            out.put((Id) ar.get('evt'), (Integer) ar.get('cnt'));
        }
        return out;
    }

    private static String shouldMarkFullyApproved(Integer total, Integer approved, Integer rejected) {
        if (total == null || total <= 0) {
            return null;
        }

        if (approved == null) approved = 0;
        if (rejected == null) rejected = 0;

        if (total == approved) {
            return 'FullyApproved';
        } 
        else if (total == rejected) {
            return 'Rejected';
        } 
        else if (total == approved + rejected) {
            return 'PartiallyApproved';
        }

        return null; // cas par défaut obligatoire
    }


    /**
 * Construit une section HTML (sans titre) pour une liste de SessionSpeakerProduct__c.
 * Signature conservée (sectionTitle, speakers) pour évolution future.
 */
private static String buildSpeakersHtmlSingleSection(String sectionTitle, List<SessionSpeakerProduct__c> speakers) {
    List<String> parts = new List<String>();
    parts.add('<div style="margin:0 0 12px 0;">');

    if (speakers == null || speakers.isEmpty()) {
        parts.add('<div style="font-size:13px;color:#6b7280;">No speakers found.</div>');
        parts.add('</div>');
        return String.join(parts, '');
    }

    parts.add(buildSpeakersTableHtml(speakers));
    parts.add('</div>');
    return String.join(parts, '');
}

    /**
     * Rend une table HTML 1 colonne, sans headers: uniquement les noms des speakers.
     */
    private static String buildSpeakersTableHtml(List<SessionSpeakerProduct__c> speakers) {
        List<String> parts = new List<String>();

        parts.add('<table style="width:100%;font-size:13px;">');

        for (SessionSpeakerProduct__c s : speakers) {
            String speakerName =
                (s != null && s.SpeakerContact__r != null && String.isNotBlank(s.SpeakerContact__r.Name))
                ? s.SpeakerContact__r.Name
                : 'Unknown';

            parts.add(
                '<tr>' +
                    '<td style="padding:6px 0;border-bottom:1px solid #f3f4f6;">' +
                        esc(speakerName) +
                    '</td>' +
                '</tr>'
            );
        }

        parts.add('</table>');
        return String.join(parts, '');
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

        List<SpeakersHtmlResponse> results = new List<SpeakersHtmlResponse>();
        if (requests == null || requests.isEmpty()) return results;

        for (SpeakersHtmlRequest r : requests) {

            SpeakersHtmlResponse out = new SpeakersHtmlResponse();
            List<SessionSpeakerProduct__c> speakers = new List<SessionSpeakerProduct__c>();

            if (r != null && String.isNotBlank(r.jsonPayload)) {

                try {
                    List<Object> rawList = (List<Object>) JSON.deserializeUntyped(r.jsonPayload);

                    Set<Id> seenSpeakerIds = new Set<Id>();
                    Set<Id> speakerIdsToQuery = new Set<Id>();

                    for (Object o : rawList) {
                        Map<String, Object> row = (Map<String, Object>) o;

                        String speakerIdStr = (String) row.get('speakerContact__c');
                        if (String.isBlank(speakerIdStr)) continue;

                        Id speakerId = (Id) speakerIdStr;

                        // DEDUPE ici (uniquement sur SpeakerContact)
                        if (!seenSpeakerIds.add(speakerId)) continue;

                        speakerIdsToQuery.add(speakerId);
                    }

                    // Query contacts pour afficher Name + Account
                    Map<Id, Contact> contactById = new Map<Id, Contact>();
                    if (!speakerIdsToQuery.isEmpty()) {
                        for (Contact c : [
                            SELECT Id, Name, Account.Name
                            FROM Contact
                            WHERE Id IN :speakerIdsToQuery
                        ]) {
                            contactById.put(c.Id, c);
                        }
                    }

                    // Construire des faux SSP juste pour le rendu HTML
                    for (Id speakerId : seenSpeakerIds) {

                        Contact c = contactById.get(speakerId);

                        SessionSpeakerProduct__c fake = new SessionSpeakerProduct__c();
                        fake.SpeakerContact__c = speakerId;

                        if (c != null) {
                            fake.SpeakerContact__r = c;
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
}