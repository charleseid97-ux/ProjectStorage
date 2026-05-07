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

    private static final String META_COMMUNICATION = 'Communication';
    private static final String META_LOCAL_MARKETING_EVENT_TEAM = 'LocalMarketing';

    private final Set<Id> eventIds;

    public BooklyMeetingInvitationQueueable(Set<Id> eventIds) {
        this.eventIds = eventIds == null ? new Set<Id>() : new Set<Id>(eventIds);
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

            if (participants == null || participants.isEmpty()) {
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

            MicrosoftGraphMeetingService.MeetingResponse response =
                MicrosoftGraphMeetingService.createTeamsMeeting(request);

            System.debug('Bookly meeting response for Event__c ' + eventId + ': ' + JSON.serialize(response));

            /*
            if (response.success == true && !String.isBlank(response.eventId)) {
                eventsToUpdate.add(new Event__c(
                    Id = eventId,
                    Microsoft_Event_Id__c = response.eventId
                ));
            }
            */
        }

        if (!eventsToUpdate.isEmpty()) {
            update eventsToUpdate;
        }
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
                   city__c
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

        addCommonParticipants(eventsById.keySet(), result, emailsByEventId);
        addRecordTypeSpecificParticipants(eventsById, result, emailsByEventId);

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

    private static void addCommonParticipants(
        Set<Id> eventIds,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        Map<String, String> strategyToGroupName = loadStrategyToGroupNameMap();

        Map<Id, Set<String>> groupNamesByEventId = new Map<Id, Set<String>>();
        Set<String> allGroupNames = new Set<String>();

        for (SessionSpeakerProduct__c speakerLink : [
            SELECT Session__c,
                   Strategy__r.Code__c,
                   SpeakerContact__r.Name,
                   SpeakerContact__r.Email,
                   SpeakerContact__r.SpeakerAssistant__r.Name,
                   SpeakerContact__r.SpeakerAssistant__r.Email
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
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

            String strategyName = speakerLink.Strategy__r == null
                ? null
                : speakerLink.Strategy__r.Code__c;
            System.debug('strategyName : '+strategyName);

            String groupName = strategyToGroupName.get(normalizeKey(strategyName));
            System.debug('groupName : '+groupName);

            if (String.isBlank(groupName)) {
                continue;
            }

            if (!groupNamesByEventId.containsKey(speakerLink.Session__c)) {
                groupNamesByEventId.put(speakerLink.Session__c, new Set<String>());
            }

            groupNamesByEventId.get(speakerLink.Session__c).add(groupName);
            allGroupNames.add(groupName);
        }

        Map<String, List<User>> usersByGroupName = loadUsersByGroupName(allGroupNames);

        for (Id eventId : groupNamesByEventId.keySet()) {
            for (String groupName : groupNamesByEventId.get(eventId)) {
                List<User> users = usersByGroupName.get(groupName);

                if (users == null) {
                    continue;
                }

                for (User userRecord : users) {
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
    }

    private static void addRecordTypeSpecificParticipants(
        Map<Id, Event__c> eventsById,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        for (Event__c eventRecord : eventsById.values()) {
            String recordTypeDeveloperName = eventRecord.RecordType.DeveloperName;

            if (recordTypeDeveloperName == RT_EVENT) {
                addEventParticipants(eventRecord, participantsByEventId, emailsByEventId);
            } else if (recordTypeDeveloperName == RT_MEETING_DAYS) {
                addMeetingDaysParticipants(eventRecord, participantsByEventId, emailsByEventId);
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
        Map<Id, Set<String>> emailsByEventId
    ) {
        addSalesTeamParticipants(eventRecord, participantsByEventId, emailsByEventId);
        addNotificationConfigParticipants(eventRecord, META_COMMUNICATION, participantsByEventId, emailsByEventId);
        addNotificationConfigParticipants(eventRecord, META_LOCAL_MARKETING_EVENT_TEAM, participantsByEventId, emailsByEventId);
        addCRMParticipants(eventRecord, participantsByEventId, emailsByEventId);

    }

    private static void addMeetingDaysParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        addSalesTeamParticipants(eventRecord, participantsByEventId, emailsByEventId);
        addOrganizerParticipant(eventRecord, participantsByEventId, emailsByEventId, false);
        addNotificationConfigParticipants(eventRecord, META_COMMUNICATION, participantsByEventId, emailsByEventId);
        addCRMParticipants(eventRecord, participantsByEventId, emailsByEventId);
    }

    private static void addMeetingParticipants(
        Event__c eventRecord,
        Map<Id, List<MicrosoftGraphMeetingService.Participant>> participantsByEventId,
        Map<Id, Set<String>> emailsByEventId
    ) {
        addSalesOwnerParticipant(eventRecord, participantsByEventId, emailsByEventId, false);
        addOwnerParticipant(eventRecord, participantsByEventId, emailsByEventId, false);
        addCRMParticipants(eventRecord, participantsByEventId, emailsByEventId);
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

    private static void addCRMParticipants(
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
    }

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

    private static Map<String, String> loadStrategyToGroupNameMap() {
        Map<String, String> result = new Map<String, String>();

        for (strategyNotificationGroups__mdt config : strategyNotificationGroups__mdt.getAll().values()) {
            if (String.isBlank(config.strategies__c) || String.isBlank(config.userGroupName__c)) {
                continue;
            }

            for (String strategyName : config.strategies__c.split(',')) {
                String normalizedStrategy = normalizeKey(strategyName);

                if (!String.isBlank(normalizedStrategy)) {
                    result.put(normalizedStrategy, config.userGroupName__c.trim());
                }
            }
        }

        return result;
    }

    private static Map<String, List<User>> loadUsersByGroupName(Set<String> groupNames) {
        Map<String, List<User>> result = new Map<String, List<User>>();

        if (groupNames == null || groupNames.isEmpty()) {
            return result;
        }

        for (String groupName : groupNames) {
            result.put(groupName, new List<User>());
        }

        Map<Id, String> groupNameById = new Map<Id, String>();

        for (Group groupRecord : [
            SELECT Id, DeveloperName
            FROM Group
            WHERE DeveloperName IN :groupNames
        ]) {
            groupNameById.put(groupRecord.Id, groupRecord.DeveloperName);
        }

        if (groupNameById.isEmpty()) {
            return result;
        }

        Set<Id> userIds = new Set<Id>();
        List<GroupMember> groupMembers = [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :groupNameById.keySet()
        ];

        for (GroupMember member : groupMembers) {
            if (member.UserOrGroupId != null && String.valueOf(member.UserOrGroupId).startsWith('005')) {
                userIds.add(member.UserOrGroupId);
            }
        }

        if (userIds.isEmpty()) {
            return result;
        }

        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Name, Email, IsActive
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            AND Email != null
        ]);

        for (GroupMember member : groupMembers) {
            User userRecord = usersById.get(member.UserOrGroupId);

            if (userRecord == null) {
                continue;
            }

            String groupName = groupNameById.get(member.GroupId);

            if (!String.isBlank(groupName) && result.containsKey(groupName)) {
                result.get(groupName).add(userRecord);
            }
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