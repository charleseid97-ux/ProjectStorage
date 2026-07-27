public without sharing class BooklyModificationsManagement {
    
    public static Boolean isSspModificationNotificationRunning = false;
    public static Set<Id> sspModificationSessionIds = new Set<Id>();

    public static final String STALE_APPROVAL_MESSAGE =
        'This request has been updated since this approval email was sent. ' +
        'Please review the latest approval email, or open the record in Salesforce and approve it from there.';

    private static final String STATE_DIGEST_ALGORITHM = 'SHA-256';
    private static final Integer STATE_ID_LENGTH = 32;

    private static final String APPROVAL_TYPE_SPEAKER = 'Speaker';
    private static final String APPROVAL_TYPE_HOP = 'HOP';
    private static final String SPEAKER_APPROVAL_PROCESS_DEVNAME = 'SpeakerApproval';
    private static final String HOP_APPROVAL_PROCESS_DEVNAME = 'SpeakerApprovalHOP';

    private static final Set<String> APPROVAL_SENSITIVE_STATUSES = new Set<String>{
        customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM,
        customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS,
        customEventConstants.STATUS_FULLY_APPROVED,
        customEventConstants.STATUS_PARTIALLY_APPROVED,
        customEventConstants.STATUS_REJECTED
    };

    private static final Set<String> SPEAKER_APPROVAL_REPROCESS_STATUSES = new Set<String>{
        customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS,
        customEventConstants.STATUS_FULLY_APPROVED,
        customEventConstants.STATUS_PARTIALLY_APPROVED
    };

    public class ApprovalStateValidationResult {
        public Boolean isValid;
        public String message;

        // Builds a small result object used by approval entry points.
        public ApprovalStateValidationResult(Boolean isValidValue, String messageValue) {
            isValid = isValidValue;
            message = messageValue;
        }
    }

    private class TargetedApprovalRequest {
        public Id eventId;
        public Id speakerId;
        public Id sspId;
        public String approvalType;
        public String processDeveloperName;
        public String reason;
    }

    // Initializes ApprovalStateId__c for new Event__c records.
    public static void initializeApprovalStateIds(List<Event__c> events) {
        if (events == null || events.isEmpty()) return;

        for (Event__c eventRecord : events) {
            if (eventRecord == null) continue;

            // New requests must carry a state id in approval emails.
            if (String.isBlank(eventRecord.ApprovalStateId__c)) {
                eventRecord.ApprovalStateId__c = generateStateId(eventRecord.Id);
            }
        }
    }

    // Refreshes ApprovalStateId__c when an approval-sensitive Event__c state changes.
    public static void refreshApprovalStateIdsOnEventChange(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        if (newEvents == null || newEvents.isEmpty() || oldMap == null || oldMap.isEmpty()) return;

        for (Event__c newEvent : newEvents) {
            if (newEvent == null || newEvent.Id == null) continue;

            Event__c oldEvent = oldMap.get(newEvent.Id);
            if (oldEvent == null) continue;

            // A changed state invalidates approval links generated before the change.
            if (shouldRefreshEventState(newEvent, oldEvent)) {
                newEvent.ApprovalStateId__c = generateStateId(newEvent.Id);
            }
        }
    }

    // Validates that the approval link state still matches the current Event__c state.
    public static ApprovalStateValidationResult validateApprovalState(
        String rawRecordId,
        String stateIdFromLink
    ) {
        if (String.isBlank(rawRecordId)) {
            return new ApprovalStateValidationResult(true, null);
        }

        Id targetId;
        try {
            targetId = (Id) rawRecordId;
        } catch (Exception ex) {
            return new ApprovalStateValidationResult(true, null);
        }

        String currentStateId = loadCurrentApprovalStateId(targetId);

        // Legacy records without ApprovalStateId__c remain approvable.
        if (String.isBlank(currentStateId)) {
            return new ApprovalStateValidationResult(true, null);
        }

        if (normalizeStateId(currentStateId) == normalizeStateId(stateIdFromLink)) {
            return new ApprovalStateValidationResult(true, null);
        }

        return new ApprovalStateValidationResult(false, STALE_APPROVAL_MESSAGE);
    }

    // Synchronizes speaker approvals after a SessionSpeakerProduct__c insert.
    public static void handleSessionSpeakerProductInsert(List<SessionSpeakerProduct__c> newSsps) {
        refreshWaitingSpeakerApprovals(collectSessionIds(newSsps));
        resubmitHopApprovalsForInsertedSsps(newSsps);
        OperationLogService.flush();
    }

    // Registers SSP modified sessions for the current transaction.
    public static void registerSspModificationSessions(
        Map<Id, SessionSpeakerProduct__c> oldMap,
        Map<Id, SessionSpeakerProduct__c> newMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;

        for (Id sspId : newMap.keySet()) {
            SessionSpeakerProduct__c newSsp = newMap.get(sspId);
            SessionSpeakerProduct__c oldSsp = oldMap == null ? null : oldMap.get(sspId);

            // Keep the session marked until the end of the transaction.
            if (hasSpeakerApprovalImpact(newSsp, oldSsp)) {
                addSessionId(sspModificationSessionIds, newSsp);
                addSessionId(sspModificationSessionIds, oldSsp);
            }
        }
    }

    // Returns true when a generic presentation email must be skipped for modified SSP sessions.
    public static Boolean shouldSkipGenericPresentationRequest(List<SessionSpeakerProduct__c> ssps) {
        if (ssps == null || ssps.isEmpty() || sspModificationSessionIds.isEmpty()) {
            return false;
        }

        for (SessionSpeakerProduct__c ssp : ssps) {
            if (ssp != null && ssp.Session__c != null && sspModificationSessionIds.contains(ssp.Session__c)) {
                return true;
            }
        }

        return false;
    }

    // Synchronizes speaker approvals after an approval-impacting SessionSpeakerProduct__c update.
    public static void handleSessionSpeakerProductUpdate(
        Map<Id, SessionSpeakerProduct__c> oldMap,
        Map<Id, SessionSpeakerProduct__c> newMap
    ) {
        if (newMap == null || newMap.isEmpty()) return;

        Set<Id> impactedSessionIds = new Set<Id>();
        Map<String, List<SessionSpeakerProduct__c>> sspsByMessage = new Map<String, List<SessionSpeakerProduct__c>>();

        for (Id sspId : newMap.keySet()) {
            SessionSpeakerProduct__c newSsp = newMap.get(sspId);
            SessionSpeakerProduct__c oldSsp = oldMap == null ? null : oldMap.get(sspId);

            // Strategy, speaker and timing changes can change the approval content.
            if (hasSpeakerApprovalImpact(newSsp, oldSsp)) {
                addSessionId(impactedSessionIds, newSsp);
                addSessionId(impactedSessionIds, oldSsp);
                addSspModificationMessage(sspsByMessage, newSsp, oldSsp);
            }
        }

        refreshWaitingSpeakerApprovals(impactedSessionIds);
        resubmitTargetedApprovalsForSspChanges(oldMap, newMap);
        sendSspModificationAlerts(sspsByMessage);
        OperationLogService.flush();
    }

    // Synchronizes speaker approvals and sends an informative alert after a SessionSpeakerProduct__c delete.
    public static void handleSessionSpeakerProductDelete(List<SessionSpeakerProduct__c> oldSsps) {
        refreshWaitingSpeakerApprovals(collectSessionIds(oldSsps));
        sendSpeakerDeletedAlerts(oldSsps);
        OperationLogService.flush();
    }

    // Sends one informative email when a speaker is removed from an Event.
    private static void sendSpeakerDeletedAlerts(List<SessionSpeakerProduct__c> oldSsps) {
        if (oldSsps == null || oldSsps.isEmpty()) return;

        Map<Id, DeletedSpeakerAlertContext> contextByEventId = buildDeletedSpeakerAlertContext(oldSsps);
        if (contextByEventId.isEmpty()) return;

        for (Id eventId : contextByEventId.keySet()) {
            DeletedSpeakerAlertContext context = contextByEventId.get(eventId);
            Set<String> recipients = buildSpeakerDeletedRecipients(context);
            String message = buildSpeakerDeletedMessage(context.speakerNames);

            customEventNotificationManager.sendGenericBooklyNotification(
                eventId,
                recipients,
                'Update on existing request',
                message,
                'BooklySpeakerDeletedNotificationSent',
                context.sspIds
            );
        }
    }

    // Container used to aggregate deleted SSP data per Event.
    private class DeletedSpeakerAlertContext {
        public Id eventId;
        public Id organizerId;
        public Set<Id> speakerIds = new Set<Id>();
        public Set<Id> strategyIds = new Set<Id>();
        public Set<String> speakerNames = new Set<String>();
        public List<Id> sspIds = new List<Id>();
    }

    // Builds deleted speaker notification context from Trigger.old records.
    private static Map<Id, DeletedSpeakerAlertContext> buildDeletedSpeakerAlertContext(
        List<SessionSpeakerProduct__c> oldSsps
    ) {
        Map<Id, DeletedSpeakerAlertContext> contextByEventId = new Map<Id, DeletedSpeakerAlertContext>();
        Set<Id> eventIds = new Set<Id>();
        Set<Id> speakerIds = new Set<Id>();

        for (SessionSpeakerProduct__c oldSsp : oldSsps) {
            if (oldSsp == null || oldSsp.Session__c == null) continue;

            eventIds.add(oldSsp.Session__c);
            if (oldSsp.SpeakerContact__c != null) speakerIds.add(oldSsp.SpeakerContact__c);
        }

        Map<Id, Event__c> eventsById = loadEventsForSpeakerDeletedAlert(eventIds);
        Map<Id, Contact> speakersById = loadSpeakersForSpeakerDeletedAlert(speakerIds);

        for (SessionSpeakerProduct__c oldSsp : oldSsps) {
            if (oldSsp == null || oldSsp.Session__c == null) continue;

            if (!contextByEventId.containsKey(oldSsp.Session__c)) {
                DeletedSpeakerAlertContext context = new DeletedSpeakerAlertContext();
                context.eventId = oldSsp.Session__c;

                Event__c eventRecord = eventsById.get(oldSsp.Session__c);
                context.organizerId = eventRecord == null ? null : eventRecord.Organizer__c;

                contextByEventId.put(oldSsp.Session__c, context);
            }

            DeletedSpeakerAlertContext currentContext = contextByEventId.get(oldSsp.Session__c);
            if (oldSsp.Id != null) currentContext.sspIds.add(oldSsp.Id);
            if (oldSsp.Strategy__c != null) currentContext.strategyIds.add(oldSsp.Strategy__c);
            if (oldSsp.SpeakerContact__c != null) currentContext.speakerIds.add(oldSsp.SpeakerContact__c);

            Contact speaker = speakersById.get(oldSsp.SpeakerContact__c);
            currentContext.speakerNames.add(
                speaker == null || String.isBlank(speaker.Name)
                    ? 'A speaker'
                    : speaker.Name
            );
        }

        return contextByEventId;
    }

    // Loads Events needed for organizer recipients.
    private static Map<Id, Event__c> loadEventsForSpeakerDeletedAlert(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return new Map<Id, Event__c>();

        return new Map<Id, Event__c>([
            SELECT Id, Organizer__c, Organizer__r.Email
            FROM Event__c
            WHERE Id IN :eventIds
        ]);
    }

    // Loads speaker assistants needed for deleted speaker recipients.
    private static Map<Id, Contact> loadSpeakersForSpeakerDeletedAlert(Set<Id> speakerIds) {
        if (speakerIds == null || speakerIds.isEmpty()) return new Map<Id, Contact>();

        return new Map<Id, Contact>([
            SELECT Id, Name, SpeakerAssistant__c, SpeakerAssistant__r.Email
            FROM Contact
            WHERE Id IN :speakerIds
        ]);
    }

    // Builds recipients: product team, organizer and removed speaker assistants.
    private static Set<String> buildSpeakerDeletedRecipients(DeletedSpeakerAlertContext context) {
        Set<String> recipients = new Set<String>();
        if (context == null) return recipients;

        recipients.addAll(
            customEventNotificationManager.loadPresentationRecipientEmailsForStrategyIds(context.strategyIds)
        );

        if (context.organizerId != null) {
            for (User organizer : [
                SELECT Email
                FROM User
                WHERE Id = :context.organizerId
                AND IsActive = true
                AND Email != null
                LIMIT 1
            ]) {
                recipients.add(organizer.Email.trim());
            }
        }

        if (!context.speakerIds.isEmpty()) {
            for (Contact speaker : [
                SELECT SpeakerAssistant__r.Email
                FROM Contact
                WHERE Id IN :context.speakerIds
                AND SpeakerAssistant__c != null
            ]) {
                if (speaker.SpeakerAssistant__r != null && !String.isBlank(speaker.SpeakerAssistant__r.Email)) {
                    recipients.add(speaker.SpeakerAssistant__r.Email.trim());
                }
            }
        }

        return recipients;
    }

    // Builds the informative speaker deletion message.
    private static String buildSpeakerDeletedMessage(Set<String> speakerNames) {
        if (speakerNames == null || speakerNames.isEmpty()) {
            return 'A speaker has been removed from the request.';
        }

        List<String> names = new List<String>(speakerNames);
        names.sort();

        if (names.size() == 1) {
            return names[0] + ' has been removed from the request.';
        }

        return 'The following speakers have been removed from the request: ' + String.join(names, ', ') + '.';
    }

    // Checks whether an Event__c change must invalidate approval email links.
    private static Boolean shouldRefreshEventState(Event__c newEvent, Event__c oldEvent) {
        if (newEvent == null || oldEvent == null) return false;

        Boolean statusChangedToSensitiveStatus =
            newEvent.Status__c != oldEvent.Status__c &&
            isApprovalSensitiveStatus(newEvent.Status__c);

        Boolean changedWhileApprovalSensitive =
            (isApprovalSensitiveStatus(newEvent.Status__c) || isApprovalSensitiveStatus(oldEvent.Status__c)) &&
            hasApprovalSensitiveEventFieldChange(newEvent, oldEvent);

        return statusChangedToSensitiveStatus || changedWhileApprovalSensitive;
    }

    // Detects Event__c field changes that are rendered in approval emails or impact approvals.
    private static Boolean hasApprovalSensitiveEventFieldChange(Event__c newEvent, Event__c oldEvent) {
        return newEvent.Organizer__c != oldEvent.Organizer__c
            || newEvent.StartDate__c != oldEvent.StartDate__c
            || newEvent.EndDate__c != oldEvent.EndDate__c
            || newEvent.StartTime__c != oldEvent.StartTime__c
            || newEvent.EndTime__c != oldEvent.EndTime__c
            || newEvent.TimeZone__c != oldEvent.TimeZone__c
            || newEvent.City__c != oldEvent.City__c
            || newEvent.Country__c != oldEvent.Country__c
            || newEvent.LocationName__c != oldEvent.LocationName__c
            || newEvent.LocationAddress__c != oldEvent.LocationAddress__c
            || newEvent.LocationPostCode__c != oldEvent.LocationPostCode__c
            || newEvent.Title__c != oldEvent.Title__c
            || newEvent.Category__c != oldEvent.Category__c
            || newEvent.Format__c != oldEvent.Format__c
            || newEvent.SalesTeam__c != oldEvent.SalesTeam__c
            || newEvent.Company__c != oldEvent.Company__c
            || newEvent.AudienceCompany__c != oldEvent.AudienceCompany__c
            || newEvent.MeetingGoal__c != oldEvent.MeetingGoal__c
            || newEvent.MeetingBackground__c != oldEvent.MeetingBackground__c
            || newEvent.Description__c != oldEvent.Description__c
            || newEvent.SpeakersHTML__c != oldEvent.SpeakersHTML__c
            || newEvent.Speakers__c != oldEvent.Speakers__c;
    }

    // Checks whether the Event status can have an active or reusable approval email.
    private static Boolean isApprovalSensitiveStatus(String statusValue) {
        return !String.isBlank(statusValue) && APPROVAL_SENSITIVE_STATUSES.contains(statusValue);
    }

    // Loads the current Event__c ApprovalStateId__c for Event__c or EventSpeakerApprovals__c targets.
    private static String loadCurrentApprovalStateId(Id targetId) {
        if (targetId == null) return null;

        try {
            if (targetId.getSObjectType() == Event__c.SObjectType) {
                Event__c eventRecord = [
                    SELECT ApprovalStateId__c
                    FROM Event__c
                    WHERE Id = :targetId
                    LIMIT 1
                ];
                return eventRecord.ApprovalStateId__c;
            }

            if (targetId.getSObjectType() == EventSpeakerApprovals__c.SObjectType) {
                EventSpeakerApprovals__c approvalRecord = [
                    SELECT Event__r.ApprovalStateId__c
                    FROM EventSpeakerApprovals__c
                    WHERE Id = :targetId
                    LIMIT 1
                ];
                return approvalRecord.Event__r == null ? null : approvalRecord.Event__r.ApprovalStateId__c;
            }
        } catch (Exception ex) {
            return null;
        }

        return null;
    }

    // Refreshes approvals only when speaker approvals have already started.
    private static void refreshWaitingSpeakerApprovals(Set<Id> sessionIds) {
        Set<Id> waitingSessionIds = filterSessionsByStatus(
            sessionIds,
            new Set<String>{ customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS }
        );

        if (waitingSessionIds.isEmpty()) return;

        // Speaker approvals before Event Team approval are left to the normal lifecycle.
        customEventSpeakerApprovalService.refreshApprovalsFromSessions(waitingSessionIds);
    }

    // Keeps only sessions whose current Event__c status is in the provided statuses.
    private static Set<Id> filterSessionsByStatus(Set<Id> sessionIds, Set<String> statuses) {
        Set<Id> result = new Set<Id>();

        if (sessionIds == null || sessionIds.isEmpty() || statuses == null || statuses.isEmpty()) {
            return result;
        }

        for (Event__c eventRecord : [
            SELECT Id, Status__c
            FROM Event__c
            WHERE Id IN :sessionIds
        ]) {
            if (statuses.contains(eventRecord.Status__c)) {
                result.add(eventRecord.Id);
            }
        }

        return result;
    }

    // Adds the correct business alert message for a SessionSpeakerProduct__c modification.
    private static void addSspModificationMessage(
        Map<String, List<SessionSpeakerProduct__c>> sspsByMessage,
        SessionSpeakerProduct__c newSsp,
        SessionSpeakerProduct__c oldSsp
    ) {
        if (sspsByMessage == null || newSsp == null || oldSsp == null) return;

        String speakerName = loadSpeakerName(newSsp.SpeakerContact__c);

        // Speaking date change.
        if (hasSpeakingDateChange(newSsp, oldSsp)) {
            addSspForMessage(
                sspsByMessage,
                'The date of ' + speakerName + '\'s speech has changed.',
                newSsp
            );
        }

        // Speaking timing change.
        if (hasSpeakingTimeChange(newSsp, oldSsp)) {
            addSspForMessage(
                sspsByMessage,
                'The timing of ' + speakerName + '\'s speech has changed.',
                newSsp
            );
        }

        // Strategy / product change.
        if (newSsp.Strategy__c != oldSsp.Strategy__c) {
            addSspForMessage(
                sspsByMessage,
                'The strategy for ' + speakerName + '\'s speech has changed.',
                newSsp
            );
        }

        // Speaker replacement.
        if (newSsp.SpeakerContact__c != oldSsp.SpeakerContact__c) {
            addSspForMessage(
                sspsByMessage,
                'The speaker assigned to this speech has changed.',
                newSsp
            );
        }
    }

    // Groups modified SSP records by alert message.
    private static void addSspForMessage(
        Map<String, List<SessionSpeakerProduct__c>> sspsByMessage,
        String message,
        SessionSpeakerProduct__c ssp
    ) {
        if (sspsByMessage == null || String.isBlank(message) || ssp == null) return;

        if (!sspsByMessage.containsKey(message)) {
            sspsByMessage.put(message, new List<SessionSpeakerProduct__c>());
        }

        sspsByMessage.get(message).add(ssp);
    }

    // Sends one presentation alert per modification message.
    private static void sendSspModificationAlerts(
        Map<String, List<SessionSpeakerProduct__c>> sspsByMessage
    ) {
        if (sspsByMessage == null || sspsByMessage.isEmpty()) return;

        isSspModificationNotificationRunning = true;

        try {
            for (String message : sspsByMessage.keySet()) {
                List<SessionSpeakerProduct__c> ssps = sspsByMessage.get(message);
                logModificationNotificationInfo(message, ssps);
                customEventNotificationManager.requestPresentation(ssps, message);
            }
        } finally {
            isSspModificationNotificationRunning = false;
        }
    }

    // Resubmits HOP approval when a product is added after speaker approval lifecycle started.
    private static void resubmitHopApprovalsForInsertedSsps(List<SessionSpeakerProduct__c> newSsps) {
        Map<String, TargetedApprovalRequest> requestsByKey = collectHopApprovalRequestsForInsertedSsps(newSsps);
        if (requestsByKey.isEmpty()) return;

        processTargetedApprovalRequests(requestsByKey);
    }

    // Resubmits targeted approvals required by SSP modifications.
    private static void resubmitTargetedApprovalsForSspChanges(
        Map<Id, SessionSpeakerProduct__c> oldMap,
        Map<Id, SessionSpeakerProduct__c> newMap
    ) {
        Map<String, TargetedApprovalRequest> requestsByKey = collectTargetedApprovalRequests(oldMap, newMap);
        if (requestsByKey.isEmpty()) return;

        processTargetedApprovalRequests(requestsByKey);
    }

    // Creates or resets approvals, then submits them to the configured approval process.
    private static void processTargetedApprovalRequests(Map<String, TargetedApprovalRequest> requestsByKey) {
        if (requestsByKey == null || requestsByKey.isEmpty()) return;

        Map<Id, SessionSpeakerProduct__c> sspsById = loadSspsForTargetedApprovals(requestsByKey.values());
        Map<Id, Event__c> eventsById = loadEventsForTargetedApprovals(requestsByKey.values());
        Map<String, EventSpeakerApprovals__c> existingByKey = loadExistingApprovals(requestsByKey.keySet());

        List<EventSpeakerApprovals__c> approvalsToUpsert = new List<EventSpeakerApprovals__c>();
        Map<String, TargetedApprovalRequest> keptRequestsByKey = new Map<String, TargetedApprovalRequest>();

        for (String key : requestsByKey.keySet()) {
            TargetedApprovalRequest request = requestsByKey.get(key);
            Event__c eventRecord = eventsById.get(request.eventId);
            SessionSpeakerProduct__c ssp = sspsById.get(request.sspId);

            if (!canResubmitSpeakerApproval(eventRecord, request, ssp)) {
                continue;
            }

            EventSpeakerApprovals__c approvalRecord = buildTargetedApprovalRecord(
                request,
                ssp,
                existingByKey.get(key)
            );

            if (approvalRecord == null) {
                continue;
            }

            approvalsToUpsert.add(approvalRecord);
            keptRequestsByKey.put(key, request);
        }

        if (approvalsToUpsert.isEmpty()) return;

        upsert approvalsToUpsert Key__c;
        submitTargetedApprovals(approvalsToUpsert, keptRequestsByKey);
    }

    // Builds one request per targeted approval type and speaker.
    private static Map<String, TargetedApprovalRequest> collectTargetedApprovalRequests(
        Map<Id, SessionSpeakerProduct__c> oldMap,
        Map<Id, SessionSpeakerProduct__c> newMap
    ) {
        Map<String, TargetedApprovalRequest> requestsByKey = new Map<String, TargetedApprovalRequest>();
        if (newMap == null || newMap.isEmpty()) return requestsByKey;

        for (Id sspId : newMap.keySet()) {
            SessionSpeakerProduct__c newSsp = newMap.get(sspId);
            SessionSpeakerProduct__c oldSsp = oldMap == null ? null : oldMap.get(sspId);

            if (newSsp == null || oldSsp == null || newSsp.Session__c == null || newSsp.SpeakerContact__c == null) {
                continue;
            }

            // Timing/date changes require Speaker Assistant approval.
            if (hasSpeakingTimeChange(newSsp, oldSsp) || hasSpeakingDateChange(newSsp, oldSsp)) {
                addTargetedApprovalRequest(
                    requestsByKey,
                    newSsp,
                    APPROVAL_TYPE_SPEAKER,
                    SPEAKER_APPROVAL_PROCESS_DEVNAME,
                    'Speaker approval resubmitted because the speech timing/date changed.'
                );
            }

            // Strategy/product changes require Head of Product approval.
            if (newSsp.Strategy__c != oldSsp.Strategy__c) {
                addTargetedApprovalRequest(
                    requestsByKey,
                    newSsp,
                    APPROVAL_TYPE_HOP,
                    HOP_APPROVAL_PROCESS_DEVNAME,
                    'HOP approval resubmitted because the speech strategy changed.'
                );
            }
        }

        return requestsByKey;
    }

    // Builds HOP approval requests for new products added after approval lifecycle started.
    private static Map<String, TargetedApprovalRequest> collectHopApprovalRequestsForInsertedSsps(
        List<SessionSpeakerProduct__c> newSsps
    ) {
        Map<String, TargetedApprovalRequest> requestsByKey = new Map<String, TargetedApprovalRequest>();
        if (newSsps == null || newSsps.isEmpty()) return requestsByKey;

        for (SessionSpeakerProduct__c newSsp : newSsps) {
            if (newSsp == null || newSsp.Session__c == null || newSsp.SpeakerContact__c == null) {
                continue;
            }

            // A new SSP means a new product/strategy was added for this speaker.
            addTargetedApprovalRequest(
                requestsByKey,
                newSsp,
                APPROVAL_TYPE_HOP,
                HOP_APPROVAL_PROCESS_DEVNAME,
                'HOP approval resubmitted because a new speech product was added.'
            );
        }

        return requestsByKey;
    }

    // Adds one targeted approval request and deduplicates by final approval key.
    private static void addTargetedApprovalRequest(
        Map<String, TargetedApprovalRequest> requestsByKey,
        SessionSpeakerProduct__c ssp,
        String approvalType,
        String processDeveloperName,
        String reason
    ) {
        if (requestsByKey == null || ssp == null || String.isBlank(approvalType)) return;

        String key = buildApprovalKey(ssp.Session__c, ssp.SpeakerContact__c, approvalType);
        TargetedApprovalRequest request = new TargetedApprovalRequest();
        request.eventId = ssp.Session__c;
        request.speakerId = ssp.SpeakerContact__c;
        request.sspId = ssp.Id;
        request.approvalType = approvalType;
        request.processDeveloperName = processDeveloperName;
        request.reason = reason;

        requestsByKey.put(key, request);
    }

    // Loads SSP rows with relationship fields needed to build approvals.
    private static Map<Id, SessionSpeakerProduct__c> loadSspsForTargetedApprovals(
        List<TargetedApprovalRequest> requests
    ) {
        Set<Id> sspIds = new Set<Id>();
        for (TargetedApprovalRequest request : requests) {
            if (request != null && request.sspId != null) {
                sspIds.add(request.sspId);
            }
        }

        if (sspIds.isEmpty()) return new Map<Id, SessionSpeakerProduct__c>();

        return new Map<Id, SessionSpeakerProduct__c>([
            SELECT Id, Session__c, SpeakerContact__c,
                   SpeakerContact__r.Name, SpeakerContact__r.SpeakerAssistant__c,
                   Strategy__r.Name, Strategy__r.AssetClass__c,
                   Session__r.RecordType.Name,
                   Language__c, StartTime__c, EndTime__c
            FROM SessionSpeakerProduct__c
            WHERE Id IN :sspIds
        ]);
    }

    // Loads Events and keeps status checks centralized.
    private static Map<Id, Event__c> loadEventsForTargetedApprovals(
        List<TargetedApprovalRequest> requests
    ) {
        Set<Id> eventIds = new Set<Id>();
        for (TargetedApprovalRequest request : requests) {
            if (request != null && request.eventId != null) {
                eventIds.add(request.eventId);
            }
        }

        if (eventIds.isEmpty()) return new Map<Id, Event__c>();

        return new Map<Id, Event__c>([
            SELECT Id, Status__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]);
    }

    // Loads existing EventSpeakerApprovals__c records by Key__c.
    private static Map<String, EventSpeakerApprovals__c> loadExistingApprovals(Set<String> approvalKeys) {
        Map<String, EventSpeakerApprovals__c> existingByKey = new Map<String, EventSpeakerApprovals__c>();
        if (approvalKeys == null || approvalKeys.isEmpty()) return existingByKey;

        for (EventSpeakerApprovals__c approvalRecord : [
            SELECT Id, Key__c, Status__c
            FROM EventSpeakerApprovals__c
            WHERE Key__c IN :approvalKeys
        ]) {
            existingByKey.put(approvalRecord.Key__c, approvalRecord);
        }

        return existingByKey;
    }

    // Checks if the Event is already in a speaker approval lifecycle.
    private static Boolean canResubmitSpeakerApproval(
        Event__c eventRecord,
        TargetedApprovalRequest request,
        SessionSpeakerProduct__c ssp
    ) {
        if (eventRecord == null || request == null || ssp == null) return false;

        // Do not start speaker approvals before Event Team approval has reached speaker approval lifecycle.
        if (!SPEAKER_APPROVAL_REPROCESS_STATUSES.contains(eventRecord.Status__c)) {
            return false;
        }

        if (
            request.approvalType == APPROVAL_TYPE_SPEAKER &&
            (ssp.SpeakerContact__r == null || ssp.SpeakerContact__r.SpeakerAssistant__c == null)
        ) {
            logApprovalModification(
                OperationLogService.Level.WARN,
                request.eventId,
                'BooklyModificationApprovalSkipped',
                'Speaker approval was not resubmitted because the speaker assistant is missing.',
                request,
                null
            );
            return false;
        }

        return true;
    }

    // Builds or updates a targeted approval record.
    private static EventSpeakerApprovals__c buildTargetedApprovalRecord(
        TargetedApprovalRequest request,
        SessionSpeakerProduct__c ssp,
        EventSpeakerApprovals__c existing
    ) {
        if (request == null || ssp == null) return null;

        String key = buildApprovalKey(request.eventId, request.speakerId, request.approvalType);
        EventSpeakerApprovals__c approvalRecord;

        // Event__c is not reparentable on existing EventSpeakerApprovals__c records.
        if (existing == null) {
            approvalRecord = new EventSpeakerApprovals__c(
                Key__c = key,
                Event__c = request.eventId,
                Speaker__c = request.speakerId,
                approvalType__c = request.approvalType
            );
        } else {
            approvalRecord = new EventSpeakerApprovals__c(
                Id = existing.Id,
                Key__c = existing.Key__c
            );
        }

        // Only update business fields required for the new approval round.
        approvalRecord.Status__c = customEventConstants.APPROVAL_STATUS_SUBMITTED;
        approvalRecord.Summary__c = ssp.Strategy__r == null ? null : ssp.Strategy__r.Name;
        approvalRecord.start__c = ssp.StartTime__c;
        approvalRecord.end__c = ssp.EndTime__c;
        approvalRecord.Name = buildTargetedApprovalName(request, ssp);
        approvalRecord.ApproverUser__c = request.approvalType == APPROVAL_TYPE_SPEAKER
            ? ssp.SpeakerContact__r.SpeakerAssistant__c
            : null;

        return approvalRecord;
    }

    // Creates a short approval name under the Salesforce Name field limit.
    private static String buildTargetedApprovalName(TargetedApprovalRequest request, SessionSpeakerProduct__c ssp) {
        String value = request.approvalType + ' - ' +
            (ssp.Strategy__r == null ? '' : ssp.Strategy__r.Name) + ' - ' +
            (ssp.SpeakerContact__r == null ? '' : ssp.SpeakerContact__r.Name);

        return trimTo(value, 80);
    }

    // Submits the targeted approval records and logs each notification attempt.
    private static void submitTargetedApprovals(
        List<EventSpeakerApprovals__c> approvals,
        Map<String, TargetedApprovalRequest> requestsByKey
    ) {
        if (approvals == null || approvals.isEmpty()) return;

        Set<Id> approvalIds = new Set<Id>();
        for (EventSpeakerApprovals__c approvalRecord : approvals) {
            if (approvalRecord.Id != null) {
                approvalIds.add(approvalRecord.Id);
            }
        }

        Set<Id> pendingApprovalIds = loadPendingApprovalTargetIds(approvalIds);

        for (EventSpeakerApprovals__c approvalRecord : approvals) {
            if (approvalRecord == null || approvalRecord.Id == null) continue;

            TargetedApprovalRequest request = requestsByKey.get(approvalRecord.Key__c);
            if (request == null) continue;

            if (pendingApprovalIds.contains(approvalRecord.Id)) {
                logApprovalModification(
                    OperationLogService.Level.INFO,
                    request.eventId,
                    'BooklyModificationApprovalAlreadyPending',
                    request.reason + ' Existing approval process is already pending.',
                    request,
                    approvalRecord.Id
                );
                continue;
            }

            try {
                Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
                submitRequest.setObjectId(approvalRecord.Id);
                submitRequest.setProcessDefinitionNameOrId(request.processDeveloperName);
                submitRequest.setComments(request.reason);

                Approval.ProcessResult result = Approval.process(submitRequest);

                if (result.isSuccess()) {
                    logApprovalModification(
                        OperationLogService.Level.INFO,
                        request.eventId,
                        'BooklyModificationApprovalResubmitted',
                        request.reason,
                        request,
                        approvalRecord.Id
                    );
                    continue;
                }

                logApprovalModification(
                    OperationLogService.Level.ERROR,
                    request.eventId,
                    'BooklyModificationApprovalSubmitFailed',
                    'Unable to resubmit approval: ' + JSON.serialize(result.getErrors()),
                    request,
                    approvalRecord.Id
                );
            } catch (Exception ex) {
                logApprovalModification(
                    OperationLogService.Level.ERROR,
                    request.eventId,
                    'BooklyModificationApprovalSubmitException',
                    'Unexpected error while resubmitting approval: ' + ex.getMessage(),
                    request,
                    approvalRecord.Id
                );
            }
        }
    }

    // Loads approval targets already pending to avoid duplicate Approval.process calls.
    private static Set<Id> loadPendingApprovalTargetIds(Set<Id> approvalIds) {
        Set<Id> pendingIds = new Set<Id>();
        if (approvalIds == null || approvalIds.isEmpty()) return pendingIds;

        for (ProcessInstanceWorkitem workItem : [
            SELECT ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId IN :approvalIds
        ]) {
            if (workItem.ProcessInstance != null && workItem.ProcessInstance.TargetObjectId != null) {
                pendingIds.add(workItem.ProcessInstance.TargetObjectId);
            }
        }

        return pendingIds;
    }

    // Logs modification notification requests before email delivery.
    private static void logModificationNotificationInfo(String message, List<SessionSpeakerProduct__c> ssps) {
        Set<Id> eventIds = new Set<Id>();
        List<Id> sspIds = new List<Id>();

        if (ssps != null) {
            for (SessionSpeakerProduct__c ssp : ssps) {
                if (ssp == null) continue;
                if (ssp.Session__c != null) eventIds.add(ssp.Session__c);
                if (ssp.Id != null) sspIds.add(ssp.Id);
            }
        }

        for (Id eventId : eventIds) {
            OperationLogService.Entry entry = new OperationLogService.Entry();
            entry.level = OperationLogService.Level.INFO;
            entry.sourceRecordId = String.valueOf(eventId);
            entry.sourceObjectApiName = 'Event__c';
            entry.operation = 'BooklyModificationNotificationRequested';
            entry.message = message;
            entry.contextJson = JSON.serialize(new Map<String, Object>{
                'sessionSpeakerProductIds' => sspIds,
                'notificationMessage' => message
            });
            entry.apexClass = 'BooklyModificationsManagement';
            entry.methodName = 'sendSspModificationAlerts';

            OperationLogService.log(entry);
        }
    }

    // Logs targeted approval submission and notification operations.
    private static void logApprovalModification(
        OperationLogService.Level level,
        Id eventId,
        String operation,
        String message,
        TargetedApprovalRequest request,
        Id approvalId
    ) {
        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = level;
        entry.sourceRecordId = eventId == null ? null : String.valueOf(eventId);
        entry.sourceObjectApiName = 'Event__c';
        entry.operation = operation;
        entry.message = message;
        entry.contextJson = JSON.serialize(new Map<String, Object>{
            'eventSpeakerApprovalId' => approvalId,
            'sessionSpeakerProductId' => request == null ? null : request.sspId,
            'speakerId' => request == null ? null : request.speakerId,
            'approvalType' => request == null ? null : request.approvalType,
            'processDeveloperName' => request == null ? null : request.processDeveloperName
        });
        entry.apexClass = 'BooklyModificationsManagement';
        entry.methodName = 'resubmitTargetedApprovalsForSspChanges';

        OperationLogService.log(entry);
    }

    // Loads a speaker name used in modification alert messages.
    private static String loadSpeakerName(Id speakerContactId) {
        if (speakerContactId == null) {
            return 'the speaker';
        }

        List<Contact> speakers = [
            SELECT Name
            FROM Contact
            WHERE Id = :speakerContactId
            LIMIT 1
        ];

        return speakers.isEmpty() || String.isBlank(speakers[0].Name)
            ? 'the speaker'
            : speakers[0].Name;
    }

    // Detects SessionSpeakerProduct__c changes that can impact speaker approval content.
    private static Boolean hasSpeakerApprovalImpact(
        SessionSpeakerProduct__c newSsp,
        SessionSpeakerProduct__c oldSsp
    ) {
        if (newSsp == null) return false;
        if (oldSsp == null) return true;

        return newSsp.Session__c != oldSsp.Session__c
            || newSsp.SpeakerContact__c != oldSsp.SpeakerContact__c
            || newSsp.Strategy__c != oldSsp.Strategy__c
            || newSsp.Language__c != oldSsp.Language__c
            || newSsp.PresentationStatus__c != oldSsp.PresentationStatus__c
            || hasSpeakingTimeChange(newSsp, oldSsp)
            || hasSpeakingDateChange(newSsp, oldSsp);
    }

    // Detects speaking time changes.
    private static Boolean hasSpeakingTimeChange(
        SessionSpeakerProduct__c newSsp,
        SessionSpeakerProduct__c oldSsp
    ) {
        if (newSsp == null || oldSsp == null) return false;

        return newSsp.StartTime__c != oldSsp.StartTime__c
            || newSsp.EndTime__c != oldSsp.EndTime__c;
    }

    // Detects optional speaking date fields without creating a hard metadata dependency.
    private static Boolean hasSpeakingDateChange(
        SessionSpeakerProduct__c newSsp,
        SessionSpeakerProduct__c oldSsp
    ) {
        return hasDynamicFieldChanged(newSsp, oldSsp, 'StartDate__c')
            || hasDynamicFieldChanged(newSsp, oldSsp, 'EndDate__c')
            || hasDynamicFieldChanged(newSsp, oldSsp, 'startDate__c')
            || hasDynamicFieldChanged(newSsp, oldSsp, 'endDate__c');
    }

    // Compares optional fields only when they exist on SessionSpeakerProduct__c.
    private static Boolean hasDynamicFieldChanged(
        SObject newRecord,
        SObject oldRecord,
        String fieldApiName
    ) {
        if (newRecord == null || oldRecord == null || String.isBlank(fieldApiName)) return false;
        if (!Schema.SObjectType.SessionSpeakerProduct__c.fields.getMap().containsKey(fieldApiName)) return false;

        return newRecord.get(fieldApiName) != oldRecord.get(fieldApiName);
    }

    // Collects Session__c values from SessionSpeakerProduct__c records.
    private static Set<Id> collectSessionIds(List<SessionSpeakerProduct__c> ssps) {
        Set<Id> sessionIds = new Set<Id>();

        if (ssps == null || ssps.isEmpty()) return sessionIds;

        for (SessionSpeakerProduct__c ssp : ssps) {
            addSessionId(sessionIds, ssp);
        }

        return sessionIds;
    }

    // Adds one Session__c value when it is available.
    private static void addSessionId(Set<Id> sessionIds, SessionSpeakerProduct__c ssp) {
        if (sessionIds == null || ssp == null || ssp.Session__c == null) return;

        sessionIds.add(ssp.Session__c);
    }

    // Builds the EventSpeakerApprovals__c external key used by existing approval sync logic.
    private static String buildApprovalKey(Id eventId, Id speakerId, String approvalType) {
        return String.valueOf(eventId) + '-' + String.valueOf(speakerId) + '-' + approvalType;
    }

    // Normalizes URL and record state values before comparison.
    private static String normalizeStateId(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    // Generates a compact random state id used to detect stale approval links.
    private static String generateStateId(Id eventId) {
        String seed = String.valueOf(eventId)
            + ':' + String.valueOf(Datetime.now().getTime())
            + ':' + String.valueOf(Crypto.getRandomInteger());

        String digest = EncodingUtil.convertToHex(
            Crypto.generateDigest(STATE_DIGEST_ALGORITHM, Blob.valueOf(seed))
        );

        return digest.substring(0, STATE_ID_LENGTH);
    }

    // Trims long values before writing to Salesforce text fields.
    private static String trimTo(String value, Integer maxLength) {
        if (String.isBlank(value) || maxLength == null || maxLength <= 0) {
            return value;
        }

        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}