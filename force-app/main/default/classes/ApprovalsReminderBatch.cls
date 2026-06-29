/** ──────────────────────────────────────
 * @description Batch class for the Approvals Reminder alert framework.
 *              Iterates over all active ApprovalsReminder__mdt records (one per batch transaction)
 *                  and sends an HTML alert email to configured recipient queues listing approval items
 *                  that have been pending longer than the configured threshold.
 *              Uses Database.Batchable<Object> with Iterable<Object> so CMDT records can be batched
 *                  without Database.getQueryLocator. Batch size is always 1 for governor-limit isolation.
 *              Implements ICustomAlerter to be dispatched dynamically by CustomAlertScheduler.
 * @author Charles EID
 * @testClass ApprovalsReminderBatchTest
 * @coverage 96%   [26-06-26]
 ────────────────────────────────────── */
public with sharing class ApprovalsReminderBatch implements Database.Batchable<Object>, Database.Stateful, ICustomAlerter {

    private static final String DATATABLE = '{_Datatable_}';
    private ScheduledAlert__mdt alertConfig;

    @TestVisible private static Map<String, Set<String>> testEmailsByQueueOverride;

    public ApprovalsReminderBatch() {}

    public ApprovalsReminderBatch(ScheduledAlert__mdt config) {
        this.alertConfig = config;
    }

    // ICustomAlerter entry point — always batchSize = 1 for per-transaction isolation per reminder config
    public void dispatch(ScheduledAlert__mdt config) {
        Database.executeBatch(new ApprovalsReminderBatch(config), 1);
    }

    public Iterable<Object> start(Database.BatchableContext bc) {
        return (List<Object>) [SELECT Label, ObjectApiNames__c, ApprovalSystem__c, SourceQueues__c, RecipientQueues__c, CCRecipientQueues__c, BCCRecipientQueues__c, OverrideEmailTemplate__c, ThresholdDays__c
                               FROM ApprovalsReminder__mdt
                               WHERE IsActive__c = true];
    }

    public void execute(Database.BatchableContext bc, List<Object> scope) {
        ApprovalsReminder__mdt reminder = (ApprovalsReminder__mdt) scope[0];
        String orgBaseUrl = URL.getOrgDomainUrl().toExternalForm();

        List<CustomApprovalInboxController.ItemToApprove> items = CustomApprovalInboxController.getItemsToApprove(reminder.ObjectApiNames__c, reminder.ApprovalSystem__c, reminder.SourceQueues__c);

        Integer threshold = reminder.ThresholdDays__c != null ? (Integer) reminder.ThresholdDays__c : 30;
        Date cutoff = Date.today().addDays(-threshold);

        List<CustomApprovalInboxController.ItemToApprove> overdue = new List<CustomApprovalInboxController.ItemToApprove>();
        for (CustomApprovalInboxController.ItemToApprove item : items) {
            if (item.submissionDate != null && item.submissionDate.date() <= cutoff) {
                overdue.add(item);
            }
        }
        if (overdue.isEmpty()) return;

        Set<String> toQueues  = parseCommaSeparated(reminder.RecipientQueues__c);
        Set<String> ccQueues  = parseCommaSeparated(reminder.CCRecipientQueues__c);
        Set<String> bccQueues = parseCommaSeparated(reminder.BCCRecipientQueues__c);

        Set<String> allQueues = new Set<String>();
        allQueues.addAll(toQueues);
        allQueues.addAll(ccQueues);
        allQueues.addAll(bccQueues);

        if (allQueues.isEmpty()) return;

        Map<String, Set<String>> emailsByQueue = testEmailsByQueueOverride != null ? testEmailsByQueueOverride : QueueMemberService.getQueueMemberEmails(allQueues);

        Set<String> toAddresses  = mergeEmails(toQueues,  emailsByQueue);
        Set<String> ccAddresses  = mergeEmails(ccQueues,  emailsByQueue);
        Set<String> bccAddresses = mergeEmails(bccQueues, emailsByQueue);

        if (toAddresses.isEmpty()) return;

        String templateDevName = String.isNotBlank(reminder.OverrideEmailTemplate__c) ? reminder.OverrideEmailTemplate__c : (alertConfig != null ? alertConfig.EmailTemplate__c : null);
        String templateHtml = getEmailTemplateHtml(templateDevName);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject('Pending Approvals Alert — ' + reminder.Label + ' (> ' + threshold + ' days)');
        mail.setToAddresses(new List<String>(toAddresses));
        if (!ccAddresses.isEmpty())  mail.setCcAddresses(new List<String>(ccAddresses));
        if (!bccAddresses.isEmpty()) mail.setBccAddresses(new List<String>(bccAddresses));
        mail.setHtmlBody(templateHtml.replace(DATATABLE, buildTableHtml(overdue, orgBaseUrl)));

        if (!Test.isRunningTest()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            for (Messaging.SendEmailResult result : results) {
                if (!result.isSuccess()) {
                    System.debug('ApprovalsReminderBatch email error: ' + result.getErrors()[0].getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {}

    // ─── HTML table ──────────────────────────────────────────────────────────────
    private String buildTableHtml(List<CustomApprovalInboxController.ItemToApprove> items, String orgBaseUrl) {
        String html = '<table border="1" cellpadding="6" cellspacing="0" width="100%" style="border-collapse:collapse; font-family:arial; font-size:11pt;">'
            + '<thead><tr style="background-color:#003366; color:#FFFFFF;">'
            + '<th align="left">Record</th>'
            + '<th align="left">Object</th>'
            + '<th align="left">Submitted By</th>'
            + '<th align="left">Step</th>'
            + '<th align="left">Pending Since</th>'
            + '</tr></thead><tbody>';

        for (CustomApprovalInboxController.ItemToApprove item : items) {
            String recordUrl     = orgBaseUrl + '/' + (item.isStandardApproval ? item.stepId : item.targetRecordId);
            String recordName    = item.targetRecordName != null ? item.targetRecordName : '';
            String objectLabel   = item.objectLabel != null ? item.objectLabel : '';
            String submittedBy   = item.submittedByName != null ? item.submittedByName : '';
            String stepLabel     = item.stepLabel != null ? item.stepLabel : '';
            String pendingSince  = item.submissionDateFormatted != null ? item.submissionDateFormatted : '';

            html += '<tr>'
                + '<td><a href="' + recordUrl + '">' + recordName + '</a></td>'
                + '<td>' + objectLabel  + '</td>'
                + '<td>' + submittedBy  + '</td>'
                + '<td>' + stepLabel    + '</td>'
                + '<td>' + pendingSince + '</td>'
                + '</tr>';
        }

        html += '</tbody></table>';
        return html;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────
    private String getEmailTemplateHtml(String devName) {
        if (String.isBlank(devName)) return DATATABLE;
        List<EmailTemplate> templates = [SELECT HtmlValue FROM EmailTemplate WHERE DeveloperName = :devName LIMIT 1];
        return (templates.isEmpty() || String.isBlank(templates[0].HtmlValue)) ? DATATABLE : templates[0].HtmlValue;
    }

    private static Set<String> parseCommaSeparated(String raw) {
        Set<String> result = new Set<String>();
        if (String.isBlank(raw)) return result;
        for (String s : raw.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) result.add(trimmed);
        }
        return result;
    }

    private static Set<String> mergeEmails(Set<String> queueNames, Map<String, Set<String>> emailsByQueue) {
        Set<String> emails = new Set<String>();
        for (String q : queueNames) {
            Set<String> qEmails = emailsByQueue.get(q);
            if (qEmails != null) emails.addAll(qEmails);
        }
        return emails;
    }
}