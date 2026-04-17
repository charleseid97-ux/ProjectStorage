public with sharing class customEventNotificationManager {

    
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
    private static Map<String, List<SessionSpeakerProduct__c>> mapSspsToGroups(
        List<SessionSpeakerProduct__c> ssps,
        Map<String, String> strategyToGroupName
    ) {

        Map<String, List<SessionSpeakerProduct__c>> result = new Map<String, List<SessionSpeakerProduct__c>>();

        for (SessionSpeakerProduct__c ssp : [
            SELECT Id, session__c, Strategy__r.Name, speakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Id IN :new Map<Id, SessionSpeakerProduct__c>(ssps).keySet()
        ]) {

            String strategyName = (ssp.Strategy__r != null) ? ssp.Strategy__r.Name : null;

            if (String.isBlank(strategyName) || ssp.session__c == null) {
                continue;
            }

            String groupName = strategyToGroupName.get(strategyName.trim());

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
     * Build and send emails for presentation requests
     */
    private static void sendPresentationEmails(
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
            if (users == null) continue;

            for (SessionSpeakerProduct__c ssp : sspsByGroup.get(groupName)) {

                String html = buildPresentationHTML(ssp);

                for (User u : users) {

                    if (!u.IsActive || String.isBlank(u.Email)) {
                        continue;
                    }

                    Messaging.SingleEmailMessage rendered =
                        Messaging.renderStoredEmailTemplate(template.Id, u.Id, ssp.session__c);

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(u.Id);
                    mail.setWhatId(ssp.session__c);
                    mail.setSaveAsActivity(false);
                    mail.setSubject(rendered.getSubject());

                    String body = rendered.getHtmlBody().replace('{{presentationRequestHTML}}', html);
                    mail.setHtmlBody(body);

                    emails.add(mail);
                }
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
            System.debug('NOTIF SEND - emails sent = ' + emails.size());
        }
    }


    /**
     * Build HTML content injected into the template placeholder
     */
    private static String buildPresentationHTML(SessionSpeakerProduct__c ssp) {

        String speaker = (ssp.speakerContact__r != null) ? ssp.speakerContact__r.Name : 'Unknown speaker';
        String product = (ssp.Strategy__r != null) ? ssp.Strategy__r.Name : 'Unknown product';

        return '<div style="font-size:15px; line-height:22px;">'
            + 'Please prepare a presentation for speaker <b>' + speaker + '</b>'
            + ' to present product <b>' + product + '</b>.'
            + '</div>';
    }

    private static Map<String, String> loadStrategyToGroupNameMap() {

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


    private static Map<String, List<User>> loadUsersByGroupName(Set<String> groupNames) {

        System.debug('NOTIF GROUP STEP 1 - loading groups ' + groupNames);

        Map<String, Id> groupIdByName = new Map<String, Id>();

        for (Group g : [
            SELECT Id, Name
            FROM Group
            WHERE Name IN :groupNames
        ]) {

            System.debug('NOTIF GROUP STEP 2 - group found = ' + g.Name);

            groupIdByName.put(g.Name, g.Id);
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
     */
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
}