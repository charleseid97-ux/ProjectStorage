public without sharing class BooklyMeetingInvitationService {
    private static final String APPROVED_STATUS = 'FullyApproved';
    private static final String SUBJECT_PREFIX = '[Bookly] - ';
    private static final String DEFAULT_TIME_ZONE = 'Europe/Paris';

    // Crée ou met à jour l'invitation Outlook lors du passage à FullyApproved.
    public static void enqueueInvitationsOnApproval(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        Set<Id> eventIdsToCreate = new Set<Id>();
        Set<Id> eventIdsToUpdate = new Set<Id>();

        if (newEvents == null || newEvents.isEmpty()) {
            return;
        }

        // Sépare les créations des mises à jour selon la présence de l'ID Outlook.
        for (Event__c eventRecord : newEvents) {
            Event__c oldEvent = oldMap != null ? oldMap.get(eventRecord.Id) : null;

            Boolean becameFullyApproved =
                eventRecord.Status__c == APPROVED_STATUS &&
                (oldEvent == null || oldEvent.Status__c != APPROVED_STATUS);

            if (!becameFullyApproved) {
                continue;
            }

            if (String.isBlank(eventRecord.MicrosoftEventId__c)) {
                eventIdsToCreate.add(eventRecord.Id);
            } else {
                eventIdsToUpdate.add(eventRecord.Id);
            }
        }

        // Crée uniquement les invitations qui n'existent pas encore.
        if (!eventIdsToCreate.isEmpty()) {
            System.enqueueJob(
                new BooklyMeetingInvitationQueueable(eventIdsToCreate, false)
            );
        }

        // Met à jour les invitations Outlook existantes.
        if (!eventIdsToUpdate.isEmpty()) {
            System.enqueueJob(
                new BooklyMeetingInvitationQueueable(eventIdsToUpdate, true)
            );
        }
    }

    // Lance la mise à jour Microsoft Graph si aucun Organizer approval n'est attendu.
    public static void enqueueInvitationUpdatesOnEventChange(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        Set<Id> eventIdsToUpdate = new Set<Id>();
        Id currentUserId = UserInfo.getUserId();

        for (Event__c eventRecord : newEvents) {
            Event__c oldEvent = oldMap != null ? oldMap.get(eventRecord.Id) : null;

            // Ignore les créations et les Events sans invitation Microsoft Graph.
            if (oldEvent == null || String.isBlank(eventRecord.MicrosoftEventId__c)) {
                continue;
            }

            // Les changements de créneau nécessitent l'approbation de l'Organizer.
            Boolean schedulingChanged =
                eventRecord.StartDate__c != oldEvent.StartDate__c ||
                eventRecord.StartTime__c != oldEvent.StartTime__c ||
                eventRecord.EndDate__c != oldEvent.EndDate__c ||
                eventRecord.EndTime__c != oldEvent.EndTime__c;

            // Ces changements peuvent être envoyés immédiatement à Outlook.
            Boolean directMeetingChange =
                eventRecord.TimeZone__c != oldEvent.TimeZone__c ||
                eventRecord.City__c != oldEvent.City__c;

            // L'Organizer ne doit pas approuver ses propres changements.
            Boolean schedulingCanBeUpdatedImmediately =
                schedulingChanged &&
                eventRecord.Organizer__c == currentUserId;

            Boolean becameCancelled =
                eventRecord.Status__c == 'Cancelled' &&
                oldEvent.Status__c != 'Cancelled';

            // Pour un autre utilisateur, le créneau sera envoyé après FullyApproved.
            if (
                directMeetingChange ||
                schedulingCanBeUpdatedImmediately ||
                becameCancelled
            ) {
                eventIdsToUpdate.add(eventRecord.Id);
            }
        }

        // Met à jour uniquement les invitations ne nécessitant pas d'approbation.
        if (!eventIdsToUpdate.isEmpty()) {
            System.enqueueJob(
                new BooklyMeetingInvitationQueueable(eventIdsToUpdate, true)
            );
        }
    }
        // Met à jour l'invitation Outlook lorsqu'un créneau SSP change.
    public static void enqueueInvitationUpdatesOnSspChange(
        Map<Id, SessionSpeakerProduct__c> newMap,
        Map<Id, SessionSpeakerProduct__c> oldMap
    ) {
        if (newMap == null || newMap.isEmpty() || oldMap == null) return;

        Set<Id> changedSspIds = new Set<Id>();

        // Garde uniquement les SSP dont la date ou l'heure a changé.
        for (Id sspId : newMap.keySet()) {
            SessionSpeakerProduct__c newSsp = newMap.get(sspId);
            SessionSpeakerProduct__c oldSsp = oldMap.get(sspId);

            if (newSsp == null || oldSsp == null || newSsp.Session__c == null) {
                continue;
            }

            if (
                newSsp.Date__c != oldSsp.Date__c ||
                newSsp.StartTime__c != oldSsp.StartTime__c ||
                newSsp.EndTime__c != oldSsp.EndTime__c
            ) {
                changedSspIds.add(sspId);
            }
        }

        if (changedSspIds.isEmpty()) return;

        Map<Id, List<String>> messagesByEventId = new Map<Id, List<String>>();
        Set<Id> eventIds = new Set<Id>();

        // Recharge les valeurs finales et le nom du speaker.
        for (SessionSpeakerProduct__c ssp : [
            SELECT Id, Session__c, Date__c, StartTime__c, EndTime__c,
                   SpeakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Id IN :changedSspIds
        ]) {
            if (!messagesByEventId.containsKey(ssp.Session__c)) {
                messagesByEventId.put(ssp.Session__c, new List<String>());
            }

            String speakerName = ssp.SpeakerContact__r == null
                ? 'Speaker'
                : ssp.SpeakerContact__r.Name;

            // Construit le nouveau créneau visible dans l'invitation.
            String slotMessage =
                speakerName + ': ' +
                formatSspDate(ssp.Date__c) + ', ' +
                formatSspTime(ssp.StartTime__c) + ' - ' +
                formatSspTime(ssp.EndTime__c);

            messagesByEventId.get(ssp.Session__c).add(slotMessage);
            eventIds.add(ssp.Session__c);
        }

        if (eventIds.isEmpty()) return;

        Set<Id> eligibleEventIds = new Set<Id>();
        Map<Id, String> finalMessagesByEventId = new Map<Id, String>();

        // Envoie la mise à jour uniquement pour les Events déjà validés.
        for (Event__c eventRecord : [
            SELECT Id, Status__c, MicrosoftEventId__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]) {
            if (
                eventRecord.Status__c != APPROVED_STATUS ||
                String.isBlank(eventRecord.MicrosoftEventId__c)
            ) {
                continue;
            }

            eligibleEventIds.add(eventRecord.Id);
            finalMessagesByEventId.put(
                eventRecord.Id,
                'The speaker schedule has been updated.' + '\n\n' +
                String.join(messagesByEventId.get(eventRecord.Id), '\n')
            );
        }

        if (!eligibleEventIds.isEmpty()) {
            System.enqueueJob(
                new BooklyMeetingInvitationQueueable(
                    eligibleEventIds,
                    true,
                    finalMessagesByEventId
                )
            );
        }
    }

    // Formate une date SSP pour le message Outlook.
    private static String formatSspDate(Date value) {
        return value == null ? 'Date not specified' : value.format();
    }

    // Formate une heure SSP pour le message Outlook.
    private static String formatSspTime(Time value) {
        if (value == null) return 'Time not specified';

        String hourValue = String.valueOf(value.hour()).leftPad(2, '0');
        String minuteValue = String.valueOf(value.minute()).leftPad(2, '0');

        return hourValue + ':' + minuteValue;
    }
}