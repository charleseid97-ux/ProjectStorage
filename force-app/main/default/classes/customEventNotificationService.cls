public with sharing class customEventNotificationService {

    // --------------------
    // Constants
    // --------------------
    private static final String SUBMITTED_STATUS = 'SubmittedToEventTeam';

    private static final String TEMPLATE_DEV_NAME         = 'EventTeamApproval';
    private static final String SPEAKER_TEMPLATE_DEV_NAME = 'speakerApprvoal';
    private static final String QUEUE_DEV_NAME            = 'EventTeam';

    private static final String VF_PAGE_NAME         = 'EventApproval';
    private static final String SPEAKER_VF_PAGE_NAME = 'EventSpeakerApproval';

    // Reused literals
    private static final String LOG_PREFIX        = '[customEventNotificationService] ';
    private static final String EXIT_LOG          = ' -> exit';
    private static final String APEX_PREFIX       = '/apex/';
    private static final String RECORD_URL_PATH   = '/lightning/r/Event__c/';
    private static final String ACTION_APPROVE_QS = '&action=approve';
    private static final String ACTION_REJECT_QS  = '&action=reject';

    private static final String PH_SPEAKERS = '{{SPEAKERS_HTML}}';
    private static final String PH_APPROVE  = '{{APPROVE_URL}}';
    private static final String PH_REJECT   = '{{REJECT_URL}}';
    private static final String PH_RECORD   = '{{RECORD_URL}}';

    private static final String TD_DEFAULT = '<td style="padding:6px 0; border-bottom:1px solid #f3f4f6;">';
    private static final String TD_ACC     = '<td style="padding:6px 0; border-bottom:1px solid #f3f4f6; color:#6b7280;">';
    private static final String DIV_CLOSE  = '</div>';

    // Toggle logs
    public static Boolean notificationsDisabled = false;
    private static final Boolean LOG_ENABLED = true;
    private static void log(String msg) { if (LOG_ENABLED) System.debug(LoggingLevel.INFO, LOG_PREFIX + msg); }
    private static void warn(String msg) { if (LOG_ENABLED) System.debug(LoggingLevel.WARN, LOG_PREFIX + msg); }
    private static void err(String msg)  { if (LOG_ENABLED) System.debug(LoggingLevel.ERROR, LOG_PREFIX + msg); }

    // --------------------
    // Trigger entrypoint
    // --------------------
    public static void manageNotifications(Map<Id, Event__c> newItems, Map<Id, Event__c> oldItems) {
        if (notificationsDisabled) { log('Notifications disabled' + EXIT_LOG); return; }
        if (newItems == null || newItems.isEmpty()) { log('No newItems' + EXIT_LOG); return; }

        log('manageNotifications start. newItems=' + newItems.size() + ', isUpdate=' + (oldItems != null));
        Set<Id> parentEventIds = getParentEventIdsFromTrigger(newItems, oldItems);

        if (parentEventIds.isEmpty()) {
            log('No events transitioned to ' + SUBMITTED_STATUS + EXIT_LOG);
            return;
        }
        sendApprovalEmails(parentEventIds);
    }

    // Détermine les parent events à traiter depuis le trigger (décomposé)
    private static Set<Id> getParentEventIdsFromTrigger(Map<Id, Event__c> newItems, Map<Id, Event__c> oldItems) {
        if (oldItems == null) return getParentEventIdsFromInsert(newItems);
        return getParentEventIdsFromUpdate(newItems, oldItems);
    }

    private static Set<Id> getParentEventIdsFromInsert(Map<Id, Event__c> newItems) {
        Set<Id> parentEventIds = new Set<Id>();
        for (Event__c e : newItems.values()) {
            if (e != null && e.Id != null && e.status__c == SUBMITTED_STATUS) {
                parentEventIds.add(e.Id);
            }
        }
        log('AfterInsert: candidates=' + parentEventIds.size());
        return parentEventIds;
    }

    private static Set<Id> getParentEventIdsFromUpdate(Map<Id, Event__c> newItems, Map<Id, Event__c> oldItems) {
        Set<Id> parentEventIds = new Set<Id>();
        for (Id eid : newItems.keySet()) {
            Event__c n = newItems.get(eid);
            Event__c o = oldItems.get(eid);
            if (n == null || o == null) continue;
            if (o.status__c != SUBMITTED_STATUS && n.status__c == SUBMITTED_STATUS) {
                parentEventIds.add(n.Id);
            }
        }
        log('AfterUpdate: candidates=' + parentEventIds.size());
        return parentEventIds;
    }

    // --------------------
    // Core sender (decomposed)
    // --------------------
    public static void sendApprovalEmails(Set<Id> parentEventIds) {
        log('sendApprovalEmails start. parentEventIds=' + parentEventIds.size());

        List<String> toEmails = getQueueMemberEmailsByDeveloperName(QUEUE_DEV_NAME);
        log('Queue recipients resolved. count=' + toEmails.size());
        if (toEmails.isEmpty()) { warn('No recipients found for queue ' + QUEUE_DEV_NAME + EXIT_LOG); return; }

        Id templateId = getEmailTemplateIdByDeveloperName(TEMPLATE_DEV_NAME);
        if (templateId == null) { err('Email template not found: ' + TEMPLATE_DEV_NAME + EXIT_LOG); return; }
        Id speakerTemplateId = getEmailTemplateIdByDeveloperName(SPEAKER_TEMPLATE_DEV_NAME);
        if (speakerTemplateId == null) { warn('Speaker email template not found: ' + SPEAKER_TEMPLATE_DEV_NAME + ' -> speaker emails skipped'); }

        List<Event__c> parents  = queryParents(parentEventIds);
        List<Event__c> children = queryChildren(parentEventIds);
        Map<Id, List<Event__c>> parentToChildren = mapParentToChildren(children);
        Set<Id> sessionIds = buildSessionIds(parentEventIds, children);
        Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers = querySessionSpeakers(sessionIds);

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        log('Org baseUrl=' + baseUrl);

        List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();
        msgs.addAll(prepareEventTeamEmails(parents, templateId, toEmails, baseUrl, parentToChildren, sessionToSpeakers));

        if (speakerTemplateId != null) {
            msgs.addAll(buildSpeakerAssistantEmails(
                speakerTemplateId,
                baseUrl,
                parents,
                children,
                sessionIds,
                parentToChildren,
                sessionToSpeakers
            ));
        }

        sendMessages(msgs);
    }

    // --------------------
    // Queries & mappings
    // --------------------
    private static List<Event__c> queryParents(Set<Id> parentEventIds) {
        List<Event__c> parents = [ SELECT Id FROM Event__c WHERE Id IN :parentEventIds ];
        log('Parents queried. count=' + parents.size());
        return parents;
    }

    private static List<Event__c> queryChildren(Set<Id> parentEventIds) {
        List<Event__c> children = [
            SELECT Id, parentEvent__c, title__c, startDate__c, startTime__c, endTime__c
            FROM Event__c
            WHERE parentEvent__c IN :parentEventIds
            ORDER BY startDate__c, startTime__c
        ];
        log('Children queried. count=' + children.size());
        return children;
    }

    private static Map<Id, List<Event__c>> mapParentToChildren(List<Event__c> children) {
        Map<Id, List<Event__c>> parentToChildren = new Map<Id, List<Event__c>>();
        for (Event__c c : children) {
            if (c.parentEvent__c == null) continue;
            if (!parentToChildren.containsKey(c.parentEvent__c)) parentToChildren.put(c.parentEvent__c, new List<Event__c>());
            parentToChildren.get(c.parentEvent__c).add(c);
        }
        log('Parent->Children map size=' + parentToChildren.size());
        return parentToChildren;
    }

    private static Set<Id> buildSessionIds(Set<Id> parentEventIds, List<Event__c> children) {
        Set<Id> sessionIds = new Set<Id>();
        sessionIds.addAll(parentEventIds);
        for (Event__c c : children) sessionIds.add(c.Id);
        log('Sessions for speakers. sessionIds=' + sessionIds.size());
        return sessionIds;
    }

    private static Map<Id, List<SessionSpeakerProduct__c>> querySessionSpeakers(Set<Id> sessionIds) {
        Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers = new Map<Id, List<SessionSpeakerProduct__c>>();
        if (sessionIds.isEmpty()) { log('No sessionIds for SSP query'); return sessionToSpeakers; }

        List<SessionSpeakerProduct__c> ssp = [
            SELECT Id, session__c, speakerContact__c,
                   speakerContact__r.Name,
                   speakerContact__r.Account.Name,
                   Language__c, presentationStatus__c, Product__c
            FROM SessionSpeakerProduct__c
            WHERE session__c IN :sessionIds
              AND speakerContact__c != null
            ORDER BY session__c
        ];
        log('SSP queried. count=' + ssp.size());

        for (SessionSpeakerProduct__c s : ssp) {
            if (!sessionToSpeakers.containsKey(s.session__c)) sessionToSpeakers.put(s.session__c, new List<SessionSpeakerProduct__c>());
            sessionToSpeakers.get(s.session__c).add(s);
        }
        log('Session->Speakers map size=' + sessionToSpeakers.size());
        return sessionToSpeakers;
    }

    // --------------------
    // Prepare Event Team emails
    // --------------------
    private static List<Messaging.SingleEmailMessage> prepareEventTeamEmails(
        List<Event__c> parents,
        Id templateId,
        List<String> toEmails,
        String baseUrl,
        Map<Id, List<Event__c>> parentToChildren,
        Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers
    ) {
        List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();
        for (Event__c p : parents) {
            Messaging.SingleEmailMessage m = prepareEventTeamEmailFor(p, templateId, toEmails, baseUrl, parentToChildren, sessionToSpeakers);
            if (m != null) msgs.add(m);
        }
        return msgs;
    }

    // Prépare un email EventTeam pour un event (retourne null en cas d'erreur)
    private static Messaging.SingleEmailMessage prepareEventTeamEmailFor(
        Event__c p,
        Id templateId,
        List<String> toEmails,
        String baseUrl,
        Map<Id, List<Event__c>> parentToChildren,
        Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers
    ) {
        try {
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, UserInfo.getUserId(), p.Id);
            String html = rendered.getHtmlBody();

            String recordUrl  = baseUrl + RECORD_URL_PATH + p.Id + '/view';
            String approveUrl = baseUrl + APEX_PREFIX + VF_PAGE_NAME + '?eid=' + p.Id + ACTION_APPROVE_QS;
            String rejectUrl  = baseUrl + APEX_PREFIX + VF_PAGE_NAME + '?eid=' + p.Id + ACTION_REJECT_QS;

            String speakersHtml = buildSpeakersHtml(p.Id, parentToChildren.get(p.Id), sessionToSpeakers);

            html = html.replace(PH_RECORD, recordUrl);
            html = html.replace(PH_APPROVE, approveUrl);
            html = html.replace(PH_REJECT, rejectUrl);
            html = html.replace(PH_SPEAKERS, speakersHtml);

            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(toEmails);
            m.setSubject(rendered.getSubject());
            m.setHtmlBody(html);
            m.setSaveAsActivity(false);
            log('Prepared EventTeam email for EventId=' + p.Id);
            return m;
        } catch (Exception ex) {
            err('Failed to prepare EventTeam email for EventId=' + p.Id + ' -> ' + ex.getMessage());
            return null;
        }
    }

    // --------------------
    // Speaker assistant builder (décomposée)
    // --------------------
    private static List<Messaging.SingleEmailMessage> buildSpeakerAssistantEmails(
        Id speakerTemplateId,
        String baseUrl,
        List<Event__c> parents,
        List<Event__c> children,
        Set<Id> sessionIds,
        Map<Id, List<Event__c>> parentToChildren,
        Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers
    ) {
        List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();

        List<EventSpeakerApprovals__c> approvals = [
            SELECT Id, Event__c, Speaker__c,
                   Speaker__r.FirstName, Speaker__r.LastName,
                   Speaker__r.SpeakerAssistant__c,
                   Speaker__r.SpeakerAssistant__r.Email,
                   Speaker__r.SpeakerAssistant__r.IsActive
            FROM EventSpeakerApprovals__c
            WHERE Event__c IN :sessionIds
              AND Speaker__c != null
        ];
        log('Speaker approvals queried. count=' + approvals.size());
        if (approvals.isEmpty()) return msgs;

        for (EventSpeakerApprovals__c esa : approvals) {
            try {
                if (!customEventNotificationService.isValidSpeakerAssistant(esa)) continue;
                Messaging.SingleEmailMessage m = customEventNotificationService.prepareSpeakerAssistantEmail(
                    esa, speakerTemplateId, baseUrl, sessionToSpeakers
                );
                if (m != null) {
                    msgs.add(m);
                    log('Prepared SpeakerAssistant email for ESA=' + esa.Id + ' to=' + esa.Speaker__r.SpeakerAssistant__r.Email);
                }
            } catch (Exception ex) {
                err('Failed to prepare SpeakerAssistant email for ESA=' + esa.Id + ' -> ' + ex.getMessage());
            }
        }
        return msgs;
    }

    // Helper: validation du recipient ESA (public static pour visibilité)
    public static Boolean isValidSpeakerAssistant(EventSpeakerApprovals__c esa) {
        return esa != null
            && esa.Speaker__r != null
            && esa.Speaker__r.SpeakerAssistant__c != null
            && esa.Speaker__r.SpeakerAssistant__r != null
            && esa.Speaker__r.SpeakerAssistant__r.IsActive == true
            && !String.isBlank(esa.Speaker__r.SpeakerAssistant__r.Email);
    }

    // Helper: prépare un message pour un ESA (retourne null en cas d'erreur) (public static pour visibilité)
    public static Messaging.SingleEmailMessage prepareSpeakerAssistantEmail(
        EventSpeakerApprovals__c esa,
        Id speakerTemplateId,
        String baseUrl,
        Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers
    ) {
        try {
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(speakerTemplateId, UserInfo.getUserId(), esa.Id);
            String html = rendered.getHtmlBody();

            String recordUrl  = baseUrl + RECORD_URL_PATH + esa.Event__c + '/view';
            String approveUrl = baseUrl + APEX_PREFIX + SPEAKER_VF_PAGE_NAME + '?id=' + esa.Id + ACTION_APPROVE_QS;
            String rejectUrl  = baseUrl + APEX_PREFIX + SPEAKER_VF_PAGE_NAME + '?id=' + esa.Id + ACTION_REJECT_QS;

            String speakersHtml = buildSpeakersHtml(esa.Event__c, null, sessionToSpeakers);

            html = html.replace(PH_RECORD, recordUrl);
            html = html.replace(PH_APPROVE, approveUrl);
            html = html.replace(PH_REJECT, rejectUrl);
            html = html.replace(PH_SPEAKERS, speakersHtml);

            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new List<String>{ esa.Speaker__r.SpeakerAssistant__r.Email });
            m.setSubject(rendered.getSubject());
            m.setHtmlBody(html);
            m.setSaveAsActivity(false);
            return m;
        } catch (Exception ex) {
            err('prepareSpeakerAssistantEmail failed for ESA=' + (esa == null ? 'null' : esa.Id) + ' -> ' + ex.getMessage());
            return null;
        }
    }

    // --------------------
    // Send messages helper
    // --------------------
    private static void sendMessages(List<Messaging.SingleEmailMessage> msgs) {
        if (msgs == null || msgs.isEmpty()) { warn('No emails to send (msgs empty)'); return; }
        log('Sending emails. count=' + msgs.size());
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(msgs, false);
            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) {
                    for (Messaging.SendEmailError e : r.getErrors()) {
                        System.debug(LoggingLevel.ERROR, LOG_PREFIX + 'sendEmail FAILED - statusCode=' + e.getStatusCode()
                            + ' message=' + e.getMessage() + ' fields=' + e.getFields());
                    }
                }
            }
        } catch (Exception ex) {
            err('Messaging.sendEmail failed -> ' + ex.getMessage());
        }
    }

    // --------------------
    // Queue -> emails (decomposed)
    // --------------------
    private static List<String> getQueueMemberEmailsByDeveloperName(String queueDevName) {
        if (String.isBlank(queueDevName)) return new List<String>();

        Id queueId = resolveQueueId(queueDevName);
        if (queueId == null) return new List<String>();

        Set<Id> userIds = collectUserIdsFromGroupTree(queueId);
        if (userIds.isEmpty()) return new List<String>();

        return fetchActiveUserEmails(userIds);
    }

    private static Id resolveQueueId(String queueDevName) {
        List<Group> queues = [ SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :queueDevName LIMIT 1 ];
        return queues.isEmpty() ? null : queues[0].Id;
    }

    private static Set<Id> collectUserIdsFromGroupTree(Id rootGroupId) {
        Set<Id> visitedGroups = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        List<Id> groupIdsToProcess = new List<Id>{ rootGroupId };

        while (!groupIdsToProcess.isEmpty()) {
            Id gid = groupIdsToProcess.remove(0);
            if (visitedGroups.contains(gid)) continue;
            visitedGroups.add(gid);

            for (GroupMember gm : [ SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :gid ]) {
                String idStr = String.valueOf(gm.UserOrGroupId);
                if (idStr.startsWith('005')) userIds.add(gm.UserOrGroupId);
                else if (idStr.startsWith('00G')) groupIdsToProcess.add(gm.UserOrGroupId);
            }
        }
        return userIds;
    }

    private static List<String> fetchActiveUserEmails(Set<Id> userIds) {
        List<String> emails = new List<String>();
        for (User u : [ SELECT Email FROM User WHERE Id IN :userIds AND IsActive = true AND Email != null ]) emails.add(u.Email);
        return emails;
    }

    // --------------------
    // Speakers HTML builders
    // --------------------
    private static String buildSpeakersHtml(Id parentId, List<Event__c> children, Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers) {
        List<String> parts = new List<String>();
        parts.add(buildSpeakersSection('Parent event', sessionToSpeakers.get(parentId)));
        if (children != null && !children.isEmpty()) {
            for (Event__c c : children) parts.add(buildSpeakersSection('Session: ' + safe(c.title__c), sessionToSpeakers.get(c.Id)));
        }
        return String.join(parts, '');
    }

    private static String buildSpeakersSection(String title, List<SessionSpeakerProduct__c> speakers) {
        List<String> parts = new List<String>();
        parts.add('<div style="margin:0 0 12px 0;">');
        parts.add('<div style="font-weight:bold; font-size:13px; margin:0 0 6px 0;">' + safe(title) + '</div>');

        if (speakers == null || speakers.isEmpty()) {
            parts.add(noSpeakersDiv());
            parts.add(DIV_CLOSE);
            return String.join(parts, '');
        }

        parts.add(tableHeader());
        for (SessionSpeakerProduct__c s : speakers) parts.add(tableRowForSpeaker(s));
        parts.add('</table>');
        parts.add(DIV_CLOSE);
        return String.join(parts, '');
    }

    private static String noSpeakersDiv() {
        return '<div style="font-size:13px; color:#6b7280;">No speakers found.</div>';
    }

    private static String tableHeader() {
        return '<table style="width:100%; border-collapse:collapse; font-size:13px;">'
             + '<tr>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Speaker</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Account</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Language</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Presentation</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Product</th>'
             + '</tr>';
    }

    private static String tableRowForSpeaker(SessionSpeakerProduct__c s) {
        String speakerName = (s.speakerContact__r != null) ? s.speakerContact__r.Name : 'Unknown';
        String accName = (s.speakerContact__r != null && s.speakerContact__r.Account != null) ? s.speakerContact__r.Account.Name : '';
        String lang = safe(s.Language__c);
        String pres = safe(s.presentationStatus__c);
        String prod = (s.Product__c != null) ? 'Yes' : '—';

        String row = '<tr>'
                   + TD_DEFAULT + safe(speakerName) + '</td>'
                   + TD_ACC     + safe(accName) + '</td>'
                   + TD_DEFAULT + safe(lang) + '</td>'
                   + TD_DEFAULT + safe(pres) + '</td>'
                   + TD_DEFAULT + safe(prod) + '</td>'
                   + '</tr>';
        return row;
    }

    // --------------------
    // Utilities
    // --------------------
    private static Id getEmailTemplateIdByDeveloperName(String devName) {
        if (String.isBlank(devName)) return null;
        List<EmailTemplate> t = [ SELECT Id FROM EmailTemplate WHERE DeveloperName = :devName LIMIT 1 ];
        return t.isEmpty() ? null : t[0].Id;
    }

    private static String safe(String v) { return v == null ? '' : v; }
}
