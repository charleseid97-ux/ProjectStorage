public without sharing class customEventNotificationManager {

    
    public static void requestPresentation(List<SessionSpeakerProduct__c> ssps) {

        System.debug('NOTIF STEP 1 - requestPresentation START, SSP count = ' + (ssps == null ? 0 : ssps.size()));

        if (ssps == null || ssps.isEmpty()) {
            System.debug('NOTIF STOP - no SSP provided');
            return;
        }

        Map<String, String> strategyToGroupName = loadStrategyToGroupNameMap();
        System.debug('NOTIF STEP 2 - strategyToGroupName map = ' + strategyToGroupName);

        if (strategyToGroupName.isEmpty()) {
            System.debug('NOTIF STOP - no metadata configuration found');
            return;
        }

        Map<String, List<SessionSpeakerProduct__c>> sspsByGroup = mapSspsToGroups(ssps, strategyToGroupName);

        if (sspsByGroup.isEmpty()) {
            System.debug('NOTIF STOP - no group matched');
            return;
        }

        Map<String, List<User>> usersByGroupName = loadUsersByGroupName(sspsByGroup.keySet());
        System.debug('NOTIF STEP 3 - usersByGroupName = ' + usersByGroupName);

        if (usersByGroupName.isEmpty()) {
            System.debug('NOTIF STOP - no users found');
            return;
        }

        sendPresentationEmails(sspsByGroup, usersByGroupName);

        System.debug('NOTIF END - requestPresentation FINISHED');
    }


    /**
     * Map SSP records to their notification group
     */
    public static Map<String, List<SessionSpeakerProduct__c>> mapSspsToGroups(
        List<SessionSpeakerProduct__c> ssps,
        Map<String, String> strategyToGroupName
    ) {

        Map<String, List<SessionSpeakerProduct__c>> result = new Map<String, List<SessionSpeakerProduct__c>>();

        for (SessionSpeakerProduct__c ssp : [
            SELECT Id, session__c, Strategy__r.Name,Strategy__r.Code__c, speakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Id IN :new Map<Id, SessionSpeakerProduct__c>(ssps).keySet()
        ]) {

            String strategyCode = (ssp.Strategy__r != null) ? ssp.Strategy__r.Code__c : null;

            if (String.isBlank(strategyCode) || ssp.session__c == null) {
                continue;
            }

            String groupName = strategyToGroupName.get(strategyCode.trim());

            if (String.isBlank(groupName)) {
                continue;
            }

            if (!result.containsKey(groupName)) {
                result.put(groupName, new List<SessionSpeakerProduct__c>());
            }

            result.get(groupName).add(ssp);
        }

        System.debug('NOTIF MAP RESULT - sspsByGroup = ' + result);

        return result;
    }


    /**
     * Build and send one email per group and per user
     */
    public static void sendPresentationEmails(
        Map<String, List<SessionSpeakerProduct__c>> sspsByGroup,
        Map<String, List<User>> usersByGroupName
    ) {

        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'PresentationRequest_VF'
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (String groupName : sspsByGroup.keySet()) {

            List<User> users = usersByGroupName.get(groupName);
            if (users == null || users.isEmpty()) continue;

            String html = '<div style="font-size:15px; line-height:22px;">'
                + 'Please prepare the following presentations:<br/><ul>';

            for (SessionSpeakerProduct__c ssp : sspsByGroup.get(groupName)) {
                html += buildPresentationHTML(ssp);
            }

            html += '</ul></div>';

            // Send the grouped content once to each user
            for (User u : users) {

                if (!u.IsActive || String.isBlank(u.Email)) {
                    System.debug('NOTIF SKIP USER - inactive or no email : ' + u.Id);
                    continue;
                }

                Messaging.SingleEmailMessage rendered =
                    Messaging.renderStoredEmailTemplate(template.Id, u.Id, sspsByGroup.get(groupName)[0].session__c);

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(u.Id);
                mail.setWhatId(sspsByGroup.get(groupName)[0].session__c);
                mail.setSaveAsActivity(false);
                mail.setSubject(rendered.getSubject());

                // Inject all presentations for this group in one email
                String body = rendered.getHtmlBody().replace('{{presentationRequestHTML}}', html);
                mail.setHtmlBody(body);

                emails.add(mail);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
            System.debug('NOTIF SEND - emails sent = ' + emails.size());
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

    public static Map<String, String> loadStrategyToGroupNameMap() {

        System.debug('NOTIF META STEP 1 - loading strategyNotificationGroups metadata');

        Map<String, String> out = new Map<String, String>();

        for (strategyNotificationGroups__mdt cfg : strategyNotificationGroups__mdt.getAll().values()) {

            System.debug('NOTIF META STEP 2 - metadata record = ' + cfg.DeveloperName);

            if (String.isBlank(cfg.strategies__c) || String.isBlank(cfg.userGroupName__c)) {
                System.debug('NOTIF META SKIP - missing strategies or group');
                continue;
            }

            for (String strategyName : cfg.strategies__c.split(',')) {

                String s = strategyName.trim();

                System.debug('NOTIF META STEP 3 - strategy mapped = ' + s + ' -> ' + cfg.userGroupName__c);

                if (String.isNotBlank(s)) {
                    out.put(s, cfg.userGroupName__c.trim());
                }
            }
        }

        System.debug('NOTIF META RESULT - strategyToGroup map = ' + out);

        return out;
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
     * Notify organizer (Contact) when events are created
     
    public static void notifyOrganizer(List<Event__c> eventsList) {

        if (eventsList == null || eventsList.isEmpty()) {
            return;
        }

        // Reload events to get Organizer contact info
        List<Event__c> eventsWithOrganizer = [
            SELECT Id, Name, Organizer__c, Organizer__r.Name, Organizer__r.Email
            FROM Event__c
            WHERE Id IN :new Map<Id, Event__c>(eventsList).keySet()
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Event__c evt : eventsWithOrganizer) {

            // Skip if no valid organizer or email
            if (evt.Organizer__c == null || evt.Organizer__r == null || String.isBlank(evt.Organizer__r.Email)) {
                continue;
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ evt.Organizer__r.Email });
            mail.setSubject('New event created: ' + evt.Name);

            // Basic HTML body for notification
            mail.setHtmlBody(
                '<div style="font-size:14px; line-height:20px;">'
                + 'Hello ' + evt.Organizer__r.Name + ',<br/><br/>'
                + 'The event <b>' + evt.Name + '</b> has been created.'
                + '</div>'
            );

            mail.setSaveAsActivity(false);
            emails.add(mail);
        }

        // Send all emails in one call (bulk safe)
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }
*/


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
            String finalSubject = rendered.getSubject().replace('[!subject]', subjectValue);

            String finalBody = rendered.getHtmlBody()
                .replace('[!subject]', subjectValue)
                .replace('[!message]', message);

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

        // Sales Team (from metadata)
        if (String.isNotBlank(evt.SalesTeam__c) && salesTeamEmails.containsKey(evt.SalesTeam__c)) {
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
                rendered.getSubject().replace('[!subject]', subjectValue);

            String finalBody = rendered.getHtmlBody()
                .replace('[!subject]', subjectValue)
                .replace('[!message]', message);

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
                Organizer__r.Email, SalesOwner__r.Email, RecordType.DeveloperName,parentEvent__c
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
            NotifOneToOneSAValidated(fullyApprovedByType.get('1to1StandAlone'));
        }

        // D - 1 TO 1 MEETING DAYS
        if (fullyApprovedByType.containsKey('1to1MeetingDays')) {
            NotifOneToOneMDValidated(fullyApprovedByType.get('1to1MeetingDays'));
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

        sendEventStatusEmails(events, loadSalesTeamEmails());
    }


    /**
     * Notify validated 1 TO 1 STANDALONE requests
     */
    public static void NotifOneToOneSAValidated(List<Event__c> events) {

        System.debug('=======NotifOneToOneSAValidated=======' + events.size());

        sendEventStatusEmails(events, loadSalesTeamEmails());
    }


    /**
     * Notify validated 1 TO 1 MEETING DAYS requests
     */
    public static void NotifOneToOneMDValidated(List<Event__c> events) {

        System.debug('=======NotifOneToOneMDValidated=======' + events.size());

        sendEventStatusEmails(events, loadSalesTeamEmails());
    }


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

            // Sales owner
            if (evt.SalesOwner__r != null &&
                String.isNotBlank(evt.SalesOwner__r.Email)) {

                recipients.add(evt.SalesOwner__r.Email);
            }

            // Sales team emails from metadata
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

}