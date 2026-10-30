/** ──────────────────────────────────────
 * @description Utility service for sending template-based email notifications
 *              as part of the custom approval process.
 *              Resolves recipient IDs from approver sets, queue memberships,
 *              submitted-by references, record owners, and additional addressee lists.
 *              Email engine (US-ImproveEmailServiceEngine): every email is an EmailRequest sent through send().
 *                  - new EmailRequest(): Apex fills the template or subject/body and the recipients itself.
 *                  - new EmailRequest(customAlertName, recordId): filled from a CustomEmailAlert__mdt record (used by the
 *                    Flow action CustomEmailAlertFlowAction); the caller can still override or add anything before send().
 *              The template is always rendered (renderStoredEmailTemplate: Classic, Lightning, Visualforce), once per distinct
 *                  template / recipient / record, then the replacements are applied. Each render costs 1 SOQL query.
 *              To / Cc / Bcc = addresses + queue members + users of userOrGroupIds, split into several identical messages
 *                  above 100 To / 25 Cc / 25 Bcc, all sent in a single Messaging.sendEmail.
 *              Configuration errors (unknown alert, template, queue or org-wide address, invalid recipient, no To recipient)
 *                  throw EmailServiceException before anything is sent. Send failures never throw: they are logged in
 *                  OperationLog__c (logFailures). The engine never flushes OperationLogService: the entry point flushes,
 *                  and send() must come after any callout of the transaction (sendEmail is pending work).
 * @author Charles EID
 * @testClass EmailServiceTest
 * @coverage TBD
 * @lastModifiedBy Charles EID   [30-10-26]
────────────────────────────────────── */
public without sharing class EmailService {

    private static final String DEFAULT_ORG_WIDE_ADDRESS = Label.EmailService_DefaultOrgWideAddress;
    private static final String DEFAULT_LOG_OPERATION = 'Email send';
    private static final Integer MAX_TO_ADDRESSES = 100;
    private static final Integer MAX_CC_BCC_ADDRESSES = 25;

    // Loaded once per alert per transaction: a bulk Flow builds one request per record with the same alert
    private static Map<String, CustomEmailAlert__mdt> alertsByName = new Map<String, CustomEmailAlert__mdt>();
    private static Map<String, Id> orgWideIdsByAddress = new Map<String, Id>();

    public enum Sender { NO_REPLY, CURRENT_USER, ORG_WIDE }

    public class EmailServiceException extends Exception {}

    // Builds then sends every active request in a single Messaging.sendEmail; send failures are logged, never thrown
    public static void send(List<EmailRequest> requests) {
        List<EmailRequest> requestByEmail = new List<EmailRequest>();
        List<Messaging.SingleEmailMessage> emails = buildEmails(requests, requestByEmail);
        if (emails.isEmpty()) return;

        try {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) logFailure(requestByEmail[i], emails[i], results[i].getErrors()[0].getMessage(), null);
            }
        }
        catch (EmailException e) {
            // Deliverability "No Access" / "System email only" is an org setting, not a failure
            if (e.getDmlType(0) == StatusCode.NO_SINGLE_MAIL_PERMISSION) return;
            for (EmailRequest request : requests) {
                if (request.isActive) logFailure(request, null, 'The emails could not be sent.', e);
            }
        }
    }

    // The exact messages send() would send, without sending them (preview, checks, tests)
    public static List<Messaging.SingleEmailMessage> build(List<EmailRequest> requests) {
        return buildEmails(requests, new List<EmailRequest>());
    }

    public static void sendTemplateEmail(String templateDeveloperName, Id whatId, Set<Id> recipientUserIds) {
        sendTemplateEmail(templateDeveloperName, whatId, recipientUserIds, new List<String>());
    }

    // Overload: also delivers to raw email addresses that aren't tied to a Salesforce User (e.g. a shared ops mailbox).
    public static void sendTemplateEmail(String templateDeveloperName, Id whatId, Set<Id> recipientUserIds, List<String> additionalEmailAddresses) {
        Boolean hasUserRecipients = recipientUserIds != null && !recipientUserIds.isEmpty();
        Boolean hasRawRecipients = additionalEmailAddresses != null && !additionalEmailAddresses.isEmpty();
        if (!hasUserRecipients && !hasRawRecipients) return;

        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null) return;

        Id orgWideEmailAddressId = resolveOrgWideEmailAddressId();

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        if (hasUserRecipients) {
            emailList.addAll(buildUserEmails(templateId, whatId, recipientUserIds, orgWideEmailAddressId));
        }
        if (hasRawRecipients) {
            emailList.addAll(buildRawAddressEmails(templateId, whatId, additionalEmailAddresses, orgWideEmailAddressId));
        }

        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList, false);
        }
    }

    public static Set<Id> resolveRecipientIds(Set<String> recipientTypeValues, Set<Id> currentApproverIds, Set<Id> nextApproverIds, Id submittedById, Id targetRecordId, String objectApiName) {
        Set<Id> result = new Set<Id>();
        if (recipientTypeValues == null || recipientTypeValues.isEmpty()) return result;

        for (String recipientType : recipientTypeValues) {
            if (recipientType == 'CurrentStepApprovers' && currentApproverIds != null) {
                result.addAll(expandApproverIds(currentApproverIds));
            } 
            else if (recipientType == 'NextStepApprovers' && nextApproverIds != null) {
                result.addAll(expandApproverIds(nextApproverIds));
            } 
            else if (recipientType == 'Submitter' && submittedById != null) {
                result.add(submittedById);
            } 
            else if (recipientType == 'RecordOwner' && targetRecordId != null && String.isNotBlank(objectApiName)) {
                try {
                    SObject record = Database.query('SELECT OwnerId FROM ' + objectApiName + ' WHERE Id = :targetRecordId LIMIT 1');
                    result.add((Id) record.get('OwnerId'));
                } catch (Exception e) {
                    OperationLogService.logWithContext(OperationLogService.Level.ERROR, targetRecordId, 'EmailServiceResolveRecordOwner', 'Failed to resolve the owner of ' + objectApiName + ' while building alert recipients.', new Map<String, Object>{ 'objectApiName' => objectApiName, 'targetRecordId' => targetRecordId, 'exceptionMessage' => e.getMessage() }, e, 'EmailService', 'resolveRecipientIds');
                }
            }
        }
        return result;
    }

    public static Set<Id> resolveAdditionalRecipientIds(String additionalQueues, String additionalUsers) {
        Set<Id> result = new Set<Id>();

        if (String.isNotBlank(additionalQueues)) {
            Set<String> queueNames = new Set<String>();
            for (String name : additionalQueues.split(',')) queueNames.add(name.trim());

            Set<Id> queueIds = new Set<Id>();
            for (Group g : [SELECT Id FROM Group WHERE DeveloperName IN :queueNames AND Type = 'Queue']) {
                queueIds.add(g.Id);
            }
            Map<Id, List<Id>> memberMap = QueueMemberService.resolveMembers(queueIds);
            for (List<Id> ids : memberMap.values()) result.addAll(ids);
        }

        if (String.isNotBlank(additionalUsers)) {
            Set<String> usernames = new Set<String>();
            for (String name : additionalUsers.split(',')) usernames.add(name.trim());
            for (User u : [SELECT Id FROM User WHERE Username IN :usernames AND IsActive = true]) {
                result.add(u.Id);
            }
        }

        return result;
    }

    private static Set<Id> expandApproverIds(Set<Id> approverIds) {
        Map<Id, List<Id>> resolved = QueueMemberService.resolveMembers(approverIds);
        Set<Id> userIds = new Set<Id>();
        for (List<Id> members : resolved.values()) userIds.addAll(members);
        return userIds;
    }

    private static Id resolveTemplateId(String templateDeveloperName) {
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    // Default "No Reply" sender (label EmailService_DefaultOrgWideAddress), also used by LyytiDeletionAlertService
    public static Id resolveOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :DEFAULT_ORG_WIDE_ADDRESS];
        return owea.isEmpty() ? null : owea[0].Id;
    }

    private static List<Messaging.SingleEmailMessage> buildUserEmails(Id templateId, Id whatId, Set<Id> recipientUserIds, Id orgWideEmailAddressId) {
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        Map<Id, String> userEmails = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :recipientUserIds AND IsActive = true]) {
            if (String.isNotBlank(u.Email)) {
                userEmails.put(u.Id, u.Email);
            }
        }

        for (Id userId : recipientUserIds) {
            if (String.isBlank(userEmails.get(userId))) continue;

            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, userId, whatId);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(userId);
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(rendered.getHtmlBody());
            mail.setPlainTextBody(rendered.getPlainTextBody());
            mail.setSaveAsActivity(false);
            if (orgWideEmailAddressId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }
            emailList.add(mail);
        }

        return emailList;
    }

    // Raw addresses have no Salesforce User Id, so the template is rendered once without a "who" and reused for each address.
    private static List<Messaging.SingleEmailMessage> buildRawAddressEmails(Id templateId, Id whatId, List<String> emailAddresses, Id orgWideEmailAddressId) {
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, null, whatId);

        for (String address : emailAddresses) {
            if (String.isBlank(address)) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ address.trim() });
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(rendered.getHtmlBody());
            mail.setPlainTextBody(rendered.getPlainTextBody());
            mail.setSaveAsActivity(false);
            if (orgWideEmailAddressId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }
            emailList.add(mail);
        }

        return emailList;
    }

    // Resolves templates, queues, users and senders in bulk, renders, applies the replacements and splits the recipients; requestByEmail receives the request of each message
    private static List<Messaging.SingleEmailMessage> buildEmails(List<EmailRequest> requests, List<EmailRequest> requestByEmail) {
        List<EmailRequest> activeRequests = new List<EmailRequest>();
        Set<String> templateNames = new Set<String>();
        Set<String> queueNames = new Set<String>();
        Set<Id> userOrGroupIds = new Set<Id>();
        Set<String> orgWideAddresses = new Set<String>();
        for (EmailRequest request : requests) {
            if (!request.isActive) continue;

            activeRequests.add(request);
            if (String.isNotBlank(request.templateDeveloperName)) templateNames.add(request.templateDeveloperName);
            for (Recipients recipients : new List<Recipients>{ request.to, request.cc, request.bcc }) {
                queueNames.addAll(recipients.queues);
                userOrGroupIds.addAll(recipients.userOrGroupIds);
            }
            String senderAddress = getSenderAddress(request);
            if (senderAddress != null) orgWideAddresses.add(senderAddress);
        }
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        if (activeRequests.isEmpty()) return emails;

        Map<String, Id> templateIdsByName = getTemplateIds(templateNames);
        Map<String, Set<String>> emailsByQueue = QueueMemberService.getQueueMemberEmails(queueNames);
        checkAllFound(queueNames, emailsByQueue.keySet(), 'Queue(s)');
        Map<Id, Set<String>> emailsByUserOrGroupId = getUserOrGroupEmails(userOrGroupIds);
        loadOrgWideAddresses(orgWideAddresses);

        // Each render costs 1 SOQL query: identical template / recipient / record are rendered once
        Map<String, Messaging.SingleEmailMessage> renderedByKey = new Map<String, Messaging.SingleEmailMessage>();
        for (EmailRequest request : activeRequests) {
            Schema.SObjectType recipientType = request.recipientId?.getSObjectType();
            if (recipientType != null && recipientType != Contact.SObjectType && recipientType != Lead.SObjectType && recipientType != User.SObjectType) throw new EmailServiceException(describe(request) + ': the recipient must be a Contact, Lead or User, not a ' + recipientType + '.');

            String subject = request.subject;
            String htmlBody = request.htmlBody;
            String textBody;
            if (String.isNotBlank(request.templateDeveloperName)) {
                Id templateId = templateIdsByName.get(request.templateDeveloperName);
                String renderKey = templateId + '|' + request.recipientId + '|' + request.whatId;
                if (!renderedByKey.containsKey(renderKey)) renderedByKey.put(renderKey, Messaging.renderStoredEmailTemplate(templateId, request.recipientId, request.whatId));
                Messaging.SingleEmailMessage rendered = renderedByKey.get(renderKey);
                subject = String.isNotBlank(request.subject) ? request.subject : rendered.getSubject();
                htmlBody = rendered.getHtmlBody();
                textBody = rendered.getPlainTextBody();
            }
            else if (String.isBlank(request.subject) || String.isBlank(request.htmlBody)) {
                throw new EmailServiceException(describe(request) + ' has no template, so it needs a subject and an HTML body.');
            }
            subject = applyReplacements(subject, request.replacements);
            htmlBody = applyReplacements(htmlBody, request.replacements);
            textBody = applyReplacements(textBody, request.replacements);

            List<String> toAddresses = resolveAddresses(request.to, emailsByQueue, emailsByUserOrGroupId);
            List<String> ccAddresses = resolveAddresses(request.cc, emailsByQueue, emailsByUserOrGroupId);
            List<String> bccAddresses = resolveAddresses(request.bcc, emailsByQueue, emailsByUserOrGroupId);
            if (toAddresses.isEmpty() && request.recipientId == null) throw new EmailServiceException(describe(request) + ' has no To recipient (no To address, no member in its To queues and no recipient record).');

            String senderAddress = getSenderAddress(request);
            Id orgWideId = senderAddress != null ? orgWideIdsByAddress.get(senderAddress) : null;

            // A message takes at most 100 To / 25 Cc / 25 Bcc: above that, identical messages share the addresses out, each address in exactly one of them
            Integer messageCount = Math.max(1, Math.max(countChunks(toAddresses.size(), MAX_TO_ADDRESSES), Math.max(countChunks(ccAddresses.size(), MAX_CC_BCC_ADDRESSES), countChunks(bccAddresses.size(), MAX_CC_BCC_ADDRESSES))));
            for (Integer i = 0; i < messageCount; i++) {
                List<String> toChunk = slice(toAddresses, i, MAX_TO_ADDRESSES);
                List<String> ccChunk = slice(ccAddresses, i, MAX_CC_BCC_ADDRESSES);
                List<String> bccChunk = slice(bccAddresses, i, MAX_CC_BCC_ADDRESSES);

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                if (!toChunk.isEmpty()) email.setToAddresses(toChunk);
                if (!ccChunk.isEmpty()) email.setCcAddresses(ccChunk);
                if (!bccChunk.isEmpty()) email.setBccAddresses(bccChunk);
                if (i == 0 && request.recipientId != null) email.setTargetObjectId(request.recipientId);
                email.setSubject(subject);
                if (String.isNotBlank(htmlBody)) email.setHtmlBody(htmlBody);
                if (String.isNotBlank(textBody)) email.setPlainTextBody(textBody);
                if (orgWideId != null) email.setOrgWideEmailAddressId(orgWideId);
                email.setSaveAsActivity(false);
                emails.add(email);
                requestByEmail.add(request);
            }
        }
        return emails;
    }

    // Static cache per alert name; SOQL rather than getInstance(), which cuts long text areas to 255 characters
    private static CustomEmailAlert__mdt getAlert(String customAlertName) {
        if (!alertsByName.containsKey(customAlertName)) {
            List<CustomEmailAlert__mdt> alerts = [SELECT DeveloperName, IsActive__c, EmailTemplate__c, ToAddresses__c, CcAddresses__c, BccAddresses__c, ToQueues__c, CcQueues__c, BccQueues__c, Sender__c, OrgWideAddress__c, LogFailures__c
                                                  FROM CustomEmailAlert__mdt
                                                  WHERE DeveloperName = :customAlertName];
            if (alerts.isEmpty()) throw new EmailServiceException('Custom Email Alert "' + customAlertName + '" not found.');
            alertsByName.put(customAlertName, alerts[0]);
        }
        return alertsByName.get(customAlertName);
    }

    private static Map<String, Id> getTemplateIds(Set<String> templateNames) {
        Map<String, Id> templateIdsByName = new Map<String, Id>();
        if (templateNames.isEmpty()) return templateIdsByName;

        for (EmailTemplate template : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :templateNames]) templateIdsByName.put(template.DeveloperName, template.Id);
        checkAllFound(templateNames, templateIdsByName.keySet(), 'Email template(s)');
        return templateIdsByName;
    }

    // Emails of the active users behind each User / Queue / Group Id (direct members, public groups and roles)
    private static Map<Id, Set<String>> getUserOrGroupEmails(Set<Id> userOrGroupIds) {
        Map<Id, Set<String>> emailsByUserOrGroupId = new Map<Id, Set<String>>();
        if (userOrGroupIds.isEmpty()) return emailsByUserOrGroupId;

        Map<Id, List<Id>> userIdsByUserOrGroupId = QueueMemberService.resolveMembers(userOrGroupIds);
        Set<Id> userIds = new Set<Id>();
        for (List<Id> ids : userIdsByUserOrGroupId.values()) userIds.addAll(ids);
        Map<Id, User> users = new Map<Id, User>([SELECT Email FROM User WHERE Id IN :userIds AND IsActive = true AND Email != null]);
        for (Id userOrGroupId : userIdsByUserOrGroupId.keySet()) {
            Set<String> emails = new Set<String>();
            for (Id userId : userIdsByUserOrGroupId.get(userOrGroupId)) {
                if (users.containsKey(userId)) emails.add(users.get(userId).Email);
            }
            emailsByUserOrGroupId.put(userOrGroupId, emails);
        }
        return emailsByUserOrGroupId;
    }

    // Org-wide address Ids are cached per transaction (lower-case keys); an address that isn't an org-wide address throws
    private static void loadOrgWideAddresses(Set<String> addresses) {
        Set<String> missingAddresses = new Set<String>();
        for (String address : addresses) {
            if (!orgWideIdsByAddress.containsKey(address)) missingAddresses.add(address);
        }
        if (!missingAddresses.isEmpty()) {
            for (OrgWideEmailAddress owea : [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address IN :missingAddresses]) orgWideIdsByAddress.put(owea.Address.toLowerCase(), owea.Id);
        }
        checkAllFound(addresses, orgWideIdsByAddress.keySet(), 'Org-wide email address(es)');
    }

    // Lower-case org-wide address the request is sent from, null for the current user
    private static String getSenderAddress(EmailRequest request) {
        if (request.sender == EmailService.Sender.NO_REPLY) return DEFAULT_ORG_WIDE_ADDRESS.toLowerCase();
        if (request.sender != EmailService.Sender.ORG_WIDE) return null;
        if (String.isBlank(request.orgWideAddress)) throw new EmailServiceException(describe(request) + ' is sent from an org-wide address but has no orgWideAddress.');
        return request.orgWideAddress.trim().toLowerCase();
    }

    private static void checkAllFound(Set<String> requestedNames, Set<String> foundNames, String label) {
        Set<String> missingNames = requestedNames.clone();
        missingNames.removeAll(foundNames);
        if (!missingNames.isEmpty()) throw new EmailServiceException(label + ' not found: ' + String.join(new List<String>(missingNames), ', ') + '.');
    }

    // Addresses + queue members + users of userOrGroupIds, without duplicates (case-insensitive)
    private static List<String> resolveAddresses(Recipients recipients, Map<String, Set<String>> emailsByQueue, Map<Id, Set<String>> emailsByUserOrGroupId) {
        Set<String> addresses = new Set<String>();
        for (String address : recipients.addresses) {
            if (String.isNotBlank(address)) addresses.add(address.trim().toLowerCase());
        }
        for (String queueName : recipients.queues) {
            for (String address : emailsByQueue.get(queueName)) addresses.add(address.toLowerCase());
        }
        for (Id userOrGroupId : recipients.userOrGroupIds) {
            for (String address : emailsByUserOrGroupId.get(userOrGroupId)) addresses.add(address.toLowerCase());
        }
        return new List<String>(addresses);
    }

    private static String applyReplacements(String value, Map<String, String> replacements) {
        if (value == null) return null;

        for (String token : replacements.keySet()) {
            if (String.isNotBlank(token)) value = value.replace(token, replacements.get(token) == null ? '' : replacements.get(token));
        }
        return value;
    }

    private static Integer countChunks(Integer size, Integer chunkSize) {
        return (size + chunkSize - 1) / chunkSize;
    }

    private static List<String> slice(List<String> values, Integer chunkIndex, Integer chunkSize) {
        List<String> chunk = new List<String>();
        for (Integer i = chunkIndex * chunkSize; i < Math.min(values.size(), (chunkIndex + 1) * chunkSize); i++) chunk.add(values[i]);
        return chunk;
    }

    // Splits a configuration text area: one value per line (commas and semicolons are accepted too)
    private static Set<String> splitValues(String raw) {
        Set<String> values = new Set<String>();
        if (String.isBlank(raw)) return values;

        for (String value : raw.split('[\\r\\n,;]+')) {
            if (String.isNotBlank(value)) values.add(value.trim());
        }
        return values;
    }

    // Logs a send failure on the request's record, when the request asks for it (logFailures); never flushes
    private static void logFailure(EmailRequest request, Messaging.SingleEmailMessage email, String errorMessage, Exception e) {
        if (request.logFailures != true) return;

        Map<String, Object> context = new Map<String, Object>{ 'customAlertName' => request.customAlertName, 'template' => request.templateDeveloperName, 'subject' => email?.getSubject(), 'toAddresses' => email?.getToAddresses(), 'targetObjectId' => email?.getTargetObjectId() };
        OperationLogService.logWithContext(OperationLogService.Level.ERROR, request.whatId, String.isNotBlank(request.logOperation) ? request.logOperation : DEFAULT_LOG_OPERATION, errorMessage, context, e, 'EmailService', 'send');
    }

    private static String describe(EmailRequest request) {
        String name = String.isNotBlank(request.customAlertName) ? request.customAlertName : String.isNotBlank(request.templateDeveloperName) ? request.templateDeveloperName : request.subject;
        return String.isBlank(name) ? 'Email request' : 'Email "' + name + '"';
    }

    // One recipient list (To, Cc or Bcc), whatever its sources; a new source = one new field here
    public class Recipients {
        public Set<String> addresses = new Set<String>();
        public Set<String> queues = new Set<String>();
        public Set<Id> userOrGroupIds = new Set<Id>();
    }

    public class EmailRequest {
        public String templateDeveloperName;
        public Id whatId;
        public Id recipientId;
        public String subject;
        public String htmlBody;
        public Map<String, String> replacements = new Map<String, String>();
        public Recipients to = new Recipients();
        public Recipients cc = new Recipients();
        public Recipients bcc = new Recipients();
        public EmailService.Sender sender = EmailService.Sender.NO_REPLY;
        public String orgWideAddress;
        public Boolean logFailures = true;
        public String logOperation;
        public String customAlertName;
        public Boolean isActive = true;

        public EmailRequest() {}

        public EmailRequest(String customAlertName, Id recordId) {
            CustomEmailAlert__mdt alert = getAlert(customAlertName);
            this.customAlertName = alert.DeveloperName;
            this.isActive = alert.IsActive__c;
            this.templateDeveloperName = alert.EmailTemplate__c;
            this.whatId = recordId;
            this.to.addresses.addAll(splitValues(alert.ToAddresses__c));
            this.cc.addresses.addAll(splitValues(alert.CcAddresses__c));
            this.bcc.addresses.addAll(splitValues(alert.BccAddresses__c));
            this.to.queues.addAll(splitValues(alert.ToQueues__c));
            this.cc.queues.addAll(splitValues(alert.CcQueues__c));
            this.bcc.queues.addAll(splitValues(alert.BccQueues__c));
            this.sender = EmailService.Sender.valueOf(alert.Sender__c);
            this.orgWideAddress = alert.OrgWideAddress__c;
            this.logFailures = alert.LogFailures__c;
            this.logOperation = 'Custom Email Alert ' + alert.DeveloperName;
        }
    }
}