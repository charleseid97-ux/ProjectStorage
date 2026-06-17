public without sharing class BooklyMeetingInvitationQueueable
    implements Queueable, Database.AllowsCallouts {

    private static final String DEFAULT_NAMED_CREDENTIAL = 'MicrosoftGraphSF';
    private static final String DEFAULT_TIME_ZONE = 'Europe/Paris';
    private static final String SUBJECT_PREFIX = '[Bookly]';
    private static final String SUBJECT_SEPARATOR = ' – ';
    private static final String TEMPLATE_DEV_NAME = 'BooklyInvitation_VF';

    private static final String RT_EVENT = 'Event';
    private static final String RT_MEETING_DAYS = 'MeetingDays';
    private static final String RT_MEETING = 'Meeting';

    private static final String FORMAT_DIGITAL = 'Digital';
    private static final String JOB_TITLE_SALES = 'Sales';

    private static final String META_COMMUNICATION = 'Communication';
    private static final String META_LOCAL_MARKETING_EVENT_TEAM = 'LocalMarketing';

    private final Set<Id> eventIds;
    private final Boolean isUpdate;
    
    public BooklyMeetingInvitationQueueable(Set<Id> eventIds) {
        this(eventIds, false);
    }

    public BooklyMeetingInvitationQueueable(Set<Id> eventIds, Boolean isUpdate) {
        this.eventIds = eventIds == null ? new Set<Id>() : new Set<Id>(eventIds);
        this.isUpdate = isUpdate == true;
    }

    public void execute(QueueableContext context) {
        if (eventIds.isEmpty()) {
            return;
        }

        Map<Id, Event__c> eventsById = getEvents(eventIds);

        if (eventsById.isEmpty()) {
            return;
        }

        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId =
            getParticipantsByEventId(eventsById);

        Map<Id, String> speakerInitialsByEventId = getSpeakerInitialsByEventId(eventsById.keySet());

        Id templateId = getEmailTemplateIdByDeveloperName(TEMPLATE_DEV_NAME);
        List<Event__c> eventsToUpdate = new List<Event__c>();

        for (Id eventId : eventsById.keySet()) {
            Event__c eventRecord = eventsById.get(eventId);
            List<MicrosoftGraphMeetingService.Participant> participants =
                participantsByEventId.get(eventId);

            if ((participants == null || participants.isEmpty()) && eventRecord.Status__c != 'Cancelled') {
                logGraphInvitation(
                    OperationLogService.Level.INFO,
                    eventRecord,
                    'GraphInvitationSkipped',
                    buildGraphInvitationLogMessage(
                        eventRecord,
                        new List<String>(),
                        'SKIPPED',
                        null,
                        'No participants found for this Event__c.'
                    ),
                    null,
                    null,
                    null
                );

                System.debug('No participants found for Event__c: ' + eventId);
                continue;
            }

            System.debug(
                LoggingLevel.INFO,
                'Bookly final participants for Event__c ' + eventId + ': ' +
                JSON.serializePretty(participants)
            );

            MicrosoftGraphMeetingService.MeetingRequest request =
                buildMeetingRequest(
                    eventRecord,
                    participants,
                    templateId,
                    speakerInitialsByEventId.get(eventId)
                );

            System.debug(
                LoggingLevel.INFO,
                'Bookly Graph request for Event__c ' + eventId + ': ' +
                JSON.serializePretty(request)
            );

            List<String> emails = new List<String>();

            for (MicrosoftGraphMeetingService.Participant participant : request.participants) {
                emails.add(participant.email);
            }

            String logAction =
                eventRecord.Status__c == 'Cancelled'
                    ? 'GraphInvitationCancelling'
                    : (
                        isUpdate
                            ? 'GraphInvitationUpdating'
                            : 'GraphInvitationSending'
                    );

            try {
                MicrosoftGraphMeetingService.MeetingResponse response;

                if (isUpdate) {
                    if (String.isBlank(eventRecord.MicrosoftEventId__c)) {
                        logGraphInvitation(
                            OperationLogService.Level.ERROR,
                            eventRecord,
                            logAction,
                            buildGraphInvitationLogMessage(
                                eventRecord,
                                emails,
                                'ERROR',
                                null,
                                'Missing MicrosoftEventId__c.'
                            ),
                            request,
                            null,
                            null
                        );

                        continue;
                    }

                    if (eventRecord.Status__c == 'Cancelled') {
                        response =
                            MicrosoftGraphMeetingService.cancelTeamsMeeting(
                                request,
                                eventRecord.MicrosoftEventId__c
                            );
                    } else {
                        response =
                            MicrosoftGraphMeetingService.updateTeamsMeeting(
                                request,
                                eventRecord.MicrosoftEventId__c
                            );
                    }
                } else {
                    response =
                        MicrosoftGraphMeetingService.createTeamsMeeting(request);
                }

                String result = response.success == true ? 'SUCCESS' : 'FAIL';

                String logMessage = buildGraphInvitationLogMessage(
                    eventRecord,
                    emails,
                    result,
                    response,
                    response.errorMessage
                );

                if (response.success == true && !String.isBlank(response.eventId)) {
                    if (eventRecord.MicrosoftEventId__c != response.eventId) {
                        eventRecord.MicrosoftEventId__c = response.eventId;
                        eventsToUpdate.add(eventRecord);
                    }
                }

                logGraphInvitation(
                    response.success == true ? OperationLogService.Level.INFO : OperationLogService.Level.ERROR,
                    eventRecord,
                    logAction,
                    logMessage,
                    request,
                    response,
                    null
                );

                System.debug(
                    'Bookly meeting response for Event__c ' +
                    eventId +
                    ': ' +
                    JSON.serialize(response)
                );
            } catch (Exception e) {
                logGraphInvitation(
                    OperationLogService.Level.ERROR,
                    eventRecord,
                    logAction,
                    buildGraphInvitationLogMessage(
                        eventRecord,
                        emails,
                        'EXCEPTION',
                        null,
                        e.getMessage()
                    ),
                    request,
                    null,
                    e
                );
            }
        }

        try {
            if (!eventsToUpdate.isEmpty()) {
                Database.SaveResult[] updateResults = Database.update(eventsToUpdate, false);

                for (Integer index = 0; index < updateResults.size(); index++) {
                    if (updateResults[index].isSuccess()) {
                        continue;
                    }

                    logGraphInvitation(
                        OperationLogService.Level.ERROR,
                        eventsToUpdate[index],
                        'GraphInvitationEventUpdate',
                        'Unable to update Event__c with MicrosoftEventId__c: ' +
                        joinDatabaseErrors(updateResults[index].getErrors()),
                        null,
                        null,
                        null
                    );
                }
            }
        } catch (Exception e) {
            logGraphInvitation(
                OperationLogService.Level.ERROR,
                null,
                'GraphInvitationEventUpdate',
                'Unexpected error while updating Event__c records with MicrosoftEventId__c.',
                null,
                null,
                e
            );
        }

        OperationLogService.flush();
    }

    // Creates an OperationLog__c entry without updating the source Event__c record.
    private static void logGraphInvitation(
        OperationLogService.Level level,
        Event__c eventRecord,
        String operation,
        String message,
        MicrosoftGraphMeetingService.MeetingRequest request,
        MicrosoftGraphMeetingService.MeetingResponse response,
        Exception exceptionValue
    ) {
        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = level;
        entry.sourceRecordId = eventRecord == null ? null : String.valueOf(eventRecord.Id);
        entry.sourceObjectApiName = 'Event__c';
        entry.operation = operation;
        entry.message = message;
        entry.contextJson = buildGraphInvitationLogContext(eventRecord, request, response);
        entry.apexClass = 'BooklyMeetingInvitationQueueable';
        entry.methodName = 'execute';
        entry.exceptionValue = exceptionValue;

        OperationLogService.log(entry);
    }

    // Builds the visible message shown to admins in the Operation Logs component.
    private static String buildGraphInvitationLogMessage(
        Event__c eventRecord,
        List<String> emails,
        String result,
        MicrosoftGraphMeetingService.MeetingResponse response,
        String errorMessage
    ) {
        String recipients = emails == null ? '' : String.join(emails, ',');

        String logMessage =
            'to: ' + recipients +
            ' | sentDateTime: ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss') +
            ' | eventStart: ' + String.valueOf(eventRecord.StartDate__c) + ' ' + String.valueOf(eventRecord.StartTime__c) +
            ' | eventEnd: ' + String.valueOf(eventRecord.EndDate__c) + ' ' + String.valueOf(eventRecord.EndTime__c) +
            ' | timeZone: ' + safeString(eventRecord.TimeZone__c) +
            ' | location: ' + safeString(eventRecord.City__c) +
            ' | result: ' + result;

        if (response != null && response.success == true && !String.isBlank(response.eventId)) {
            logMessage += ' | eventId: ' + response.eventId;
        }

        if (!String.isBlank(errorMessage)) {
            logMessage += ' | error: ' + errorMessage;
        }

        return logMessage;
    }

    // Builds a compact JSON context for troubleshooting without adding lookups to Event__c.
    private static String buildGraphInvitationLogContext(
        Event__c eventRecord,
        MicrosoftGraphMeetingService.MeetingRequest request,
        MicrosoftGraphMeetingService.MeetingResponse response
    ) {
        Map<String, Object> context = new Map<String, Object>();
        context.put('eventId', eventRecord == null ? null : String.valueOf(eventRecord.Id));
        context.put('eventStatus', eventRecord == null ? null : eventRecord.Status__c);
        context.put('microsoftEventId', eventRecord == null ? null : eventRecord.MicrosoftEventId__c);
        context.put('requestSubject', request == null ? null : request.subject);
        context.put('participantCount', request == null || request.participants == null ? 0 : request.participants.size());
        context.put('generateTeamsLink', request == null ? null : request.generateTeamsLink);
        context.put('responseSuccess', response == null ? null : response.success);
        context.put('responseEventId', response == null ? null : response.eventId);
        context.put('responseErrorMessage', response == null ? null : response.errorMessage);

        return JSON.serialize(context);
    }

    // Converts Database.SaveResult errors into one readable log message.
    private static String joinDatabaseErrors(Database.Error[] errors) {
        List<String> messages = new List<String>();

        if (errors == null || errors.isEmpty()) {
            return '';
        }

        for (Database.Error error : errors) {
            messages.add(String.valueOf(error.getStatusCode()) + ': ' + error.getMessage());
        }

        return String.join(messages, ' | ');
    }

    private static Map<Id, Event__c> getEvents(Set<Id> eventIds) {
        return new Map<Id, Event__c>([
            SELECT Id,
                   RecordType.DeveloperName,
                   Name,
                   Title__c,
                   Format__c,
                   StartDate__c,
                   StartTime__c,
                   EndDate__c,
                   EndTime__c,
                   TimeZone__c,
                   SalesTeam__c,
                   Organizer__c,
                   Organizer__r.Name,
                   Organizer__r.Email,
                   SalesOwner__c,
                   SalesOwner__r.Name,
                   SalesOwner__r.Email,
                   OwnerId,
                   Owner.Name,
                   Owner.Email,
                   city__c,
                   MicrosoftEventId__c,
                   Status__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]);
    }

    private static Map<Id, List<MicrosoftGraphMeetingService.Participant>> getParticipantsByEventId(
        Map<Id, Event__c> eventsById
    ) {
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> result =
            initParticipantMap(eventsById.keySet());

        Map<Id, Set<String>> emailsByEventId = initEmailMap(eventsById.keySet());
        Map<Id, Boolean> hasTopSpeakerByEventId = getHasTopSpeakerByEventId(eventsById.keySet());

        addCommonParticipants(eventsById.keySet(), result, emailsByEventId, hasTopSpeakerByEventId);
        addRecordTypeSpecificParticipants(eventsById, result, emailsByEventId, hasTopSpeakerByEventId);

        return result;
    }

    private static Map<Id, List<MicrosoftGraphMeetingService.Participant>> initParticipantMap(Set<Id> eventIds) {
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> result =
            new Map<Id, List<MicrosoftGraphMeetingService.Participant>>();

        for (Id eventId : eventIds) {
            result.put(eventId, new List<MicrosoftGraphMeetingService.Participant>());
        }

        return result;
    }

    private static Map<Id, Set<String>> initEmailMap(Set<Id> eventIds) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();

        for (Id eventId : eventIds) {
            result.put(eventId, new Set<String>());
        }

        return result;
    }

    private static Map<Id, Boolean> getHasTopSpeakerByEventId(Set<Id> eventIds) {
        Map<Id, Boolean> result = new Map<Id, Boolean>();

        for (Id eventId : eventIds) {
            result.put(eventId, false);
        }

        for (SessionSpeakerProduct__c speakerLink : [
            SELECT Session__c,
                   SpeakerContact__r.JobTitle__c
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
            if (isTopSpeaker(speakerLink.SpeakerContact__r.JobTitle__c)) {
                result.put(speakerLink.Session__c, true);
            }
        }

        return result;
    }

    private static Boolean isTopSpeaker(String jobTitle) {
        if (String.isBlank(jobTitle)) {
            return true;
        }

        return jobTitle.trim().toLowerCase() != JOB_TITLE_SALES.toLowerCase();
    }

    // Ajoute les participants communs : speakers, assistants et users liés aux stratégies.
    private static void addCommonParticipants(
        Set<Id> eventIds,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Map<Id, Boolean> hasTopSpeakerByEventId
    ) {
        Map<String, Set<String>> strategyToUsernames = loadStrategyToUsernamesMap();

        Map<Id, Set<String>> usernamesByEventId = new Map<Id, Set<String>>();
        Set<String> allUsernames = new Set<String>();

        for (SessionSpeakerProduct__c speakerLink : [
            SELECT Session__c,
                   Strategy__r.Code__c,
                   SpeakerContact__r.Name,
                   SpeakerContact__r.Email,
                   SpeakerContact__r.JobTitle__c,
                   SpeakerContact__r.SpeakerAssistant__r.Name,
                   SpeakerContact__r.SpeakerAssistant__r.Email
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
            // Le speaker et son assistant restent toujours invités.
            addParticipant(
                participantsByEventId.get(speakerLink.Session__c),
                emailsByEventId.get(speakerLink.Session__c),
                speakerLink.SpeakerContact__r.Email,
                speakerLink.SpeakerContact__r.Name,
                false
            );

            addParticipant(
                participantsByEventId.get(speakerLink.Session__c),
                emailsByEventId.get(speakerLink.Session__c),
                speakerLink.SpeakerContact__r.SpeakerAssistant__r.Email,
                speakerLink.SpeakerContact__r.SpeakerAssistant__r.Name,
                false
            );

            // Les users par stratégie ne sont ajoutés que s'il y a un top speaker.
            if (hasTopSpeakerByEventId.get(speakerLink.Session__c) != true) {
                continue;
            }

            String strategyCode = speakerLink.Strategy__r == null
                ? null
                : speakerLink.Strategy__r.Code__c;

            Set<String> usernames = strategyToUsernames.get(normalizeKey(strategyCode));

            if (usernames == null || usernames.isEmpty()) {
                continue;
            }

            // On regroupe les usernames par événement pour éviter les doublons.
            if (!usernamesByEventId.containsKey(speakerLink.Session__c)) {
                usernamesByEventId.put(speakerLink.Session__c, new Set<String>());
            }

            usernamesByEventId.get(speakerLink.Session__c).addAll(usernames);
            allUsernames.addAll(usernames);
        }

        Map<String, User> usersByUsername = loadUsersByUsername(allUsernames);

        for (Id eventId : usernamesByEventId.keySet()) {
            for (String username : usernamesByEventId.get(eventId)) {
                User userRecord = usersByUsername.get(username);

                if (userRecord == null) {
                    continue;
                }

                // L'invitation est envoyée à l'email du User Salesforce trouvé.
                addParticipant(
                    participantsByEventId.get(eventId),
                    emailsByEventId.get(eventId),
                    userRecord.Email,
                    userRecord.Name,
                    false
                );
            }
        }
    }

    private static void addRecordTypeSpecificParticipants(
        Map<Id, Event__c> eventsById,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Map<Id, Boolean> hasTopSpeakerByEventId
    ) {
        for (Event__c eventRecord : eventsById.values()) {
            String recordTypeDeveloperName = eventRecord.RecordType.DeveloperName;

            if (recordTypeDeveloperName == RT_EVENT) {
                addEventParticipants(eventRecord, participantsByEventId, emailsByEventId, hasTopSpeakerByEventId);
            } else if (recordTypeDeveloperName == RT_MEETING_DAYS) {
                addMeetingDaysParticipants(eventRecord, participantsByEventId, emailsByEventId, hasTopSpeakerByEventId);
            } else if (recordTypeDeveloperName == RT_MEETING) {
                addMeetingParticipants(eventRecord, participantsByEventId, emailsByEventId);
            } else {
                System.debug('Unsupported Event__c RecordType: ' + recordTypeDeveloperName);
            }
        }
    }

    private static void addEventParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Map<Id, Boolean> hasTopSpeakerByEventId
    ) {
        addSalesTeamParticipants(eventRecord, participantsByEventId, emailsByEventId);

        if (hasTopSpeakerByEventId.get(eventRecord.Id) == true) {
            addNotificationConfigParticipants(eventRecord, META_COMMUNICATION, participantsByEventId, emailsByEventId);
            addNotificationConfigParticipants(eventRecord, META_LOCAL_MARKETING_EVENT_TEAM, participantsByEventId, emailsByEventId);
        }

        // addCRMParticipants(eventRecord, participantsByEventId, emailsByEventId);
    }

    private static void addMeetingDaysParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Map<Id, Boolean> hasTopSpeakerByEventId
    ) {
        addSalesTeamParticipants(eventRecord, participantsByEventId, emailsByEventId);
        addOrganizerParticipant(eventRecord, participantsByEventId, emailsByEventId, false);

        if (hasTopSpeakerByEventId.get(eventRecord.Id) == true) {
            addNotificationConfigParticipants(eventRecord, META_COMMUNICATION, participantsByEventId, emailsByEventId);
        }

        // addCRMParticipants(eventRecord, participantsByEventId, emailsByEventId);
    }

    private static void addMeetingParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        addSalesOwnerParticipant(eventRecord, participantsByEventId, emailsByEventId, false);
        addOwnerParticipant(eventRecord, participantsByEventId, emailsByEventId, false);

        // addCRMParticipants(eventRecord, participantsByEventId, emailsByEventId);
    }

    private static void addSalesTeamParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        if (eventRecord == null || String.isBlank(eventRecord.SalesTeam__c)) {
            return;
        }

        Map<String, BooklySalesTeamNotification__mdt> configByDeveloperName =
            BooklySalesTeamNotification__mdt.getAll();

        String developerName = toMetadataDeveloperName(eventRecord.SalesTeam__c);
        BooklySalesTeamNotification__mdt config = configByDeveloperName.get(developerName);

        if (config == null || String.isBlank(config.emailAddress__c)) {
            System.debug('No SalesTeam metadata found for: ' + eventRecord.SalesTeam__c);
            return;
        }

        for (String email : splitEmails(config.emailAddress__c)) {
            addParticipant(
                participantsByEventId.get(eventRecord.Id),
                emailsByEventId.get(eventRecord.Id),
                email,
                email,
                false
            );
        }
    }
    
    /*private static void addCRMParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        if (eventRecord == null || String.isBlank(eventRecord.SalesTeam__c)) {
            return;
        }

        Map<String, BooklySalesTeamNotification__mdt> configByDeveloperName =
            BooklySalesTeamNotification__mdt.getAll();

        String developerName = toMetadataDeveloperName(eventRecord.SalesTeam__c);
        BooklySalesTeamNotification__mdt config = configByDeveloperName.get(developerName);

        if (config == null || String.isBlank(config.emailAddressCRM__c)) {
            System.debug('No SalesTeam metadata found for: ' + eventRecord.SalesTeam__c);
            return;
        }

        for (String email : splitEmails(config.emailAddressCRM__c)) {
            addParticipant(
                participantsByEventId.get(eventRecord.Id),
                emailsByEventId.get(eventRecord.Id),
                email,
                email,
                false
            );
        }
    }*/

    private static void addParticipant(
        List<MicrosoftGraphMeetingService.Participant> participants,
        Set<String> existingEmails,
        String email,
        String name,
        Boolean optional
    ) {
        if (participants == null || existingEmails == null || String.isBlank(email)) {
            return;
        }

        String normalizedEmail = email.trim().toLowerCase();

        if (existingEmails.contains(normalizedEmail)) {
            return;
        }

        existingEmails.add(normalizedEmail);

        participants.add(
            new MicrosoftGraphMeetingService.Participant(
                email.trim(),
                String.isBlank(name) ? email.trim() : name.trim(),
                optional
            )
        );
    }

    private static MicrosoftGraphMeetingService.MeetingRequest buildMeetingRequest(
        Event__c eventRecord,
        List<MicrosoftGraphMeetingService.Participant> participants,
        Id templateId,
        String speakerInitials
    ) {
        MicrosoftGraphMeetingService.MeetingRequest request =
            new MicrosoftGraphMeetingService.MeetingRequest();

        String timeZone = String.isBlank(eventRecord.TimeZone__c)
            ? DEFAULT_TIME_ZONE
            : eventRecord.TimeZone__c;

        request.namedCredentialName = DEFAULT_NAMED_CREDENTIAL;
        request.subject = buildSubject(eventRecord, speakerInitials);
        request.templateId = templateId;
        request.relatedRecordId = eventRecord.Id;
        request.message = 'Below event details.';
        request.startDate = eventRecord.StartDate__c;
        request.startTime = eventRecord.StartTime__c;
        request.endDate = eventRecord.EndDate__c;
        request.endTime = eventRecord.EndTime__c;
        request.timeZone = timeZone;
        request.participants = participants;
        request.generateTeamsLink = shouldGenerateTeamsLink(eventRecord);

        return request;
    }

    private static Boolean shouldGenerateTeamsLink(Event__c eventRecord) {
        return false;
    }

    private static Id getEmailTemplateIdByDeveloperName(String developerName) {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            throw new IllegalArgumentException('EmailTemplate not found: ' + developerName);
        }

        return templates[0].Id;
    }

    private static String safeString(String value) {
        return String.isBlank(value) ? '' : value.trim();
    }

        // Charge le mapping Strategy Code -> usernames depuis BooklyStrategiesByUsers__mdt.
    private static Map<String, Set<String>> loadStrategyToUsernamesMap() {
        Map<String, Set<String>> result = new Map<String, Set<String>>();

        for (BooklyStrategiesByUsers__mdt config : BooklyStrategiesByUsers__mdt.getAll().values()) {
            if (String.isBlank(config.Username__c) || String.isBlank(config.StrategyCodes__c)) {
                continue;
            }

            String username = config.Username__c.trim();

            // StrategyCodes__c contient les codes séparés par des points-virgules.
            for (String strategyCode : config.StrategyCodes__c.split(';')) {
                String normalizedStrategy = normalizeKey(strategyCode);

                if (String.isBlank(normalizedStrategy)) {
                    continue;
                }

                if (!result.containsKey(normalizedStrategy)) {
                    result.put(normalizedStrategy, new Set<String>());
                }

                result.get(normalizedStrategy).add(username);
            }
        }

        return result;
    }

    // Charge les users actifs correspondant aux usernames déclarés dans le metadata.
    private static Map<String, User> loadUsersByUsername(Set<String> usernames) {
        Map<String, User> result = new Map<String, User>();

        if (usernames == null || usernames.isEmpty()) {
            return result;
        }

        for (User userRecord : [
            SELECT Id, Name, Email, Username, IsActive
            FROM User
            WHERE Username IN :usernames
            AND IsActive = true
            AND Email != null
        ]) {
            // La clé reste le Username pour matcher avec Username__c.
            result.put(userRecord.Username, userRecord);
        }

        return result;
    }

    private static String normalizeKey(String value) {
        return String.isBlank(value) ? null : value.trim().toLowerCase();
    }

    private static String toMetadataDeveloperName(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        return value.trim()
            .replace('&', 'and')
            .replaceAll('[^a-zA-Z0-9]+', '_')
            .replaceAll('^_+', '')
            .replaceAll('_+$', '');
    }

    private static List<String> splitEmails(String rawEmails) {
        List<String> result = new List<String>();

        if (String.isBlank(rawEmails)) {
            return result;
        }

        for (String email : rawEmails.split('[,;\\n\\r]+')) {
            if (!String.isBlank(email)) {
                result.add(email.trim());
            }
        }

        return result;
    }

    private static void addOrganizerParticipant(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Boolean optional
    ) {
        if (eventRecord == null || eventRecord.Organizer__r == null) {
            return;
        }

        addParticipant(
            participantsByEventId.get(eventRecord.Id),
            emailsByEventId.get(eventRecord.Id),
            eventRecord.Organizer__r.Email,
            eventRecord.Organizer__r.Name,
            optional
        );
    }

    private static void addSalesOwnerParticipant(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Boolean optional
    ) {
        if (eventRecord == null || eventRecord.SalesOwner__r == null) {
            return;
        }

        addParticipant(
            participantsByEventId.get(eventRecord.Id),
            emailsByEventId.get(eventRecord.Id),
            eventRecord.SalesOwner__r.Email,
            eventRecord.SalesOwner__r.Name,
            optional
        );
    }

    private static void addOwnerParticipant(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId,
        Boolean optional
    ) {
        if (eventRecord == null || eventRecord.Owner == null) {
            return;
        }

        addParticipant(
            participantsByEventId.get(eventRecord.Id),
            emailsByEventId.get(eventRecord.Id),
            eventRecord.Owner.Email,
            eventRecord.Owner.Name,
            optional
        );
    }

    private static void addNotificationConfigParticipants(
        Event__c eventRecord,
        String metadataDeveloperName,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        if (eventRecord == null || String.isBlank(metadataDeveloperName)) {
            return;
        }

        BooklyNotificationConfig__mdt config =
            BooklyNotificationConfig__mdt.getAll().get(metadataDeveloperName);

        if (config == null || String.isBlank(config.EmailAddresses__c)) {
            return;
        }

        for (String email : splitEmails(config.EmailAddresses__c)) {
            addParticipant(
                participantsByEventId.get(eventRecord.Id),
                emailsByEventId.get(eventRecord.Id),
                email,
                email,
                false
            );
        }
    }

    private static String buildSubject(Event__c eventRecord, String speakerInitials) {
        return joinNonBlank(
            new List<String>{
                SUBJECT_PREFIX,
                speakerInitials,
                eventRecord == null ? null : eventRecord.Title__c,
                eventRecord == null ? null : eventRecord.City__c
            },
            SUBJECT_SEPARATOR
        );
    }

    private static Map<Id, String> getSpeakerInitialsByEventId(Set<Id> eventIds) {
        Map<Id, Set<String>> initialsByEventId = new Map<Id, Set<String>>();

        if (eventIds == null || eventIds.isEmpty()) {
            return new Map<Id, String>();
        }

        for (SessionSpeakerProduct__c speakerLink : [
            SELECT Session__c, SpeakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
            if (!initialsByEventId.containsKey(speakerLink.Session__c)) {
                initialsByEventId.put(speakerLink.Session__c, new Set<String>());
            }

            String initials = getSpeakerInitials(speakerLink.SpeakerContact__r.Name);

            if (!String.isBlank(initials)) {
                initialsByEventId.get(speakerLink.Session__c).add(initials);
            }
        }

        Map<Id, String> result = new Map<Id, String>();

        for (Id eventId : initialsByEventId.keySet()) {
            List<String> values = new List<String>(initialsByEventId.get(eventId));
            values.sort();
            result.put(eventId, String.join(values, ','));
        }

        return result;
    }

    private static String getSpeakerInitials(String fullName) {
        if (String.isBlank(fullName)) {
            return null;
        }

        List<String> parts = fullName.trim().split('\\s+');

        if (parts.size() < 2) {
            return null;
        }

        String firstInitial = parts[0].substring(0, 1);
        String lastInitial = parts[parts.size() - 1].substring(0, 1);

        return (firstInitial + lastInitial).toUpperCase();
    }

    private static String joinNonBlank(List<String> values, String separator) {
        List<String> kept = new List<String>();

        for (String value : values) {
            if (!String.isBlank(value)) {
                kept.add(value.trim());
            }
        }

        return String.join(kept, separator);
    }
}