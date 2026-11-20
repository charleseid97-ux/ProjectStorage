/** ──────────────────────────────────────
 * @description Utility service for sending template-based email notifications as part of the custom approval process.
 *              Resolves recipient IDs from approver sets, queue memberships, submitted-by references, record owners, and additional addressee lists.
 *              Email engine (US-ImproveEmailServiceEngine): every email is an EmailRequest sent through send().
 *                  - new EmailRequest(): Apex fills the template or subject/body and the recipients itself.
 *                  - new EmailRequest(customAlertName, recordId): filled from a CustomEmailAlert__mdt record (used by the Flow action CustomEmailAlertFlowAction); the caller can still override or add anything before send().
 *              The template is always rendered (renderStoredEmailTemplate: Classic, Lightning, Visualforce), once per distinct template / recipient / record, then the replacements are applied. Each render costs 1 SOQL query.
 *              To / Cc / Bcc = addresses + queue members + users of userOrGroupIds, split into several identical messages above 100 To / 25 Cc / 25 Bcc, all sent in a single Messaging.sendEmail.
 *              Configuration errors (unknown alert, template, queue or org-wide address, invalid recipient) throw EmailServiceException before anything is sent. Send failures never throw: they are logged in
 *                  OperationLog__c (logFailures). The engine never flushes OperationLogService: the entry point flushes, and send() must come after any callout of the transaction (sendEmail is pending work).
 *              Invalid addresses (e.g. masked sandbox addresses "x@y.com.invalid") never block the others: a message Salesforce rejects for them is resent once without them (WARN log).
 *              Dry run (dryRun, DryRun__c on the alert, or forced for the org / a profile / a user by EmailServiceSettings__c.ForceDryRun__c): the email is built and checked as configured, but sent only to the dry-run addresses
 *                  (EmailServiceSettings__c.DryRunAddresses__c), its subject prefixed with "[DRY RUN] " and the real recipients listed at the top of its body (the recipient record by name and email).
 *              No To recipient (e.g. every Custom Email Recipient inactive, an empty record field, no active user): the email goes the same way to the No Recipient Addresses only (EmailServiceSettings__c.NoRecipientAddresses__c),
 *                  its subject prefixed with "[NO RECIPIENT] ", its Cc / Bcc, alert and record listed at the top of its body, with a WARN log; the caller never fails for it. No address set: configuration error.
 *              Recipients of an alert: its CustomEmailRecipient__mdt rows, one recipient per row (Address, Queue, PublicGroup, RecordField in To / Cc / Bcc), each with an optional formula Condition on the email's record (Formula.builder).
 *                  The fields the rows read (conditions, record fields) are queried once per object for all the requests of a build.
 *                  A Record Field row giving a User in To makes that user the recipient record (targetObjectId) when the request has none, exactly like the Flow's Recipient Id (rows read by DeveloperName order).
 *                  US-20337: an Apex row (Type Apex, Value__c = a class implementing RecipientResolver, e.g. PMTTeamOwnerRecipients) adds the users the class returns for the record, resolved once per class per build.
 *              US-20337: Microsoft Teams messages (TeamsMessageService) are built here too (isTeamsMessage): same rows, conditions, render, replacements, dry run and No Recipient fallback,
 *                  with Teams wording in the banner and errors and no recipient record (every recipient is an address). build(requests, requestByEmail) tells which request each message belongs to.
 * @author Charles EID
 * @testClass EmailServiceTest
 * @coverage 97%   [12-11-26]
 * @lastModifiedBy Charles EID   [12-11-26]
────────────────────────────────────── */
public without sharing class EmailService {

    private static final String DEFAULT_ORG_WIDE_ADDRESS = Label.EmailService_DefaultOrgWideAddress;
    @TestVisible
    private static final String DRY_RUN_SUBJECT_PREFIX = '[DRY RUN] ';
    @TestVisible
    private static final String NO_RECIPIENT_SUBJECT_PREFIX = '[NO RECIPIENT] ';
    // Running user's effective values (org default, overridden per profile / user)
    private static final EmailServiceSettings__c SETTINGS = EmailServiceSettings__c.getInstance();
    private static final Boolean FORCE_DRY_RUN = SETTINGS.ForceDryRun__c == true;
    private static final List<String> DRY_RUN_ADDRESSES = new List<String>(splitValues(SETTINGS.DryRunAddresses__c));
    private static final List<String> NO_RECIPIENT_ADDRESSES = new List<String>(splitValues(SETTINGS.NoRecipientAddresses__c));
    private static final String DEFAULT_LOG_OPERATION = 'Email send';
    private static final Integer MAX_TO_ADDRESSES = 100;
    private static final Integer MAX_CC_BCC_ADDRESSES = 25;
    private static final Set<String> ADDRESS_FIELDS = new Set<String>{ 'toAddresses', 'ccAddresses', 'bccAddresses' };
    private static final Set<Schema.SObjectType> RECIPIENT_TYPES = new Set<Schema.SObjectType>{ Contact.SObjectType, Lead.SObjectType, User.SObjectType };
    private static final Set<Schema.SObjectType> USER_OR_GROUP_TYPES = new Set<Schema.SObjectType>{ User.SObjectType, Group.SObjectType };
    private static final String RECORD_FIELD = 'RecordField';
    private static final String APEX_RESOLVER = 'Apex';

    // Loaded once per alert per transaction: a bulk Flow builds one request per record with the same alert
    private static Map<String, CustomEmailAlert__mdt> alertsByName = new Map<String, CustomEmailAlert__mdt>();
    private static Map<String, List<CustomEmailRecipient__mdt>> recipientRulesByAlertName = new Map<String, List<CustomEmailRecipient__mdt>>();
    // Compiled once per condition and object per transaction
    private static Map<String, FormulaEval.FormulaInstance> conditionsByKey = new Map<String, FormulaEval.FormulaInstance>();
    private static Map<String, Id> orgWideIdsByAddress = new Map<String, Id>();
    private static Map<Id, String> recipientLabelsById = new Map<Id, String>();
    // Apex rows' classes, instantiated once per transaction
    private static Map<String, RecipientResolver> resolversByName = new Map<String, RecipientResolver>();

    public enum Sender { NO_REPLY, CURRENT_USER, ORG_WIDE }

    public class EmailServiceException extends Exception {}

    // Class named by a Custom Email Recipient of Type Apex: the users who receive the email or Teams message of each record (all the build's records at once)
    public interface RecipientResolver {
        Map<Id, Set<Id>> getUserIds(Set<Id> recordIds);
    }

    // Builds then sends every active request in a single Messaging.sendEmail; send failures and emails sent to the No Recipient Addresses are logged, never thrown
    public static void send(List<EmailRequest> requests) {
        List<EmailRequest> requestByEmail = new List<EmailRequest>();
        List<EmailRequest> noRecipientRequests = new List<EmailRequest>();
        List<Messaging.SingleEmailMessage> emails = buildEmails(requests, requestByEmail, noRecipientRequests);
        if (emails.isEmpty()) return;

        for (EmailRequest request : noRecipientRequests) logFailure(OperationLogService.Level.WARN, request, null, 'No To recipient: the email was sent to the No Recipient Addresses (Custom Setting Email and Notification Service Settings).', null);
        try {
            sendEmails(emails, requestByEmail, true);
        }
        catch (EmailException e) {
            // Deliverability "No Access" / "System email only" is an org setting, not a failure
            if (e.getDmlType(0) == StatusCode.NO_SINGLE_MAIL_PERMISSION) return;
            for (EmailRequest request : requests) {
                if (request.isActive) logFailure(OperationLogService.Level.ERROR, request, null, 'The emails could not be sent.', e);
            }
        }
    }

    // The exact messages send() would send, without sending them (preview, checks, tests)
    public static List<Messaging.SingleEmailMessage> build(List<EmailRequest> requests) {
        return build(requests, new List<EmailRequest>());
    }

    // Same, requestByEmail receiving the request of each message (a request above 100 To / 25 Cc / 25 Bcc gives several messages): TeamsMessageService reads its recipients there
    public static List<Messaging.SingleEmailMessage> build(List<EmailRequest> requests, List<EmailRequest> requestByEmail) {
        return buildEmails(requests, requestByEmail, new List<EmailRequest>());
    }

    // Flow inputs Replacement Tokens and Replacement Values, matched by position (Flow has no Map type); configName names the alert or Teams message in the error
    public static Map<String, String> buildReplacements(String configName, List<String> tokens, List<String> values) {
        tokens = tokens != null ? tokens : new List<String>();
        values = values != null ? values : new List<String>();
        if (tokens.size() != values.size()) throw new EmailServiceException(configName + ': ' + tokens.size() + ' Replacement Tokens for ' + values.size() + ' Replacement Values. Both collections need the same size and order.');

        Map<String, String> replacements = new Map<String, String>();
        for (Integer i = 0; i < tokens.size(); i++) replacements.put(tokens[i], values[i]);
        return replacements;
    }

    // Splits a list of values (Flow inputs Additional To / Cc / Bcc Addresses): separated by commas, semicolons or line breaks
    public static Set<String> splitValues(String raw) {
        Set<String> values = new Set<String>();
        if (String.isBlank(raw)) return values;

        for (String value : raw.split('[\\r\\n,;]+')) {
            if (String.isNotBlank(value)) values.add(value.trim());
        }
        return values;
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

    // Applies the Custom Email Recipient rows, resolves templates, queues, users and senders in bulk, checks each request, then builds its content (buildContent) and its messages (splitMessages)
    // requestByEmail receives the request of each message, noRecipientRequests the requests sent to the No Recipient Addresses
    private static List<Messaging.SingleEmailMessage> buildEmails(List<EmailRequest> requests, List<EmailRequest> requestByEmail, List<EmailRequest> noRecipientRequests) {
        List<EmailRequest> activeRequests = new List<EmailRequest>();
        for (EmailRequest request : requests) {
            if (request.isActive) activeRequests.add(request);
        }
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        if (activeRequests.isEmpty()) return emails;

        applyRecipientRules(activeRequests);
        Set<String> templateNames = new Set<String>();
        Set<String> queueNames = new Set<String>();
        Set<Id> userOrGroupIds = new Set<Id>();
        Set<String> orgWideAddresses = new Set<String>();
        Set<Id> dryRunRecipientIds = new Set<Id>();
        for (EmailRequest request : activeRequests) {
            if (String.isNotBlank(request.templateDeveloperName)) templateNames.add(request.templateDeveloperName);
            if (request.recipientId != null && isDryRun(request)) dryRunRecipientIds.add(request.recipientId);
            for (Recipients recipients : new List<Recipients>{ request.to, request.cc, request.bcc }) {
                queueNames.addAll(recipients.queues);
                userOrGroupIds.addAll(recipients.userOrGroupIds);
            }
            String senderAddress = getSenderAddress(request);
            if (senderAddress != null) orgWideAddresses.add(senderAddress);
        }
        Map<String, Id> templateIdsByName = getTemplateIds(templateNames);
        Map<String, Set<String>> emailsByQueue = QueueMemberService.getQueueMemberEmails(queueNames);
        checkAllFound(queueNames, emailsByQueue.keySet(), 'Queue(s)');
        Map<Id, Set<String>> emailsByUserOrGroupId = getUserOrGroupEmails(userOrGroupIds);
        loadOrgWideAddresses(orgWideAddresses);
        loadRecipientLabels(dryRunRecipientIds);

        Map<String, Messaging.SingleEmailMessage> renderedByKey = new Map<String, Messaging.SingleEmailMessage>();
        for (EmailRequest request : activeRequests) {
            Schema.SObjectType recipientType = request.recipientId?.getSObjectType();
            if (recipientType != null && !RECIPIENT_TYPES.contains(recipientType)) throw new EmailServiceException(describe(request) + ': the recipient must be a Contact, Lead or User, not a ' + recipientType + '.');

            Messaging.SingleEmailMessage content = buildContent(request, templateIdsByName, renderedByKey);
            List<String> toAddresses = resolveAddresses(request.to, emailsByQueue, emailsByUserOrGroupId);
            List<String> ccAddresses = resolveAddresses(request.cc, emailsByQueue, emailsByUserOrGroupId);
            List<String> bccAddresses = resolveAddresses(request.bcc, emailsByQueue, emailsByUserOrGroupId);
            // A Teams message goes to all its recipients alike: it has none when all three lists are empty
            Boolean noRecipient = request.isTeamsMessage ? toAddresses.isEmpty() && ccAddresses.isEmpty() && bccAddresses.isEmpty() : toAddresses.isEmpty() && request.recipientId == null;
            if (noRecipient && NO_RECIPIENT_ADDRESSES.isEmpty()) throw new EmailServiceException(describe(request) + ' has no ' + (request.isTeamsMessage ? 'recipient' : 'To recipient') + ' (no address, no active user or queue member, no matching Custom Email Recipient' + (request.isTeamsMessage ? '' : ' and no recipient record') + ') and no No Recipient Address is set (Custom Setting Email and Notification Service Settings).');
            request.noRecipient = noRecipient && !isDryRun(request);
            if (request.noRecipient) noRecipientRequests.add(request);

            for (Messaging.SingleEmailMessage email : splitMessages(request, content, toAddresses, ccAddresses, bccAddresses, noRecipient)) {
                emails.add(email);
                requestByEmail.add(request);
            }
        }
        return emails;
    }

    // Adds the recipients of each request's Custom Email Recipient rows whose condition is true on its record; sets keep build() then send() on the same requests free of duplicates
    // Public groups and Apex rows are collected first (pending), then resolved once for all the requests
    private static void applyRecipientRules(List<EmailRequest> requests) {
        Map<Id, SObject> recordsById = queryRuleRecords(requests);
        PendingRecipients pending = new PendingRecipients();
        for (EmailRequest request : requests) {
            SObject record = recordsById.get(request.whatId);
            for (CustomEmailRecipient__mdt rule : request.recipientRules) {
                if (String.isNotBlank(rule.Condition__c) && getCondition(rule, record.getSObjectType()).evaluate(record) != true) continue;

                Recipients recipients = rule.SendAs__c == 'Cc' ? request.cc : rule.SendAs__c == 'Bcc' ? request.bcc : request.to;
                addRecipient(request, recipients, rule, record, pending);
            }
        }
        addPublicGroups(pending.recipientsByGroupName);
        addResolverRecipients(pending.recipientsByRecordIdByResolver);
    }

    // The records the rows read (conditions, record fields): one query per object with every field read by the rows of all the requests
    private static Map<Id, SObject> queryRuleRecords(List<EmailRequest> requests) {
        Map<Schema.SObjectType, Set<Id>> recordIdsByType = new Map<Schema.SObjectType, Set<Id>>();
        Map<Schema.SObjectType, Set<String>> fieldsByType = new Map<Schema.SObjectType, Set<String>>();
        for (EmailRequest request : requests) {
            for (CustomEmailRecipient__mdt rule : request.recipientRules) {
                Set<String> fields = getRuleFields(request, rule);
                if (fields.isEmpty()) continue;

                Schema.SObjectType recordType = request.whatId.getSObjectType();
                if (!recordIdsByType.containsKey(recordType)) {
                    recordIdsByType.put(recordType, new Set<Id>());
                    fieldsByType.put(recordType, new Set<String>{ 'id' });
                }
                recordIdsByType.get(recordType).add(request.whatId);
                fieldsByType.get(recordType).addAll(fields);
            }
        }
        Map<Id, SObject> recordsById = new Map<Id, SObject>();
        for (Schema.SObjectType recordType : recordIdsByType.keySet()) {
            Set<Id> recordIds = recordIdsByType.get(recordType);
            List<SObject> records = Database.query('SELECT ' + String.join(new List<String>(fieldsByType.get(recordType)), ', ') + ' FROM ' + recordType + ' WHERE Id IN :recordIds');
            recordsById.putAll(records);
        }
        return recordsById;
    }

    // Lower-case fields a row reads on the request's record: its condition's fields and its record field; empty when it reads nothing (an Apex row needs the Record Id, its class reads the record itself)
    private static Set<String> getRuleFields(EmailRequest request, CustomEmailRecipient__mdt rule) {
        Set<String> fields = new Set<String>();
        if (rule.Type__c != RECORD_FIELD && rule.Type__c != APEX_RESOLVER && String.isBlank(rule.Condition__c)) return fields;
        if (request.whatId == null) throw new EmailServiceException(describe(request) + ': its Custom Email Recipient "' + rule.DeveloperName + '" reads the email\'s record, but there is no Record Id.');

        if (rule.Type__c == RECORD_FIELD) fields.add(rule.Value__c.trim().toLowerCase());
        if (String.isNotBlank(rule.Condition__c)) {
            for (String field : getCondition(rule, request.whatId.getSObjectType()).getReferencedFields()) fields.add(field.toLowerCase());
        }
        return fields;
    }

    private static FormulaEval.FormulaInstance getCondition(CustomEmailRecipient__mdt rule, Schema.SObjectType recordType) {
        String key = recordType + '|' + rule.Condition__c;
        if (!conditionsByKey.containsKey(key)) {
            try {
                conditionsByKey.put(key, Formula.builder().withType(recordType).withReturnType(FormulaEval.FormulaReturnType.BOOLEAN).withFormula(rule.Condition__c).build());
            }
            catch (FormulaValidationException e) {
                throw new EmailServiceException('Custom Email Recipient "' + rule.DeveloperName + '": its condition is not a valid formula on ' + recordType + ' (' + e.getMessage() + ').');
            }
        }
        return conditionsByKey.get(key);
    }

    // Public groups are collected by name and Apex rows by class and record (pending), then resolved together by addPublicGroups and addResolverRecipients
    private static void addRecipient(EmailRequest request, Recipients recipients, CustomEmailRecipient__mdt rule, SObject record, PendingRecipients pending) {
        String value = rule.Value__c.trim();
        switch on rule.Type__c {
            when 'Address' {
                recipients.addresses.add(value);
            }
            when 'Queue' {
                recipients.queues.add(value);
            }
            when 'PublicGroup' {
                if (!pending.recipientsByGroupName.containsKey(value)) pending.recipientsByGroupName.put(value, new List<Recipients>());
                pending.recipientsByGroupName.get(value).add(recipients);
            }
            when 'Apex' {
                getResolver(rule);
                if (!pending.recipientsByRecordIdByResolver.containsKey(value)) pending.recipientsByRecordIdByResolver.put(value, new Map<Id, List<Recipients>>());
                Map<Id, List<Recipients>> recipientsByRecordId = pending.recipientsByRecordIdByResolver.get(value);
                if (!recipientsByRecordId.containsKey(request.whatId)) recipientsByRecordId.put(request.whatId, new List<Recipients>());
                recipientsByRecordId.get(request.whatId).add(recipients);
            }
            when else {
                addRecordFieldRecipient(request, recipients, rule, readFieldPath(record, value));
            }
        }
    }

    // The class of an Apex row, instantiated once per transaction; a missing class, or one not implementing RecipientResolver, is a configuration error
    private static RecipientResolver getResolver(CustomEmailRecipient__mdt rule) {
        String className = rule.Value__c.trim();
        if (!resolversByName.containsKey(className)) {
            Object resolver = Type.forName(className)?.newInstance();
            if (!(resolver instanceof RecipientResolver)) throw new EmailServiceException('Custom Email Recipient "' + rule.DeveloperName + '": ' + className + ' is not an Apex class implementing EmailService.RecipientResolver.');
            resolversByName.put(className, (RecipientResolver) resolver);
        }
        return resolversByName.get(className);
    }

    // Users of the Apex rows: each class is called once with all its records, its users added to the rows' lists (userOrGroupIds: active users only); a record it returns nothing for adds nobody
    private static void addResolverRecipients(Map<String, Map<Id, List<Recipients>>> recipientsByRecordIdByResolver) {
        for (String className : recipientsByRecordIdByResolver.keySet()) {
            Map<Id, List<Recipients>> recipientsByRecordId = recipientsByRecordIdByResolver.get(className);
            Map<Id, Set<Id>> userIdsByRecordId = resolversByName.get(className).getUserIds(recipientsByRecordId.keySet());
            for (Id recordId : recipientsByRecordId.keySet()) {
                Set<Id> userIds = userIdsByRecordId.get(recordId);
                if (userIds == null) continue;

                for (Recipients recipients : recipientsByRecordId.get(recordId)) recipients.userOrGroupIds.addAll(userIds);
            }
        }
    }

    // A User / Queue / Group lookup gives its active users (userOrGroupIds), an Email or Text field gives addresses; an empty field adds nobody
    // A User in To becomes the recipient record when the request has none, as the Flow's Recipient Id did: not counted in the daily email limit, fills the Recipient merge fields, and an inactive user is a send failure (logged), not a build error
    // A Teams message has no recipient record: its users are addresses like the others
    private static void addRecordFieldRecipient(EmailRequest request, Recipients recipients, CustomEmailRecipient__mdt rule, Object value) {
        if (value instanceof Id) {
            Id userOrGroupId = (Id) value;
            if (!USER_OR_GROUP_TYPES.contains(userOrGroupId.getSObjectType())) throw new EmailServiceException('Custom Email Recipient "' + rule.DeveloperName + '": ' + rule.Value__c + ' is a ' + userOrGroupId.getSObjectType() + ', not a User, Queue or Group. For a Contact or Lead, use its Email field (e.g. Contact__r.Email).');
            if (recipients === request.to && !request.isTeamsMessage && userOrGroupId.getSObjectType() == User.SObjectType && (request.recipientId == null || request.recipientId == userOrGroupId)) request.recipientId = userOrGroupId;
            else recipients.userOrGroupIds.add(userOrGroupId);
        }
        else if (value != null) {
            recipients.addresses.addAll(splitValues(String.valueOf(value)));
        }
    }

    // Value of a field path on a queried record (e.g. Agreement__r.Owner.Email); null when a relationship on the way is empty
    private static Object readFieldPath(SObject record, String path) {
        List<String> parts = path.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < parts.size() - 1 && current != null; i++) current = current.getSObject(parts[i]);
        return current?.get(parts[parts.size() - 1]);
    }

    // Ids of the rows' public groups (by DeveloperName) in userOrGroupIds, expanded to their active users like any group; an unknown group throws
    private static void addPublicGroups(Map<String, List<Recipients>> recipientsByGroupName) {
        if (recipientsByGroupName.isEmpty()) return;

        Set<String> groupNames = recipientsByGroupName.keySet();
        Map<String, Id> groupIdsByName = new Map<String, Id>();
        for (Group publicGroup : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Regular' AND DeveloperName IN :groupNames]) groupIdsByName.put(publicGroup.DeveloperName, publicGroup.Id);
        checkAllFound(groupNames, groupIdsByName.keySet(), 'Public group(s)');
        for (String groupName : groupNames) {
            for (Recipients recipients : recipientsByGroupName.get(groupName)) recipients.userOrGroupIds.add(groupIdsByName.get(groupName));
        }
    }

    // Subject and bodies of a request, replacements applied: rendered from its template (its subject can override the rendered one), otherwise its own subject and HTML body
    // Each render costs 1 SOQL query: identical template / recipient / record are rendered once per build (renderedByKey)
    private static Messaging.SingleEmailMessage buildContent(EmailRequest request, Map<String, Id> templateIdsByName, Map<String, Messaging.SingleEmailMessage> renderedByKey) {
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
        Messaging.SingleEmailMessage content = new Messaging.SingleEmailMessage();
        content.setSubject((isDryRun(request) ? DRY_RUN_SUBJECT_PREFIX : '') + applyReplacements(subject, request.replacements));
        content.setHtmlBody(applyReplacements(htmlBody, request.replacements));
        content.setPlainTextBody(applyReplacements(textBody, request.replacements));
        return content;
    }

    // A message takes at most 100 To / 25 Cc / 25 Bcc: above that, identical messages share the addresses out, each address in exactly one of them; the recipient record is on the first one
    // A dry run (its recipients already checked by buildEmails) goes to the dry-run addresses only: no To / Cc / Bcc, no recipient record (it still fills the Recipient merge fields), the real recipients listed at the top of the body
    // An email without To recipient goes the same way to the No Recipient Addresses only, its subject prefixed (a dry run stays a dry run)
    private static List<Messaging.SingleEmailMessage> splitMessages(EmailRequest request, Messaging.SingleEmailMessage content, List<String> toAddresses, List<String> ccAddresses, List<String> bccAddresses, Boolean noRecipient) {
        Boolean dryRun = isDryRun(request);
        if (dryRun || noRecipient) {
            if (dryRun && DRY_RUN_ADDRESSES.isEmpty()) throw new EmailServiceException(describe(request) + ' is a dry run but no dry-run address is set (Custom Setting Email and Notification Service Settings, Dry Run Addresses).');
            String kind = request.isTeamsMessage ? 'Teams message' : 'email';
            addBanner(content, dryRun ? DRY_RUN_SUBJECT_PREFIX + 'This ' + kind + ' was not sent to its real recipients:' : NO_RECIPIENT_SUBJECT_PREFIX + 'This ' + kind + ' has no ' + (request.isTeamsMessage ? 'recipient' : 'To recipient') + ', so it was sent to you instead. Its recipients:', request, toAddresses, ccAddresses, bccAddresses);
            if (!dryRun) content.setSubject(NO_RECIPIENT_SUBJECT_PREFIX + content.getSubject());
            toAddresses = dryRun ? DRY_RUN_ADDRESSES : NO_RECIPIENT_ADDRESSES;
            ccAddresses = new List<String>();
            bccAddresses = new List<String>();
        }
        Id targetObjectId = dryRun ? null : request.recipientId;
        String senderAddress = getSenderAddress(request);
        Id orgWideId = senderAddress != null ? orgWideIdsByAddress.get(senderAddress) : null;
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Integer messageCount = Math.max(1, Math.max(countChunks(toAddresses.size(), MAX_TO_ADDRESSES), Math.max(countChunks(ccAddresses.size(), MAX_CC_BCC_ADDRESSES), countChunks(bccAddresses.size(), MAX_CC_BCC_ADDRESSES))));
        for (Integer i = 0; i < messageCount; i++) {
            List<String> toChunk = slice(toAddresses, i, MAX_TO_ADDRESSES);
            List<String> ccChunk = slice(ccAddresses, i, MAX_CC_BCC_ADDRESSES);
            List<String> bccChunk = slice(bccAddresses, i, MAX_CC_BCC_ADDRESSES);

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            if (!toChunk.isEmpty()) email.setToAddresses(toChunk);
            if (!ccChunk.isEmpty()) email.setCcAddresses(ccChunk);
            if (!bccChunk.isEmpty()) email.setBccAddresses(bccChunk);
            if (i == 0 && targetObjectId != null) email.setTargetObjectId(targetObjectId);
            email.setSubject(content.getSubject());
            if (String.isNotBlank(content.getHtmlBody())) email.setHtmlBody(content.getHtmlBody());
            if (String.isNotBlank(content.getPlainTextBody())) email.setPlainTextBody(content.getPlainTextBody());
            if (orgWideId != null) email.setOrgWideEmailAddressId(orgWideId);
            email.setSaveAsActivity(false);
            emails.add(email);
        }
        return emails;
    }

    // Dry run or no To recipient: the recipients the email would have reached (the recipient record first, by name and email), its alert and its record, at the top of its HTML and text bodies
    // A Teams message lists its recipients in one line: they all receive it alike
    private static void addBanner(Messaging.SingleEmailMessage content, String title, EmailRequest request, List<String> toAddresses, List<String> ccAddresses, List<String> bccAddresses) {
        List<String> toRecipients = new List<String>();
        if (request.recipientId != null) toRecipients.add(recipientLabelsById.get(request.recipientId) + ' (recipient record)');
        toRecipients.addAll(toAddresses);
        if (request.isTeamsMessage) {
            toRecipients.addAll(ccAddresses);
            toRecipients.addAll(bccAddresses);
        }
        List<String> lines = new List<String>{ title, (request.isTeamsMessage ? 'Recipients: ' : 'To: ') + (toRecipients.isEmpty() ? '(none)' : String.join(toRecipients, ', ')) };
        if (!request.isTeamsMessage && !ccAddresses.isEmpty()) lines.add('Cc: ' + String.join(ccAddresses, ', '));
        if (!request.isTeamsMessage && !bccAddresses.isEmpty()) lines.add('Bcc: ' + String.join(bccAddresses, ', '));
        if (String.isNotBlank(request.customAlertName)) lines.add((request.isTeamsMessage ? 'Custom Teams Message: ' : 'Custom Email Alert: ') + request.customAlertName);
        if (request.whatId != null) lines.add('Record: ' + URL.getOrgDomainUrl().toExternalForm() + '/' + request.whatId);
        String banner = String.join(lines, '\n');
        if (String.isNotBlank(content.getHtmlBody())) content.setHtmlBody('<div style="border:2px solid #c23934;padding:8px;margin-bottom:16px;font-family:Arial,sans-serif;font-size:12px;">' + banner.escapeHtml4().replace('\n', '<br/>') + '</div>' + content.getHtmlBody());
        if (String.isNotBlank(content.getPlainTextBody())) content.setPlainTextBody(banner + '\n\n' + content.getPlainTextBody());
    }

    // Sends the messages and logs their failures. Salesforce rejects a whole message for one invalid address (e.g. a masked sandbox address "x@y.com.invalid"): such a message is resent once without the rejected addresses
    private static void sendEmails(List<Messaging.SingleEmailMessage> emails, List<EmailRequest> requestByEmail, Boolean retryInvalidAddresses) {
        List<Messaging.SingleEmailMessage> retryEmails = new List<Messaging.SingleEmailMessage>();
        List<EmailRequest> retryRequestByEmail = new List<EmailRequest>();
        List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) continue;

            List<Messaging.SendEmailError> errors = results[i].getErrors();
            // Deliverability "No Access" / "System email only" also comes back as a failed result: an org setting, not a failure
            if (errors[0].getStatusCode() == StatusCode.NO_SINGLE_MAIL_PERMISSION) return;

            Set<String> invalidAddresses = getInvalidAddresses(errors);
            if (!retryInvalidAddresses || invalidAddresses.isEmpty()) {
                logFailure(OperationLogService.Level.ERROR, requestByEmail[i], emails[i], joinMessages(errors), null);
                continue;
            }
            Boolean hasRecipient = removeAddresses(emails[i], invalidAddresses);
            logFailure(OperationLogService.Level.WARN, requestByEmail[i], emails[i], 'Invalid email address(es) removed: ' + String.join(new List<String>(invalidAddresses), ', ') + (hasRecipient ? '. Email resent to the other recipients.' : '. No recipient left, email not sent.'), null);
            if (hasRecipient) {
                retryEmails.add(emails[i]);
                retryRequestByEmail.add(requestByEmail[i]);
            }
        }
        if (!retryEmails.isEmpty()) sendEmails(retryEmails, retryRequestByEmail, false);
    }

    // Addresses Salesforce rejected: one INVALID_EMAIL_ADDRESS error per address, its fields = the list name + the address. Empty when another error is mixed in (a resend would fail anyway)
    private static Set<String> getInvalidAddresses(List<Messaging.SendEmailError> errors) {
        Set<String> invalidAddresses = new Set<String>();
        for (Messaging.SendEmailError error : errors) {
            if (error.getStatusCode() != StatusCode.INVALID_EMAIL_ADDRESS) return new Set<String>();
            for (String field : error.getFields()) {
                if (!ADDRESS_FIELDS.contains(field)) invalidAddresses.add(field.toLowerCase());
            }
        }
        return invalidAddresses;
    }

    // Salesforce returns one error per problem (e.g. one per invalid To, Cc and Bcc address): all of them go in the log
    private static String joinMessages(List<Messaging.SendEmailError> errors) {
        List<String> messages = new List<String>();
        for (Messaging.SendEmailError error : errors) messages.add(error.getMessage());
        return String.join(messages, ' | ');
    }

    // Removes the addresses from the message's To / Cc / Bcc; true when the message still has a recipient
    private static Boolean removeAddresses(Messaging.SingleEmailMessage email, Set<String> addresses) {
        List<String> toAddresses = keepAddresses(email.getToAddresses(), addresses);
        List<String> ccAddresses = keepAddresses(email.getCcAddresses(), addresses);
        List<String> bccAddresses = keepAddresses(email.getBccAddresses(), addresses);
        email.setToAddresses(toAddresses);
        email.setCcAddresses(ccAddresses);
        email.setBccAddresses(bccAddresses);
        return !toAddresses.isEmpty() || !ccAddresses.isEmpty() || !bccAddresses.isEmpty() || email.getTargetObjectId() != null;
    }

    private static List<String> keepAddresses(List<String> addresses, Set<String> removedAddresses) {
        List<String> kept = new List<String>();
        if (addresses == null) return kept;

        for (String address : addresses) {
            if (!removedAddresses.contains(address.toLowerCase())) kept.add(address);
        }
        return kept;
    }

    // Static cache per alert name, with its active Custom Email Recipient rows; SOQL rather than getInstance(), which cuts long text areas to 255 characters
    private static CustomEmailAlert__mdt getAlert(String customAlertName) {
        if (!alertsByName.containsKey(customAlertName)) {
            List<CustomEmailAlert__mdt> alerts = [SELECT DeveloperName, IsActive__c, DryRun__c, EmailTemplate__c, Sender__c, OrgWideAddress__c, LogFailures__c
                                                  FROM CustomEmailAlert__mdt
                                                  WHERE DeveloperName = :customAlertName];
            if (alerts.isEmpty()) throw new EmailServiceException('Custom Email Alert "' + customAlertName + '" not found.');
            List<CustomEmailRecipient__mdt> rules = [SELECT DeveloperName, SendAs__c, Type__c, Value__c, Condition__c
                                                     FROM CustomEmailRecipient__mdt
                                                     WHERE CustomEmailAlert__r.DeveloperName = :customAlertName AND IsActive__c = true
                                                     ORDER BY DeveloperName];
            alertsByName.put(customAlertName, alerts[0]);
            recipientRulesByAlertName.put(customAlertName, rules);
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

    // "Name <email>" of the dry runs' recipient records (User, Contact or Lead), shown in their banner: one query per object, cached per transaction
    private static void loadRecipientLabels(Set<Id> recipientIds) {
        Map<Schema.SObjectType, Set<Id>> idsByType = new Map<Schema.SObjectType, Set<Id>>();
        for (Id recipientId : recipientIds) {
            if (recipientLabelsById.containsKey(recipientId)) continue;

            if (!idsByType.containsKey(recipientId.getSObjectType())) idsByType.put(recipientId.getSObjectType(), new Set<Id>());
            idsByType.get(recipientId.getSObjectType()).add(recipientId);
        }
        for (Schema.SObjectType recipientType : idsByType.keySet()) {
            Set<Id> ids = idsByType.get(recipientType);
            List<SObject> recipients = Database.query('SELECT Id, Name, Email FROM ' + recipientType + ' WHERE Id IN :ids');
            for (SObject recipient : recipients) recipientLabelsById.put(recipient.Id, recipient.get('Name') + ' <' + recipient.get('Email') + '>');
        }
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

    // Logs a send failure (ERROR) or a removed invalid address (WARN) on the request's record, when the request asks for it (logFailures); never flushes
    private static void logFailure(OperationLogService.Level level, EmailRequest request, Messaging.SingleEmailMessage email, String errorMessage, Exception e) {
        if (request.logFailures != true) return;

        Map<String, Object> context = new Map<String, Object>{ 'customAlertName' => request.customAlertName, 'template' => request.templateDeveloperName, 'subject' => email?.getSubject(), 'toAddresses' => email?.getToAddresses(), 'targetObjectId' => email?.getTargetObjectId(), 'dryRun' => isDryRun(request) };
        OperationLogService.logWithContext(level, request.whatId, String.isNotBlank(request.logOperation) ? request.logOperation : DEFAULT_LOG_OPERATION, errorMessage, context, e, 'EmailService', 'send');
    }

    // A dry run when the request asks for it (DryRun__c, dryRun) or when the org forces it for the running user (EmailServiceSettings__c.ForceDryRun__c, e.g. in a sandbox)
    private static Boolean isDryRun(EmailRequest request) {
        return request.dryRun == true || FORCE_DRY_RUN;
    }

    private static String describe(EmailRequest request) {
        String name = String.isNotBlank(request.customAlertName) ? request.customAlertName : String.isNotBlank(request.templateDeveloperName) ? request.templateDeveloperName : request.subject;
        String kind = request.isTeamsMessage ? 'Teams message' : 'Email';
        return String.isBlank(name) ? kind + ' request' : kind + ' "' + name + '"';
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
        public Boolean dryRun = false;
        public List<CustomEmailRecipient__mdt> recipientRules = new List<CustomEmailRecipient__mdt>();
        // US-20337: built by TeamsMessageService (customAlertName = its Custom Teams Message): Teams wording, no recipient record
        public Boolean isTeamsMessage = false;
        // Set by the build: the message goes to the No Recipient Addresses
        public Boolean noRecipient = false;

        public EmailRequest() {}

        public EmailRequest(String customAlertName, Id recordId) {
            CustomEmailAlert__mdt alert = getAlert(customAlertName);
            this.customAlertName = alert.DeveloperName;
            this.isActive = alert.IsActive__c;
            this.dryRun = alert.DryRun__c;
            this.templateDeveloperName = alert.EmailTemplate__c;
            this.whatId = recordId;
            // Resolved by build(), with the record's fields queried once for all the requests
            this.recipientRules.addAll(recipientRulesByAlertName.get(customAlertName));
            this.sender = EmailService.Sender.valueOf(alert.Sender__c);
            this.orgWideAddress = alert.OrgWideAddress__c;
            this.logFailures = alert.LogFailures__c;
            this.logOperation = 'Custom Email Alert ' + alert.DeveloperName;
        }
    }

    // Rows resolved for all the requests at once, after the loop on the rows: public groups by name, Apex rows by class then record
    private class PendingRecipients {
        public Map<String, List<Recipients>> recipientsByGroupName = new Map<String, List<Recipients>>();
        public Map<String, Map<Id, List<Recipients>>> recipientsByRecordIdByResolver = new Map<String, Map<Id, List<Recipients>>>();
    }
}