/** ──────────────────────────────────────
 * @description Microsoft Teams messages engine (US-20337), the Teams counterpart of the Custom Email Alerts: every message is a TeamsMessageRequest sent through send().
 *              new TeamsMessageRequest(customTeamsMessageName, recordId): filled from a CustomTeamsMessage__mdt record (used by the Flow action CustomTeamsMessageFlowAction).
 *              The message is built by EmailService.build() (isTeamsMessage): its CustomEmailRecipient__mdt rows (shared with a Custom Email Alert when a row points to both),
 *                  conditions, record fields, queues, public groups, Apex resolvers, template render, replacements, dry run and No Recipient fallback work as for an email.
 *                  Every recipient (To, Cc or Bcc of the rows) receives the template's HTML body in a 1:1 chat; there is no subject, as with the former WS_QueueableLauncher.
 *              Configuration errors (unknown Teams message, template, queue, group, invalid condition) throw before anything is sent, like emails.
 *              The callouts can't run in the caller's transaction (a record-triggered Flow has pending work): send() hands the messages to TeamsMessageQueueable,
 *                  which logs the recipients it could not reach (LogFailures__c). A message sent to the No Recipient Addresses is logged here (WARN).
 *              Sent from the Microsoft 365 account of the Named Credential (NamedCredential__c, default MicrosoftGraph), exactly like WS_QueueableLauncher.
 * @author Charles EID
 * @testClass TeamsMessageServiceTest
 * @coverage 98%   [12-11-26]
 ────────────────────────────────────── */
public without sharing class TeamsMessageService {

    // Loaded once per Teams message per transaction: a bulk Flow builds one request per record with the same message
    private static Map<String, CustomTeamsMessage__mdt> messagesByName = new Map<String, CustomTeamsMessage__mdt>();
    private static Map<String, List<CustomEmailRecipient__mdt>> recipientRulesByMessageName = new Map<String, List<CustomEmailRecipient__mdt>>();

    // Builds the messages (recipients, content) in the caller's transaction, so a configuration error stops it, then sends them from a queueable
    public static void send(List<TeamsMessageRequest> requests) {
        List<Delivery> deliveries = build(requests);
        for (TeamsMessageRequest request : requests) {
            if (request.emailRequest.noRecipient && request.emailRequest.logFailures) OperationLogService.logWithContext(OperationLogService.Level.WARN, request.emailRequest.whatId, request.emailRequest.logOperation, 'No recipient: the Teams message was sent to the No Recipient Addresses (Custom Setting Email and Notification Service Settings).', new Map<String, Object>{ 'customTeamsMessageName' => request.emailRequest.customAlertName }, null, 'TeamsMessageService', 'send');
        }
        if (!deliveries.isEmpty()) System.enqueueJob(new TeamsMessageQueueable(deliveries));
    }

    // The Teams messages send() would send, one per recipient, without sending them (preview, checks, tests)
    public static List<Delivery> build(List<TeamsMessageRequest> requests) {
        List<EmailService.EmailRequest> emailRequests = new List<EmailService.EmailRequest>();
        for (TeamsMessageRequest request : requests) emailRequests.add(request.emailRequest);
        List<EmailService.EmailRequest> requestByEmail = new List<EmailService.EmailRequest>();
        List<Messaging.SingleEmailMessage> emails = EmailService.build(emailRequests, requestByEmail);

        // A request above 100 To / 25 Cc / 25 Bcc gives several messages with the same body: each address is in one of them
        List<Delivery> deliveries = new List<Delivery>();
        for (Integer i = 0; i < emails.size(); i++) {
            TeamsMessageRequest request = findRequest(requests, requestByEmail[i]);
            for (String address : getAddresses(emails[i])) deliveries.add(new Delivery(address, emails[i].getHtmlBody(), request));
        }
        return deliveries;
    }

    private static CustomTeamsMessage__mdt getMessage(String customTeamsMessageName) {
        if (!messagesByName.containsKey(customTeamsMessageName)) {
            List<CustomTeamsMessage__mdt> messages = [SELECT DeveloperName, IsActive__c, DryRun__c, MessageTemplate__c, NamedCredential__c, LogFailures__c
                                                      FROM CustomTeamsMessage__mdt
                                                      WHERE DeveloperName = :customTeamsMessageName];
            if (messages.isEmpty()) throw new EmailService.EmailServiceException('Custom Teams Message "' + customTeamsMessageName + '" not found.');
            List<CustomEmailRecipient__mdt> rules = [SELECT DeveloperName, SendAs__c, Type__c, Value__c, Condition__c
                                                     FROM CustomEmailRecipient__mdt
                                                     WHERE CustomTeamsMessage__r.DeveloperName = :customTeamsMessageName AND IsActive__c = true
                                                     ORDER BY DeveloperName];
            messagesByName.put(customTeamsMessageName, messages[0]);
            recipientRulesByMessageName.put(customTeamsMessageName, rules);
        }
        return messagesByName.get(customTeamsMessageName);
    }

    private static TeamsMessageRequest findRequest(List<TeamsMessageRequest> requests, EmailService.EmailRequest emailRequest) {
        for (TeamsMessageRequest request : requests) {
            if (request.emailRequest === emailRequest) return request;
        }
        return null;
    }

    private static List<String> getAddresses(Messaging.SingleEmailMessage email) {
        List<String> addresses = new List<String>();
        for (List<String> listAddresses : new List<List<String>>{ email.getToAddresses(), email.getCcAddresses(), email.getBccAddresses() }) {
            if (listAddresses != null) addresses.addAll(listAddresses);
        }
        return addresses;
    }

    public class TeamsMessageRequest {
        // Built and checked by EmailService (isTeamsMessage); the caller can still add addresses, replacements or a dry run before send()
        public EmailService.EmailRequest emailRequest = new EmailService.EmailRequest();
        public String namedCredential = WS_GetUserGraphApi.DEFAULT_NC;

        public TeamsMessageRequest(String customTeamsMessageName, Id recordId) {
            CustomTeamsMessage__mdt message = getMessage(customTeamsMessageName);
            emailRequest.isTeamsMessage = true;
            emailRequest.customAlertName = message.DeveloperName;
            emailRequest.isActive = message.IsActive__c;
            emailRequest.dryRun = message.DryRun__c;
            emailRequest.templateDeveloperName = message.MessageTemplate__c;
            emailRequest.whatId = recordId;
            emailRequest.recipientRules.addAll(recipientRulesByMessageName.get(customTeamsMessageName));
            // No org-wide address to look up: Teams sends from the Named Credential's account
            emailRequest.sender = EmailService.Sender.CURRENT_USER;
            emailRequest.logFailures = message.LogFailures__c;
            emailRequest.logOperation = 'Custom Teams Message ' + message.DeveloperName;
            if (String.isNotBlank(message.NamedCredential__c)) namedCredential = message.NamedCredential__c.trim();
        }
    }

    // One recipient of one message: what TeamsMessageQueueable sends and logs
    public class Delivery {
        public String address { get; private set; }
        public String content { get; private set; }
        public Id recordId { get; private set; }
        public String messageName { get; private set; }
        public String namedCredential { get; private set; }
        public String logOperation { get; private set; }
        public Boolean logFailures { get; private set; }

        public Delivery(String address, String content, TeamsMessageRequest request) {
            this.address = address;
            this.content = content;
            this.recordId = request.emailRequest.whatId;
            this.messageName = request.emailRequest.customAlertName;
            this.namedCredential = request.namedCredential;
            this.logOperation = request.emailRequest.logOperation;
            this.logFailures = request.emailRequest.logFailures;
        }
    }
}
