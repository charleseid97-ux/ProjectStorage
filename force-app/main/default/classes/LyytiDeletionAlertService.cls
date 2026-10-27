/** ──────────────────────────────────────
 * @description Lyyti Deletion Alert: emails the event managers the Lyyti participants (CampaignMembers with a LyytiId__c)
 *                  deleted in Salesforce, so they can remove them in Lyyti.
 *              One entry point per deleted object, each resolving its Lyyti members, all sending through sendAlerts:
 *                  - alertDeletedCampaignMembers (CampaignMember before delete): a CampaignMember deleted directly is deleted
 *                    permanently (no recycle bin), so it is read while it still exists.
 *                  - alertDeletedContacts / alertDeletedLeads (Contact / Lead after delete): their members are cascade-deleted
 *                    with them and read back from the recycle bin. A merge moves the losing record's members to the master
 *                    instead of deleting them, so it sends nothing.
 *              Routing: active LyytiDeletionAlert__mdt records by Campaign.Sales_Team__c (SalesTeam__c codes); the record
 *                  with a blank SalesTeam__c is the fallback for every other Sales Team and for campaigns without one.
 *                  One email per record, with its EmailTemplate__c, to its RecipientQueues__c members and RecipientEmails__c,
 *                  sent from the default "No Reply" org-wide address (EmailService.resolveOrgWideEmailAddressId).
 *              Names come from Contact / Lead: a deleted CampaignMember's own FirstName, LastName, Email and CompanyOrAccount are empty.
 * @author Charles EID
 * @testClass LyytiDeletionAlertServiceTest
 * @coverage TBD
 * @lastModifiedBy Charles EID   [27-10-26]
 ────────────────────────────────────── */
