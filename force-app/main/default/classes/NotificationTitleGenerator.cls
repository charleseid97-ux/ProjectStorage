public without sharing class NotificationTitleGenerator {

    private static final Integer TITLE_MAX_LENGTH = 255;
    private static final String APPROVAL_REQUEST_TITLE = 'Approval request';
    private static final String UPDATE_REQUEST_TITLE = 'Update on existing request';

    // Renseigne le titre des approbations déclenchées directement par l'Event.
    public static void setEventNotificationTitles(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldEvents
    ) {
        if (newEvents == null || newEvents.isEmpty() || oldEvents == null) return;

        for (Event__c newEvent : newEvents) {
            if (newEvent == null) continue;
            Event__c oldEvent = oldEvents.get(newEvent.Id);
            if (oldEvent == null) continue;

            // Un titre déjà préparé par une resoumission ciblée reste prioritaire.
            if (
                !String.isBlank(newEvent.NotificationTitle__c) &&
                newEvent.NotificationTitle__c != oldEvent.NotificationTitle__c
            ) continue;

            // Ne mémorise une modification que si le code soumettra l'Organizer.
            if (
                hasOrganizerApprovalChange(newEvent, oldEvent) &&
                !isEventTeamSubmission(newEvent, oldEvent) &&
                newEvent.Organizer__c == UserInfo.getUserId()
            ) continue;

            // Les changements réalisés avant la première soumission restent une demande initiale.
            if (isInitialEventTeamSubmission(newEvent, oldEvent)) {
                newEvent.NotificationTitle__c = APPROVAL_REQUEST_TITLE;
                newEvent.NotificationDetails__c = null;
                continue;
            }

            String details = buildEventChangeDetails(newEvent, oldEvent);

            // Toute resoumission Event Team après la création reste une notification d'update.
            if (
                isEventTeamSubmission(newEvent, oldEvent) &&
                oldEvent.Status__c != 'Draft'
            ) {
                newEvent.NotificationTitle__c = UPDATE_REQUEST_TITLE;

                // Conserve le détail déjà préparé, par exemple lors de l'ajout d'un speaker.
                if (String.isBlank(newEvent.NotificationDetails__c)) {
                    newEvent.NotificationDetails__c = truncateTitle(details);
                }

                continue;
            }

            // Les autres modifications utilisent leur détail spécifique.
            if (!String.isBlank(details)) {
                newEvent.NotificationTitle__c = UPDATE_REQUEST_TITLE;
                newEvent.NotificationDetails__c = truncateTitle(details);
            } else if (isEventTeamSubmission(newEvent, oldEvent)) {
                newEvent.NotificationTitle__c = APPROVAL_REQUEST_TITLE;
                newEvent.NotificationDetails__c = null;
            }
        }
    }

    // Retourne le titre d'une demande Event Team initiale.
    public static String getNewApprovalTitle() {
        return APPROVAL_REQUEST_TITLE;
    }

    // Retourne le sujet commun de toutes les approbations resoumises.
    public static String getUpdatedApprovalTitle() {
        return UPDATE_REQUEST_TITLE;
    }

    // Construit le détail affiché lors de l'ajout d'un speaker.
    public static String buildSpeakerAddedDetails(List<String> speakerNames) {
        if (speakerNames == null || speakerNames.isEmpty()) {
            return 'A new speaker has been added to the request';
        }

        List<String> names = new List<String>(speakerNames);
        names.sort();
        return truncateTitle(
            'A new speaker has been added to the request: ' + String.join(names, ', ')
        );
    }

    // Construit les détails Organizer à partir des changements de créneau SSP.
    public static Map<Id, String> buildSspScheduleDetails(
        Map<Id, SessionSpeakerProduct__c> newSsps,
        Map<Id, SessionSpeakerProduct__c> oldSsps
    ) {
        Map<Id, String> detailsByEventId = new Map<Id, String>();
        if (newSsps == null || newSsps.isEmpty() || oldSsps == null) return detailsByEventId;

        Map<Id, String> speakerNamesById = loadSpeakerNames(newSsps.values());
        Map<Id, Set<String>> messagesByEventId = new Map<Id, Set<String>>();

        for (SessionSpeakerProduct__c newSsp : newSsps.values()) {
            if (newSsp == null) continue;
            SessionSpeakerProduct__c oldSsp = oldSsps.get(newSsp.Id);
            if (oldSsp == null || newSsp.Session__c == null) continue;

            String message = buildSspChangeTitle(
                newSsp,
                oldSsp,
                speakerNamesById.get(newSsp.SpeakerContact__c)
            );
            if (String.isBlank(message)) continue;

            if (!messagesByEventId.containsKey(newSsp.Session__c)) {
                messagesByEventId.put(newSsp.Session__c, new Set<String>());
            }
            messagesByEventId.get(newSsp.Session__c).add(message);
        }

        for (Id eventId : messagesByEventId.keySet()) {
            List<String> messages = new List<String>(messagesByEventId.get(eventId));
            messages.sort();

            // Un même changement fonctionnel ne doit apparaître qu'une seule fois.
            detailsByEventId.put(
                eventId,
                truncateTitle(String.join(messages, ' / '))
            );
        }

        return detailsByEventId;
    }

    // Construit le détail d'une resoumission Speaker Assistant ou Head of Product.
    public static String buildTargetedApprovalDetails(
        String reason,
        String speakerName
    ) {
        String name = String.isBlank(speakerName) ? 'the speaker' : speakerName;

        if (reason == 'SPEAKER_DATE_CHANGED') {
            return truncateTitle('The date of ' + name + '\'s speech has changed');
        }

        if (reason == 'SPEAKER_TIME_CHANGED') {
            return truncateTitle('The timing of ' + name + '\'s speech has changed');
        }

        if (reason == 'STRATEGY_CHANGED') {
            return truncateTitle('The strategy for ' + name + '\'s speech has changed');
        }

        if (reason == 'SPEAKER_ADDED') {
            return truncateTitle('A new speaker has been added to the request: ' + name);
        }

        return APPROVAL_REQUEST_TITLE;
    }

    // Détermine la modification Event affichée dans le cadre du template.
    private static String buildEventChangeDetails(Event__c newEvent, Event__c oldEvent) {
        if (newEvent.Organizer__c != oldEvent.Organizer__c) {
            return 'You have been assigned as new organizer of this request';
        }

        if (newEvent.StartDate__c != oldEvent.StartDate__c || newEvent.EndDate__c != oldEvent.EndDate__c) {
            return 'The date of the request has changed';
        }

        if (newEvent.StartTime__c != oldEvent.StartTime__c || newEvent.EndTime__c != oldEvent.EndTime__c) {
            return 'The timing of the request has changed';
        }

        if (newEvent.City__c != oldEvent.City__c || newEvent.Country__c != oldEvent.Country__c) {
            return 'The location has changed';
        }

        return null;
    }

    // Reproduit les changements Event qui relancent l'approbation Organizer.
    private static Boolean hasOrganizerApprovalChange(Event__c newEvent, Event__c oldEvent) {
        return newEvent.Organizer__c != oldEvent.Organizer__c
            || newEvent.StartDate__c != oldEvent.StartDate__c
            || newEvent.EndDate__c != oldEvent.EndDate__c
            || newEvent.StartTime__c != oldEvent.StartTime__c
            || newEvent.EndTime__c != oldEvent.EndTime__c;
    }

    // Identifie la transition qui déclenche l'approbation Event Team.
    private static Boolean isEventTeamSubmission(Event__c newEvent, Event__c oldEvent) {
        return oldEvent.Status__c != 'SubmittedToEventTeam'
            && newEvent.Status__c == 'SubmittedToEventTeam';
    }

    // Distingue la première demande Event Team des resoumissions ultérieures.
    private static Boolean isInitialEventTeamSubmission(Event__c newEvent, Event__c oldEvent) {
        return oldEvent.Status__c == 'Draft'
            && newEvent.Status__c == 'SubmittedToEventTeam';
    }

    // Détermine le message de modification d'un speaker sans écraser le cas date.
    private static String buildSspChangeTitle(
        SessionSpeakerProduct__c newSsp,
        SessionSpeakerProduct__c oldSsp,
        String speakerName
    ) {
        String name = String.isBlank(speakerName) ? 'the speaker' : speakerName;

        if (newSsp.Date__c != oldSsp.Date__c) {
            return 'The date of ' + name + '\'s speech has changed';
        }

        if (newSsp.StartTime__c != oldSsp.StartTime__c || newSsp.EndTime__c != oldSsp.EndTime__c) {
            return 'The timing of ' + name + '\'s speech has changed';
        }

        if (newSsp.Strategy__c != oldSsp.Strategy__c) {
            return 'The strategy for ' + name + '\'s speech has changed';
        }

        return null;
    }

    // Charge les noms nécessaires aux titres créés depuis un trigger SSP.
    private static Map<Id, String> loadSpeakerNames(List<SessionSpeakerProduct__c> ssps) {
        Set<Id> speakerIds = new Set<Id>();
        for (SessionSpeakerProduct__c ssp : ssps) {
            if (ssp != null && ssp.SpeakerContact__c != null) {
                speakerIds.add(ssp.SpeakerContact__c);
            }
        }

        Map<Id, String> namesById = new Map<Id, String>();
        if (speakerIds.isEmpty()) return namesById;

        for (Contact speaker : [SELECT Id, Name FROM Contact WHERE Id IN :speakerIds]) {
            namesById.put(speaker.Id, speaker.Name);
        }

        return namesById;
    }

    // Garantit la compatibilité avec la taille maximale d'un sujet Salesforce.
    private static String truncateTitle(String title) {
        if (String.isBlank(title) || title.length() <= TITLE_MAX_LENGTH) return title;

        return title.substring(0, TITLE_MAX_LENGTH - 3) + '...';
    }
}