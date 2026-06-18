// Runs without sharing intentionally because notification delivery must not depend on
// the triggering user's access to Users, Contacts or recipient email fields.
public without sharing class customEventNotificationManager {

    private static String SUBJECT_PLACEHOLDER = '[!subject]';
    private static String MESSAGE_PLACEHOLDER = '[!message]';
    private static String PRESENTATION_GLOBAL_GROUP = 'BooklyAlertProductAll';
    // Lance l'envoi des demandes de présentation selon les stratégies configurées.
    public static void requestPresentation(List<SessionSpeakerProduct__c> ssps) {

        System.debug('NOTIF STEP 1 - requestPresentation START, SSP count = ' + (ssps == null ? 0 : ssps.size()));

        try {

            if (ssps == null || ssps.isEmpty()) {
                System.debug('NOTIF STOP - no SSP provided');

                // Warning non bloquant : aucune demande de présentation à traiter.
                logPresentationRequest(
                    OperationLogService.Level.WARN,
                    null,
                    'PresentationRequestSkipped',
                    'No SessionSpeakerProduct__c provided.',
                    null,
                    null,
                    null,
                    null
                );

                return;
            }

            Map<String, Set<String>> strategyToUsernames = loadStrategyToUsernamesMap();
            System.debug('NOTIF STEP 2 - strategyToUsernames map = ' + strategyToUsernames);

            if (strategyToUsernames.isEmpty()) {
                System.debug('NOTIF WARN - no metadata configuration found');

                // Warning non bloquant : le groupe global peut encore être notifié.
                logPresentationRequest(
                    OperationLogService.Level.WARN,
                    null,
                    'PresentationRequestMetadataMissing',
                    'No BooklyStrategiesByUsers__mdt configuration found. Global group will still be checked.',
                    null,
                    null,
                    null,
                    null
                );
            }

            Map<String, List<SessionSpeakerProduct__c>> sspsByUsername = mapSspsToUsernames(ssps, strategyToUsernames);

            // Le groupe global reçoit toutes les présentations, même sans match metadata.
            addGlobalPresentationGroupRecipients(ssps, sspsByUsername);

            if (sspsByUsername.isEmpty()) {
                System.debug('NOTIF STOP - no username matched and no global group recipient found');

                // Warning non bloquant : aucun destinataire spécifique ou global n'a été trouvé.
                logPresentationRequest(
                    OperationLogService.Level.WARN,
                    null,
                    'PresentationRequestNoMatch',
                    'No username matched the SSP Strategy Code and no active user was found in BooklyAlertProductAll.',
                    null,
                    null,
                    null,
                    null
                );

                return;
            }

            Set<String> usernames = new Set<String>(sspsByUsername.keySet());
            System.debug('NOTIF STEP 3 - final usernames = ' + usernames);

            Map<String, User> usersByUsername = loadUsersByUsername(usernames);            
            System.debug('NOTIF STEP 4 - usersByUsername = ' + usersByUsername);

            if (usersByUsername.isEmpty()) {
                System.debug('NOTIF STOP - no users found');

                // Erreur bloquante : aucun User actif avec email trouvé.
                logPresentationRequest(
                    OperationLogService.Level.ERROR,
                    null,
                    'PresentationRequestNoActiveUser',
                    'No active Salesforce User with email found for configured usernames.',
                    usernames,
                    null,
                    collectPresentationSspIds(sspsByUsername),
                    null
                );

                return;
            }

            sendPresentationEmails(sspsByUsername, usersByUsername);

            System.debug('NOTIF END - requestPresentation FINISHED');
        } catch (Exception e) {

            // Erreur bloquante inattendue pendant le traitement complet.
            logPresentationRequest(
                OperationLogService.Level.ERROR,
                null,
                'PresentationRequestUnexpectedError',
                'Unexpected error while processing presentation request notifications.',
                null,
                null,
                null,
                e
            );
        } finally {
            OperationLogService.flush();
        }



        System.debug('NOTIF END - requestPresentation FINISHED');
    }




    // Ajoute les users actifs du groupe global à toutes les demandes de présentation.
    private static void addGlobalPresentationGroupRecipients(
        List<SessionSpeakerProduct__c> ssps,
        Map<String, List<SessionSpeakerProduct__c>> sspsByUsername
    ) {

        if (ssps == null || ssps.isEmpty() || sspsByUsername == null) {
            return;
        }

        // Charge le groupe global depuis son DeveloperName.
        List<Group> groups = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :PRESENTATION_GLOBAL_GROUP
            LIMIT 1
        ];

        if (groups.isEmpty()) {
            System.debug('NOTIF GLOBAL GROUP SKIP - group not found: ' + PRESENTATION_GLOBAL_GROUP);
            return;
        }

        Set<Id> userIds = new Set<Id>();

        // Collecte les membres directs du groupe global.
        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :groups[0].Id
        ]) {
            userIds.add(gm.UserOrGroupId);
        }

        if (userIds.isEmpty()) {
            System.debug('NOTIF GLOBAL GROUP SKIP - no member found');
            return;
        }

        // Recharge tous les SSP pour avoir les champs nécessaires au template.
        List<SessionSpeakerProduct__c> allSsps = [
            SELECT Id, session__c, Strategy__r.Name,Strategy__r.Code__c, speakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Id IN :new Map<Id, SessionSpeakerProduct__c>(ssps).keySet()
            AND session__c != null
        ];

        if (allSsps.isEmpty()) {
            return;
        }

        // Ajoute toutes les présentations à chaque user actif du groupe global.
        for (User u : [
            SELECT Id, Username, Email, IsActive
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            AND Email != null
        ]) {

            if (!sspsByUsername.containsKey(u.Username)) {
                sspsByUsername.put(u.Username, new List<SessionSpeakerProduct__c>());
            }

            sspsByUsername.get(u.Username).addAll(allSsps);
        }
    }

        // Charge le mapping Strategy Code -> usernames depuis BooklyStrategiesByUsers__mdt.
    public static Map<String, Set<String>> loadStrategyToUsernamesMap() {

        Map<String, Set<String>> out = new Map<String, Set<String>>();

        // Chaque ligne metadata associe un username à une liste de strategy codes.
        for (BooklyStrategiesByUsers__mdt cfg : BooklyStrategiesByUsers__mdt.getAll().values()) {

            if (String.isBlank(cfg.Username__c) || String.isBlank(cfg.StrategyCodes__c)) {
                continue;
            }

            String username = cfg.Username__c.trim();

            // StrategyCodes__c contient les codes séparés par des points-virgules.
            for (String strategyCode : cfg.StrategyCodes__c.split(';')) {

                String s = String.isBlank(strategyCode) ? null : strategyCode.trim().toLowerCase();

                if (String.isBlank(s)) {
                    continue;
                }

                if (!out.containsKey(s)) {
                    out.put(s, new Set<String>());
                }

                out.get(s).add(username);
            }
        }

        return out;
    }


    // Mappe les SSP aux usernames configurés pour leur Strategy Code.
    public static Map<String, List<SessionSpeakerProduct__c>> mapSspsToUsernames(
        List<SessionSpeakerProduct__c> ssps,
        Map<String, Set<String>> strategyToUsernames
    ) {

        Map<String, List<SessionSpeakerProduct__c>> result = new Map<String, List<SessionSpeakerProduct__c>>();
        Set<String> missingStrategyCodes = new Set<String>();
        List<Id> missingStrategySspIds = new List<Id>();

        // Recharge les SSP pour récupérer la stratégie et le speaker.
        for (SessionSpeakerProduct__c ssp : [
            SELECT Id, session__c, Strategy__r.Name,Strategy__r.Code__c, speakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Id IN :new Map<Id, SessionSpeakerProduct__c>(ssps).keySet()
        ]) {

            String strategyCode = (ssp.Strategy__r != null) ? ssp.Strategy__r.Code__c : null;

            if (String.isBlank(strategyCode) || ssp.session__c == null) {
                continue;
            }

            Set<String> usernames = strategyToUsernames.get(strategyCode.trim().toLowerCase());

            if (usernames == null || usernames.isEmpty()) {

                // Warning traité une seule fois après la boucle.
                missingStrategyCodes.add(strategyCode.trim());
                missingStrategySspIds.add(ssp.Id);
                continue;
            }

            // Ajoute le SSP à chaque username configuré pour cette stratégie.
            for (String username : usernames) {

                if (String.isBlank(username)) {
                    continue;
                }

                if (!result.containsKey(username)) {
                    result.put(username, new List<SessionSpeakerProduct__c>());
                }

                result.get(username).add(ssp);
            }
        }

        if (!missingStrategyCodes.isEmpty()) {

            List<String> missingStrategies = new List<String>(missingStrategyCodes);
            missingStrategies.sort();

            // Warning non bloquant : le groupe global recevra quand même ces présentations.
            logPresentationRequest(
                OperationLogService.Level.WARN,
                null,
                'PresentationRequestStrategyNotMapped',
                'No username configured in BooklyStrategiesByUsers__mdt for Strategy Code(s): ' + String.join(missingStrategies, ', '),
                null,
                null,
                missingStrategySspIds,
                null
            );
        }

        return result;
    }


    // Charge les users actifs correspondant aux usernames à notifier.
    public static Map<String, User> loadUsersByUsername(Set<String> usernames) {

        Map<String, User> out = new Map<String, User>();

        if (usernames == null || usernames.isEmpty()) {
            return out;
        }

        // Charge uniquement les users actifs avec email.
        for (User u : [
            SELECT Id, Email, Username, IsActive
            FROM User
            WHERE Username IN :usernames
            AND IsActive = true
            AND Email != null
        ]) {
            out.put(u.Username, u);
        }

        return out;
    }


        /**
     * Build and send one email per user with all related presentation requests
     */
    public static void sendPresentationEmails(
        Map<String, List<SessionSpeakerProduct__c>> sspsByUsername,
        Map<String, User> usersByUsername
    ) {

        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'PresentationRequest_VF'
            LIMIT 1
        ];

        Map<Id, User> uniqueUsersById = new Map<Id, User>();
        Map<Id, SessionSpeakerProduct__c> uniqueSspsById = new Map<Id, SessionSpeakerProduct__c>();
        Map<String, Set<String>> strategiesByUsername = new Map<String, Set<String>>();
        Id eventId;

        // Build one unique recipients list from all configured usernames.
        for (String username : sspsByUsername.keySet()) {

            User u = usersByUsername.get(username);

            if (u == null || !u.IsActive || String.isBlank(u.Email)) {
                logPresentationRequest(
                    OperationLogService.Level.WARN,
                    null,
                    'PresentationRequestUserSkipped',
                    'Configured username skipped because user is missing, inactive or has no email: ' + username,
                    new Set<String>{ username },
                    null,
                    null,
                    null
                );
                continue;
            }

            uniqueUsersById.put(u.Id, u);

            // Deduplicate SSP rows and keep the strategies that explain each notification.
            for (SessionSpeakerProduct__c ssp : sspsByUsername.get(username)) {
                addPresentationStrategyReason(strategiesByUsername, username, ssp);
                uniqueSspsById.put(ssp.Id, ssp);
            }
        }

        String html = '<div style="font-size:15px; line-height:22px;">'
            + 'Please prepare the following presentations:<br/><ul>';

        for (SessionSpeakerProduct__c ssp : uniqueSspsById.values()) {

            if (eventId == null) {
                eventId = ssp.session__c;
            }

            html += buildPresentationHTML(ssp);
        }

        html += '</ul></div>';

        if (eventId == null || uniqueUsersById.isEmpty()) {
            return;
        }

        List<String> recipients = new List<String>();

        for (User u : uniqueUsersById.values()) {
            recipients.add(u.Email);
        }

        try {

            Messaging.SingleEmailMessage rendered =
                Messaging.renderStoredEmailTemplate(
                    template.Id,
                    UserInfo.getUserId(),
                    eventId
                );

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(recipients);
            mail.setSaveAsActivity(false);
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(
                rendered.getHtmlBody().replace('{{presentationRequestHTML}}', html)
            );

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);

            List<Id> sspIds = new List<Id>(uniqueSspsById.keySet());

            for (Messaging.SendEmailResult result : results) {

                if (result.isSuccess()) {
                    logPresentationRequest(
                        OperationLogService.Level.INFO,
                        eventId,
                        'PresentationRequestEmailSent',
                        'Presentation request notification sent to: '
                            + formatPresentationNotificationReasons(strategiesByUsername),
                        sspsByUsername.keySet(),
                        recipients,
                        sspIds,
                        strategiesByUsername,
                        null
                    );
                    continue;
                }

                logPresentationRequest(
                    OperationLogService.Level.ERROR,
                    eventId,
                    'PresentationRequestEmailSendFailed',
                    'Unable to send presentation request notification: '
                        + joinSendEmailErrors(result.getErrors()),
                    sspsByUsername.keySet(),
                    recipients,
                    sspIds,
                    strategiesByUsername,
                    null
                );
            }

        } catch (Exception e) {

            logPresentationRequest(
                OperationLogService.Level.ERROR,
                eventId,
                'PresentationRequestEmailException',
                'Unexpected error while sending presentation request notification.',
                sspsByUsername.keySet(),
                recipients,
                new List<Id>(uniqueSspsById.keySet()),
                strategiesByUsername,
                e
            );
        }
    }


    /**
     * Build one HTML row for a presentation request
     */
    public static String buildPresentationHTML(SessionSpeakerProduct__c ssp) {

        String speaker = (ssp.speakerContact__r != null) ? ssp.speakerContact__r.Name : 'Unknown speaker';
        String product = (ssp.Strategy__r != null) ? ssp.Strategy__r.Name : 'Unknown product';

        // Add one presentation line to the grouped email body
        return '<li>'
            + '<b>' + product + '</b>'
            + ' - Speaker: <b>' + speaker + '</b>'
            + '</li>';
    }


    public static Map<String, List<User>> loadUsersByGroupName(Set<String> groupNames) {

        System.debug('NOTIF GROUP STEP 1 - loading groups ' + groupNames);

        Map<String, Id> groupIdByName = new Map<String, Id>();

        for (Group g : [
            SELECT Id, DeveloperName 
            FROM Group
            WHERE DeveloperName  IN :groupNames
        ]) {

            System.debug('NOTIF GROUP STEP 2 - group found = ' + g.DeveloperName);

            groupIdByName.put(g.DeveloperName, g.Id);
        }

        System.debug('NOTIF GROUP STEP 3 - groupIdByName = ' + groupIdByName);

        Map<String, List<User>> out = new Map<String, List<User>>();

        for (String g : groupNames) {
            out.put(g, new List<User>());
        }

        List<GroupMember> members = [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :groupIdByName.values()
        ];

        System.debug('NOTIF GROUP STEP 4 - members found = ' + members.size());

        // Collect all user Ids
        Set<Id> userIds = new Set<Id>();

        for (GroupMember gm : members) {
            userIds.add(gm.UserOrGroupId);
        }

        // Single query for users
        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Email, IsActive
            FROM User
            WHERE Id IN :userIds
        ]);

        System.debug('NOTIF GROUP STEP 5 - users loaded = ' + usersById.size());

        // Build final mapping
        for (GroupMember gm : members) {

            User u = usersById.get(gm.UserOrGroupId);

            if (u == null || !u.IsActive) {
                continue;
            }

            String groupName = null;

            for (String name : groupIdByName.keySet()) {
                if (groupIdByName.get(name) == gm.GroupId) {
                    groupName = name;
                    break;
                }
            }

            if (groupName != null) {
                out.get(groupName).add(u);
            }
        }

        System.debug('NOTIF GROUP RESULT - usersByGroupName = ' + out);

        return out;
    }


    /**
     * Build and send emails using VF template with placeholders
     */
    public static void sendEventStatusEmails(
        List<Event__c> events,
        Map<String, List<String>> salesTeamEmails
    ) {

        system.debug('=======Error sendEventStatusEmails');

        // Load VF template
        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'BooklyGenericNotif_VF'
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Event__c evt : events) {

            Set<String> recipients = buildRecipients(evt, salesTeamEmails);
            if (recipients.isEmpty()) {
                system.debug('=======Error : no recipients');
                continue;
            }

            // Build subject + message
            String message = buildStatusMessage(evt);
            system.debug('======= Message'+message);
            if (String.isBlank(message)) {
                system.debug('=======Error : no Message');
                continue;
            }
            String subjectValue = message;

            // Render template once per event (use any user, will override recipients later)
            Id anyUserId = UserInfo.getUserId();

            Messaging.SingleEmailMessage rendered =
                Messaging.renderStoredEmailTemplate(template.Id, anyUserId, evt.Id);

            // Replace placeholders
            String finalSubject = rendered.getSubject().replace(SUBJECT_PLACEHOLDER , subjectValue);

            String finalBody = rendered.getHtmlBody()
                .replace(SUBJECT_PLACEHOLDER , subjectValue)
                .replace(MESSAGE_PLACEHOLDER , message);

            // Build final email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            system.debug('====sendStatus===recipients :'+recipients);
            system.debug('=======sendStatus :'+finalSubject);

            mail.setToAddresses(new List<String>(recipients));
            mail.setSubject(finalSubject);
            mail.setHtmlBody(finalBody);
            mail.setSaveAsActivity(false);
            System.debug(
                '=== notif sent to recipients=' + new List<String>(recipients)
                + ' | eventId=' + evt.Id
                + ' | status=' + evt.Status__c
                + ' | recordType=' + (evt.RecordType != null ? evt.RecordType.DeveloperName : null)
                + ' | subject=' + finalSubject
            );
            emails.add(mail);
        }

        // Send in bulk
        if (!emails.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
            System.debug('=== notif sendEmail called, emails count=' + emails.size());

            for (Integer i = 0; i < results.size(); i++) {
                System.debug(
                    '=== notif result index=' + i
                    + ' success=' + results[i].isSuccess()
                    + ' errors=' + results[i].getErrors()
                );
            }
        }
    }
    /**
     * Build recipients list (organizer + sales owner + sales team)
     */
    public static Set<String> buildRecipients(
        Event__c evt,
        Map<String, List<String>> salesTeamEmails
    ) {

        Set<String> toAddresses = new Set<String>();

        // Organizer
        if (evt.Organizer__r != null && String.isNotBlank(evt.Organizer__r.Email)) {
            toAddresses.add(evt.Organizer__r.Email);
        }

        // Sales Owner
        if (evt.SalesOwner__r != null && String.isNotBlank(evt.SalesOwner__r.Email)) {
            toAddresses.add(evt.SalesOwner__r.Email);
        }

        // Submitted => Owner instead of Sales Team
        if (evt.Status__c == 'SubmittedToEventTeam') {

            if (evt.Owner != null && String.isNotBlank(evt.Owner.Email)) {
                toAddresses.add(evt.Owner.Email);
            }

        } else if (String.isNotBlank(evt.SalesTeam__c) && salesTeamEmails.containsKey(evt.SalesTeam__c)) {

            // Sales Team (from metadata)
            toAddresses.addAll(salesTeamEmails.get(evt.SalesTeam__c));
        }

        return toAddresses;
    }
    /**
     * Build message depending on status + record type
     */
    public static String buildStatusMessage(Event__c evt) {
        system.debug('=========buildStatusMessage : '+evt);
        // Case: Submitted
        if (evt.Status__c == 'SubmittedToEventTeam') {
            return System.Label.BooklySubmittedMessage;
        }

        // Case: Fully Approved + MeetingDays
        if (evt.Status__c == 'FullyApproved' &&
            evt.RecordType != null &&
            evt.RecordType.DeveloperName == 'MeetingDays') {

            return System.Label.BooklyMeetingDaysMessage;
        }

        // Default Fully Approved
        if (evt.Status__c == 'FullyApproved') {
            return System.Label.BooklyApprovedMessage;
        }

        return null;
    }

    /**
     * Entry point - notify Sales Team when 1 to 1 Meeting Days are created 
     */
    public static void notifyOneToOneMeetingDaysCreatedTodelete(List<Event__c> newEvents) {

        if (newEvents == null || newEvents.isEmpty()) {
            return;
        }

        Set<Id> eventIds = new Map<Id, Event__c>(newEvents).keySet();

        // Reload fields needed to identify 1to1 Meeting Days and recipients
        List<Event__c> events = [
            SELECT Id, Status__c, title__c, salesTeam__c, parentEvent__c,
                parentEvent__r.SalesTeam__c,
                Organizer__r.Email, SalesOwner__r.Email,
                RecordType.DeveloperName
            FROM Event__c
            WHERE Id IN :eventIds
        ];

        List<Event__c> oneToOneMeetingDays = new List<Event__c>();

        // Keep only 1to1 Meeting Days
        for (Event__c evt : events) {

            if (getEventType(evt) == '1to1MeetingDays') {
                oneToOneMeetingDays.add(evt);
            }
        }

        if (oneToOneMeetingDays.isEmpty()) {
            System.debug('=== notif 1to1MeetingDays created - no matching event');
            return;
        }

        NotifOneToOneMDCreated(oneToOneMeetingDays);
    }


    /**
     * Notify Sales Team when 1 to 1 Meeting Days are created
     */
    public static void NotifOneToOneMDCreated(List<Event__c> events) {

        System.debug('=======NotifOneToOneMDCreated=======' + events.size());

        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'BooklyGenericNotif_VF'
            LIMIT 1
        ];

        Map<String, List<String>> salesTeamEmails = loadSalesTeamEmails();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Event__c evt : events) {

            String salesTeam = evt.SalesTeam__c;

            if (String.isBlank(salesTeam) && evt.parentEvent__r != null) {
                salesTeam = evt.parentEvent__r.SalesTeam__c;
            }

            if (String.isBlank(salesTeam) || !salesTeamEmails.containsKey(salesTeam)) {
                System.debug('=== No Sales Team found for event : ' + evt.Id);
                continue;
            }

            Set<String> recipients = new Set<String>();
            recipients.addAll(salesTeamEmails.get(salesTeam));

            String subjectValue = 'New One to One created';

            String message =
                'Action required<br/><br/>'
                + 'Please proceed with creating and completing your one-to-one meetings '
                + 'in order to book the speakers with your clients.';

            Messaging.SingleEmailMessage rendered =
                Messaging.renderStoredEmailTemplate(
                    template.Id,
                    UserInfo.getUserId(),
                    evt.Id
                );

            String finalSubject =
                rendered.getSubject().replace(SUBJECT_PLACEHOLDER , subjectValue);

            String finalBody = rendered.getHtmlBody()
                .replace(SUBJECT_PLACEHOLDER , subjectValue)
                .replace(MESSAGE_PLACEHOLDER , message);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setToAddresses(new List<String>(recipients));
            mail.setSubject(finalSubject);
            mail.setHtmlBody(finalBody);
            mail.setSaveAsActivity(false);

            System.debug(
                '=== 1to1MeetingDays CREATED notif sent to=' + recipients
                + ' | eventId=' + evt.Id
            );

            emails.add(mail);
        }

        if (!emails.isEmpty()) {

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(emails, false);

            System.debug(
                '=== 1to1MeetingDays CREATED emails count=' + emails.size()
            );

            for (Integer i = 0; i < results.size(); i++) {

                System.debug(
                    '=== notif result index=' + i
                    + ' success=' + results[i].isSuccess()
                    + ' errors=' + results[i].getErrors()
                );
            }
        }
    }
    /**
     * Entry point - detect status change and split validated events by business type
     */
    public static void notifyEventStatusChange(Map<Id, Event__c> oldMap, Map<Id, Event__c> newMap) {

        System.debug('=======notifyEventStatusChange=================');

        List<Id> eventIds = new List<Id>();

        // Keep only events with relevant status change
        for (Id evtId : newMap.keySet()) {

            Event__c oldEvt = oldMap.get(evtId);
            Event__c newEvt = newMap.get(evtId);

            if (oldEvt.Status__c != newEvt.Status__c &&
                (newEvt.Status__c == 'SubmittedToEventTeam' ||
                newEvt.Status__c == 'FullyApproved')) {

                eventIds.add(evtId);
            }
        }

        if (eventIds.isEmpty()) {
            System.debug('=======notifyEventStatusChange=====no Event for notification');
            return;
        }

        // Reload fields needed by template, recipients, message and split
        List<Event__c> events = [
            SELECT Id, Status__c, title__c, category__c, format__c, salesTeam__c,
                startDate__c, startTime__c, endDate__c, endTime__c, timezone__c,
                city__c, locationName__c, locationAddress__c, locationPostCode__c,
                country__c, AudienceCompany__c, Company__r.Name,
                meetingGoal__c, meetingBackground__c, description__c, speakersHTML__c,
                Organizer__r.Email, SalesOwner__r.Email, Owner.Email, RecordType.DeveloperName,parentEvent__c
            FROM Event__c
            WHERE Id IN :eventIds
        ];

        Map<String, List<Event__c>> fullyApprovedByType = new Map<String, List<Event__c>>();
        List<Event__c> submittedEvents = new List<Event__c>();

        // Split validated events by business type
        for (Event__c evt : events) {

            // Keep existing flow for SubmittedToEventTeam
            if (evt.Status__c == 'SubmittedToEventTeam') {
                submittedEvents.add(evt);
                continue;
            }

            // Split only validated events
            if (evt.Status__c != 'FullyApproved') {
                continue;
            }

            String eventType = getEventType(evt);

            if (String.isBlank(eventType)) {
                System.debug('=======Unknown Event Type=======' + evt.Id);
                continue;
            }

            addEventToTypeMap(fullyApprovedByType, eventType, evt);
        }

        System.debug('=======fullyApprovedByType : ' + fullyApprovedByType);

        // Existing generic notification for SubmittedToEventTeam
        if (!submittedEvents.isEmpty()) {
            sendEventStatusEmails(submittedEvents, loadSalesTeamEmails());
        }

        // A - EVENT
        if (fullyApprovedByType.containsKey('Event')) {
            NotifEventValidated(fullyApprovedByType.get('Event'));
        }

        // B - MEETING DAYS
        if (fullyApprovedByType.containsKey('MeetingDays')) {
            NotifMeetingDaysValidated(fullyApprovedByType.get('MeetingDays'));
        }

        // C - 1 TO 1 STANDALONE
        if (fullyApprovedByType.containsKey('1to1StandAlone')) {
             // No validation notification for 1to1 standalone
           // NotifOneToOneSAValidated(fullyApprovedByType.get('1to1StandAlone'));
        }

        // D - 1 TO 1 MEETING DAYS
        if (fullyApprovedByType.containsKey('1to1MeetingDays')) {
           // NotifOneToOneMDValidated(fullyApprovedByType.get('1to1MeetingDays'));
        }
    }


    /**
     * Notify validated EVENT requests
     */
    public static void NotifEventValidated(List<Event__c> events) {

        System.debug('=======NotifEventValidated=======' + events.size());

        sendEventStatusEmails(events, loadSalesTeamEmails());
    }


    /**
     * Notify validated MEETING DAYS requests
     */
    public static void NotifMeetingDaysValidated(List<Event__c> events) {

        System.debug('=======NotifMeetingDaysValidated=======' + events.size());

        sendEventStatusEmails(events, loadSalesCRMEmails());
    }


    /**
     * Notify validated 1 TO 1 STANDALONE requests
    
    public static void NotifOneToOneSAValidated(List<Event__c> events) {

        System.debug('=======NotifOneToOneSAValidated=======' + events.size());

        sendEventStatusEmails(events, loadSalesTeamEmails());
    } */


    /**
     * Notify validated 1 TO 1 MEETING DAYS requests
     */
    /*public static void NotifOneToOneMDValidated(List<Event__c> events) {

        System.debug('=======NotifOneToOneMDValidated=======' + events.size());

        sendEventStatusEmails(events, loadSalesTeamEmails());
    }*/


    /**
     * Add event to the matching event type list
     */
    public static void addEventToTypeMap(
        Map<String, List<Event__c>> eventsByType,
        String eventType,
        Event__c evt
    ) {

        if (!eventsByType.containsKey(eventType)) {
            eventsByType.put(eventType, new List<Event__c>());
        }

        eventsByType.get(eventType).add(evt);
    }


   /**
     * Resolve business event type from record type and parent event
     */
    public static String getEventType(Event__c evt) {

        if (evt.RecordType == null || String.isBlank(evt.RecordType.DeveloperName)) {
            return null;
        }

        if (evt.RecordType.DeveloperName == 'event') {
            return 'Event';
        }

        if (evt.RecordType.DeveloperName == 'MeetingDays') {
            return 'MeetingDays';
        }

        if (evt.RecordType.DeveloperName == 'Meeting') {

            if (evt.parentEvent__c != null) {
                return '1to1MeetingDays';
            }

            return '1to1StandAlone';
        }

        return null;
    }

    
    /**
     * Load sales team notification emails from metadata
     */
    public static Map<String, List<String>> loadSalesTeamEmails() {

        Map<String, List<String>> result = new Map<String, List<String>>();

        // Metadata label must match Event__c.SalesTeam__c
        for (BooklySalesTeamNotification__mdt cfg : BooklySalesTeamNotification__mdt.getAll().values()) {

            if (String.isBlank(cfg.Label) || String.isBlank(cfg.emailAddressCRM__c)) {
                continue;
            }

            String salesTeam = cfg.Label.trim();

            if (!result.containsKey(salesTeam)) {
                result.put(salesTeam, new List<String>());
            }

            result.get(salesTeam).add(cfg.emailAddressCRM__c.trim());
        }

        return result;
    }
        /**
     * Load sales team notification emails from metadata
     */
    public static Map<String, List<String>> loadSalesCRMEmails() {

        Map<String, List<String>> result = new Map<String, List<String>>();

        // Metadata label must match Event__c.SalesTeam__c
        for (BooklySalesTeamNotification__mdt cfg : BooklySalesTeamNotification__mdt.getAll().values()) {

            if (String.isBlank(cfg.Label) || String.isBlank(cfg.emailAddress__c)) {
                continue;
            }

            String salesTeam = cfg.Label.trim();

            if (!result.containsKey(salesTeam)) {
                result.put(salesTeam, new List<String>());
            }

            result.get(salesTeam).add(cfg.emailAddress__c.trim());
        }

        return result;
    }


        /**
     * Notify organizer + sales team when Campaign is created
     */
    public static void notifyCampaignCreated(List<Event__c> events) {

        if (events == null || events.isEmpty()) {
            return;
        }

        // Reload all fields required for recipients + email content
        List<Event__c> eventsWithData = [
            SELECT Id, Name, Campaign__c,
            Campaign__r.Name,
            Organizer__r.Email,
            SalesOwner__r.Email,
            SalesTeam__c
            FROM Event__c
            WHERE Id IN :new Map<Id, Event__c>(events).keySet()
            AND Campaign__c != null
        ];

        Map<String, List<String>> salesTeamEmails = loadSalesTeamEmails();

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        for (Event__c evt : eventsWithData) {

            Set<String> recipients = new Set<String>();
            
            // Organizer
            if (evt.Organizer__r != null &&
                String.isNotBlank(evt.Organizer__r.Email)) {

                recipients.add(evt.Organizer__r.Email);
            }
            // CRM notification emails from metadata
            if (String.isNotBlank(evt.SalesTeam__c) &&
                salesTeamEmails.containsKey(evt.SalesTeam__c)) {

                recipients.addAll(
                    salesTeamEmails.get(evt.SalesTeam__c)
                );
            }

            if (recipients.isEmpty()) {
                continue;
            }

            // Build Campaign URL
            String campaignUrl =
                URL.getOrgDomainUrl().toExternalForm()
                + '/'
                + evt.Campaign__c;

            // Build HTML body from label
            String body =
                System.Label.BooklyCampaignCreatedMessage
                    .replace('{!campaignUrl}', campaignUrl);

            // Build subject from label
            String subject =
                System.Label.BooklyCampaignCreatedSubject
                    .replace('{!campaignName}', evt.Campaign__r.Name);

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            // Build notification email
            mail.setToAddresses(new List<String>(recipients));
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            mail.setSaveAsActivity(false);

            emails.add(mail);
        }

        // Send all notifications in one call
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }

        // Collecte les SSP liés à la notification pour les ajouter au contexte de log.
    private static List<Id> collectPresentationSspIds(
        Map<String, List<SessionSpeakerProduct__c>> sspsByUsername
    ) {

        Set<Id> uniqueSspIds = new Set<Id>();

        if (sspsByUsername == null || sspsByUsername.isEmpty()) {
            return new List<Id>();
        }

        // Déduplique les SSP car une stratégie peut notifier plusieurs users.
        for (List<SessionSpeakerProduct__c> ssps : sspsByUsername.values()) {

            if (ssps == null) {
                continue;
            }

            for (SessionSpeakerProduct__c ssp : ssps) {

                if (ssp != null && ssp.Id != null) {
                    uniqueSspIds.add(ssp.Id);
                }
            }
        }

        return new List<Id>(uniqueSspIds);
    }


        // Crée une entrée OperationLog__c pour les notifications de présentation.
    private static void logPresentationRequest(
        OperationLogService.Level level,
        Id eventId,
        String operation,
        String message,
        Set<String> usernames,
        List<String> recipients,
        List<Id> sspIds,
        Exception exceptionValue
    ) {

        logPresentationRequest(
            level,
            eventId,
            operation,
            message,
            usernames,
            recipients,
            sspIds,
            null,
            exceptionValue
        );
    }


    // Crée une entrée OperationLog__c avec le détail des stratégies par username notifié.
    private static void logPresentationRequest(
        OperationLogService.Level level,
        Id eventId,
        String operation,
        String message,
        Set<String> usernames,
        List<String> recipients,
        List<Id> sspIds,
        Map<String, Set<String>> strategiesByUsername,
        Exception exceptionValue
    ) {

        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = level;
        entry.sourceRecordId = eventId == null ? null : String.valueOf(eventId);
        entry.sourceObjectApiName = 'Event__c';
        entry.operation = operation;

        // Le message reste lisible dans le composant Operation Logs.
        entry.message = message;
        entry.contextJson = buildPresentationLogContext(usernames, recipients, sspIds, strategiesByUsername);
        entry.apexClass = 'customEventNotificationManager';
        entry.methodName = 'requestPresentation';
        entry.exceptionValue = exceptionValue;

        OperationLogService.log(entry);
    }


    // Construit le JSON de contexte pour tracer usernames, emails et SSP concernés.
    private static String buildPresentationLogContext(
        Set<String> usernames,
        List<String> recipients,
        List<Id> sspIds
    ) {

        return buildPresentationLogContext(usernames, recipients, sspIds, null);
    }

    // Ajoute la stratégie du SSP comme raison de notification pour un username.
    private static void addPresentationStrategyReason(
        Map<String, Set<String>> strategiesByUsername,
        String username,
        SessionSpeakerProduct__c ssp
    ) {

        if (strategiesByUsername == null || String.isBlank(username) || ssp == null) {
            return;
        }

        String strategy = null;

        if (ssp.Strategy__r != null) {
            strategy = String.isNotBlank(ssp.Strategy__r.Code__c)
                ? ssp.Strategy__r.Code__c
                : ssp.Strategy__r.Name;
        }

        if (String.isBlank(strategy)) {
            strategy = 'Unknown strategy';
        }

        if (!strategiesByUsername.containsKey(username)) {
            strategiesByUsername.put(username, new Set<String>());
        }

        strategiesByUsername.get(username).add(strategy);
    }


    // Formate les raisons sous la forme username(StrategyA,StrategyB).
    private static String formatPresentationNotificationReasons(
        Map<String, Set<String>> strategiesByUsername
    ) {

        if (strategiesByUsername == null || strategiesByUsername.isEmpty()) {
            return '';
        }

        List<String> formattedReasons = new List<String>();
        List<String> usernames = new List<String>(strategiesByUsername.keySet());
        usernames.sort();

        for (String username : usernames) {

            List<String> strategies = new List<String>(strategiesByUsername.get(username));
            strategies.sort();

            formattedReasons.add(username + '(' + String.join(strategies, ',') + ')');
        }

        return String.join(formattedReasons, ', ');
    }


    // Convertit les Set en List pour avoir un JSON propre et lisible.
    private static Map<String, List<String>> buildPresentationNotificationReasonMap(
        Map<String, Set<String>> strategiesByUsername
    ) {

        Map<String, List<String>> notificationReasons = new Map<String, List<String>>();

        if (strategiesByUsername == null || strategiesByUsername.isEmpty()) {
            return notificationReasons;
        }

        for (String username : strategiesByUsername.keySet()) {

            List<String> strategies = new List<String>(strategiesByUsername.get(username));
            strategies.sort();

            notificationReasons.put(username, strategies);
        }

        return notificationReasons;
    }
    
    // Construit le JSON de contexte avec les stratégies qui justifient chaque notification.
    private static String buildPresentationLogContext(
        Set<String> usernames,
        List<String> recipients,
        List<Id> sspIds,
        Map<String, Set<String>> strategiesByUsername
    ) {

        Map<String, Object> context = new Map<String, Object>();
        List<String> usernameValues = usernames == null ? new List<String>() : new List<String>(usernames);
        List<String> recipientValues = recipients == null ? new List<String>() : recipients;
        List<Id> sspIdValues = sspIds == null ? new List<Id>() : sspIds;

        // Ces champs permettent de savoir qui devait être notifié et qui l'a été.
        context.put('configuredUsernames', usernameValues);
        context.put('recipients', recipientValues);
        context.put('recipientCount', recipientValues.size());
        context.put('sessionSpeakerProductIds', sspIdValues);
        context.put('sessionSpeakerProductCount', sspIdValues.size());
        context.put('notificationReasons', buildPresentationNotificationReasonMap(strategiesByUsername));
        context.put('notificationReasonsText', formatPresentationNotificationReasons(strategiesByUsername));

        return JSON.serialize(context);
    }


    // Convertit les erreurs Messaging.SendEmailResult en message lisible.
    private static String joinSendEmailErrors(Messaging.SendEmailError[] errors) {

        List<String> messages = new List<String>();

        if (errors == null || errors.isEmpty()) {
            return '';
        }

        for (Messaging.SendEmailError error : errors) {
            messages.add(String.valueOf(error.getStatusCode()) + ': ' + error.getMessage());
        }

        return String.join(messages, ' | ');
    }
}