public without sharing class LyytiDeletionAlertService {

    private static final String DATATABLE = '{_Datatable_}';
    private static final String DEFAULT_SUBJECT = 'A campaign member has been deleted. Please remove them in Lyyti';
    private static final String MEMBER_QUERY = 'SELECT ContactId, Contact.FirstName, Contact.LastName, Contact.Email, Contact.Account.Name, Lead.FirstName, Lead.LastName, Lead.Email, Lead.Company, Campaign.Name, Campaign.Sales_Team__c, Campaign.LyytiURL__c FROM CampaignMember WHERE LyytiId__c != null AND ';

    public static void alertDeletedCampaignMembers(Set<Id> memberIds) {
        List<CampaignMember> members = queryLyytiMembers('Id IN :recordIds', memberIds);
        sendAlerts(members);
    }

    public static void alertDeletedContacts(Set<Id> contactIds) {
        List<CampaignMember> members = queryLyytiMembers('ContactId IN :recordIds AND IsDeleted = true ALL ROWS', contactIds);
        sendAlerts(members);
    }

    public static void alertDeletedLeads(Set<Id> leadIds) {
        List<CampaignMember> members = queryLyytiMembers('LeadId IN :recordIds AND IsDeleted = true ALL ROWS', leadIds);
        sendAlerts(members);
    }

    // recordIds is bound by name in the condition
    private static List<CampaignMember> queryLyytiMembers(String condition, Set<Id> recordIds) {
        return Database.query(MEMBER_QUERY + condition);
    }

    private static void sendAlerts(List<CampaignMember> members) {
        if (members.isEmpty()) return;

        Map<String, LyytiDeletionAlert__mdt> alertBySalesTeam = new Map<String, LyytiDeletionAlert__mdt>();
        LyytiDeletionAlert__mdt fallbackAlert;
        for (LyytiDeletionAlert__mdt alert : [SELECT DeveloperName, SalesTeam__c, RecipientQueues__c, RecipientEmails__c, EmailTemplate__c FROM LyytiDeletionAlert__mdt WHERE IsActive__c = true]) {
            if (String.isBlank(alert.SalesTeam__c)) {
                fallbackAlert = alert;
            }
            else {
                for (String salesTeam : splitValues(alert.SalesTeam__c)) alertBySalesTeam.put(salesTeam, alert);
            }
        }

        Map<String, LyytiDeletionAlert__mdt> alertsByName = new Map<String, LyytiDeletionAlert__mdt>();
        Map<String, List<CampaignMember>> membersByAlert = new Map<String, List<CampaignMember>>();
        for (CampaignMember member : members) {
            LyytiDeletionAlert__mdt alert = alertBySalesTeam.containsKey(member.Campaign.Sales_Team__c) ? alertBySalesTeam.get(member.Campaign.Sales_Team__c) : fallbackAlert;
            if (alert == null) continue;

            alertsByName.put(alert.DeveloperName, alert);
            if (!membersByAlert.containsKey(alert.DeveloperName)) membersByAlert.put(alert.DeveloperName, new List<CampaignMember>());
            membersByAlert.get(alert.DeveloperName).add(member);
        }
        if (membersByAlert.isEmpty()) return;

        Set<String> queueNames = new Set<String>();
        Set<String> templateNames = new Set<String>();
        for (LyytiDeletionAlert__mdt alert : alertsByName.values()) {
            queueNames.addAll(splitValues(alert.RecipientQueues__c));
            templateNames.add(alert.EmailTemplate__c);
        }
        Map<String, Set<String>> emailsByQueue = QueueMemberService.getQueueMemberEmails(queueNames);
        Map<String, EmailTemplate> templatesByName = new Map<String, EmailTemplate>();
        for (EmailTemplate template : [SELECT DeveloperName, Subject, HtmlValue FROM EmailTemplate WHERE DeveloperName IN :templateNames]) {
            templatesByName.put(template.DeveloperName, template);
        }

        Id orgWideEmailAddressId = EmailService.resolveOrgWideEmailAddressId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (LyytiDeletionAlert__mdt alert : alertsByName.values()) {
            Set<String> toAddresses = splitValues(alert.RecipientEmails__c);
            for (String queueName : splitValues(alert.RecipientQueues__c)) {
                if (emailsByQueue.containsKey(queueName)) toAddresses.addAll(emailsByQueue.get(queueName));
            }
            if (toAddresses.isEmpty()) continue;

            EmailTemplate template = templatesByName.get(alert.EmailTemplate__c);
            String templateHtml = (template != null && String.isNotBlank(template.HtmlValue)) ? template.HtmlValue : DATATABLE;
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject((template != null && String.isNotBlank(template.Subject)) ? template.Subject : DEFAULT_SUBJECT);
            mail.setToAddresses(new List<String>(toAddresses));
            mail.setHtmlBody(templateHtml.replace(DATATABLE, buildTableHtml(membersByAlert.get(alert.DeveloperName))));
            if (orgWideEmailAddressId != null) mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
            emails.add(mail);
        }
        if (emails.isEmpty()) return;

        // An email failure is logged and never blocks the delete that triggered it
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
            for (Messaging.SendEmailResult result : results) {
                if (!result.isSuccess()) OperationLogService.logWithContext(OperationLogService.Level.ERROR, (Id) null, 'LyytiDeletionAlertSend', 'Lyyti deletion alert email failed: ' + result.getErrors()[0].getMessage(), null, 'LyytiDeletionAlertService', 'sendAlerts');
            }
        }
        catch (Exception e) {
            OperationLogService.logWithContext(OperationLogService.Level.ERROR, (Id) null, 'LyytiDeletionAlertSend', 'Lyyti deletion alert emails could not be sent.', null, e, 'LyytiDeletionAlertService', 'sendAlerts');
        }
    }

    // Campaign.LyytiURL__c is a HYPERLINK formula: its value is already the "View in Lyyti" anchor
    private static String buildTableHtml(List<CampaignMember> members) {
        String html = '<table border="1" cellpadding="6" cellspacing="0" width="100%" style="border-collapse:collapse; font-family:arial; font-size:11pt;">'
            + '<thead><tr style="background-color:#003366; color:#FFFFFF;">'
            + '<th align="left">First Name</th>'
            + '<th align="left">Last Name</th>'
            + '<th align="left">Company</th>'
            + '<th align="left">Email</th>'
            + '<th align="left">Event</th>'
            + '<th align="left">Lyyti</th>'
            + '</tr></thead><tbody>';

        for (CampaignMember member : members) {
            Boolean isContact = member.ContactId != null;
            String company = isContact ? member.Contact.Account?.Name : member.Lead?.Company;
            String lyytiLink = String.isNotBlank(member.Campaign.LyytiURL__c) ? member.Campaign.LyytiURL__c : '';

            html += '<tr>'
                + '<td>' + htmlEscape(isContact ? member.Contact.FirstName : member.Lead?.FirstName) + '</td>'
                + '<td>' + htmlEscape(isContact ? member.Contact.LastName : member.Lead?.LastName) + '</td>'
                + '<td>' + htmlEscape(company) + '</td>'
                + '<td>' + htmlEscape(isContact ? member.Contact.Email : member.Lead?.Email) + '</td>'
                + '<td>' + htmlEscape(member.Campaign.Name) + '</td>'
                + '<td>' + lyytiLink + '</td>'
                + '</tr>';
        }

        html += '</tbody></table>';
        return html;
    }

    private static String htmlEscape(String value) {
        if (value == null) return '';
        return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }

    // Splits a "," or ";" separated configuration value (sales teams, queues, emails)
    private static Set<String> splitValues(String raw) {
        Set<String> result = new Set<String>();
        if (String.isBlank(raw)) return result;
        for (String value : raw.split('[,;]')) {
            if (String.isNotBlank(value)) result.add(value.trim());
        }
        return result;
    }
}