/** ──────────────────────────────────────
 * @description Test class for EmailService.
 *              Covers recipient type resolution (submitter, current/next approvers,
 *              record owner, queue expansion), additional recipient resolution,
 *              and sendTemplateEmail early-return guards.
 *              Email engine (US-ImproveEmailServiceEngine): build() on the real Custom Email Alerts (AIAgent*), Apex-built requests (no template, queues, users, chunking, template subject override),
 *                  configuration errors, send() removing the invalid addresses Salesforce rejects (WARN logs), the dry run (dry-run addresses, subject prefix, real recipients banner), an email without To recipient
 *                  (sent to the No Recipient Addresses, subject prefix, banner, WARN log), and the Flow action CustomEmailAlertFlowAction.
 *              Custom Email Recipients: every active row of the org is validated (condition, record field, queue, group), the real alerts' rows are checked in their messages, and in-memory rows cover
 *                  conditions, record fields (a user in To being the recipient record), queues, public groups and their configuration errors.
 *              US-20337: the org-wide row check also covers the Teams messages' rows and the Apex rows (class implementing EmailService.RecipientResolver); an in-memory Apex row and an unknown class.
 *              Assertions pass in any org: real alerts, templates and rows are read at runtime, never hard-coded; the only requirement is one active alert whose template object has a test record.
 * @author Charles EID
 * @covers EmailService   97%   [12-11-26]
 * @covers CustomEmailAlertFlowAction   100%   [12-11-26]
 * @lastModifiedBy Charles EID   [12-11-26]
 ────────────────────────────────────── */
@IsTest
public class EmailServiceTest {

    private static final String QUEUE_NAME = 'EST_Queue';
    private static final String GROUP_NAME = 'EST_Regular_Group';
    private static final String DRY_RUN_ADDRESS = 'est.dryrun@example.com';
    private static final String NO_RECIPIENT_ADDRESS = 'est.norecipient@example.com';

    // A queue and a public group whose only member is the running user, the dry-run address (tests don't see the org's custom setting data), and the records the alert templates are rendered with:
    // AI_Agent__c and Case, plus a blank record of any other template object when the org lets one be created (otherwise its alerts aren't sampled)
    @TestSetup
    static void setupTestData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group queue = new Group(Name = QUEUE_NAME, DeveloperName = QUEUE_NAME, Type = 'Queue');
            Group publicGroup = new Group(Name = GROUP_NAME, DeveloperName = GROUP_NAME, Type = 'Regular');
            insert new List<Group>{ queue, publicGroup };
            insert new List<GroupMember>{ new GroupMember(GroupId = queue.Id, UserOrGroupId = UserInfo.getUserId()), new GroupMember(GroupId = publicGroup.Id, UserOrGroupId = UserInfo.getUserId()) };
        }
        insert new EmailServiceSettings__c(SetupOwnerId = UserInfo.getOrganizationId(), DryRunAddresses__c = DRY_RUN_ADDRESS, NoRecipientAddresses__c = NO_RECIPIENT_ADDRESS);
        insert new AI_Agent__c(Name = 'EST Agent', Connectors__c = 'Outlook', Status__c = 'Active');
        insert new Case(Subject = 'EST AI Agent request', AgentName__c = 'EST Requested Agent');

        Set<String> templateNames = new Set<String>();
        for (CustomEmailAlert__mdt alert : [SELECT EmailTemplate__c FROM CustomEmailAlert__mdt WHERE IsActive__c = true]) templateNames.add(alert.EmailTemplate__c);
        Set<String> otherObjects = new Set<String>(getObjectsByTemplate(templateNames).values());
        otherObjects.removeAll(new Set<String>{ 'AI_Agent__c', 'Case', null });
        List<SObject> blankRecords = new List<SObject>();
        for (String objectName : otherObjects) {
            Type objectType = Type.forName(objectName);
            if (objectType != null) blankRecords.add((SObject) objectType.newInstance());
        }
        Database.insert(blankRecords, false);
    }

    @IsTest
    static void testSendTemplateEmail() {
        Id currentUserId = UserInfo.getUserId();
        AlertSample sample = getAlertSamples()[0];

        Test.startTest();

        // Early returns: no recipient, or a template that doesn't exist
        EmailService.sendTemplateEmail('SomeTemplate', null, null);
        EmailService.sendTemplateEmail('SomeTemplate', null, new Set<Id>());
        EmailService.sendTemplateEmail('NonExistent_Template_XYZ', currentUserId, new Set<Id>{ currentUserId });
        EmailService.sendTemplateEmail('SomeTemplate', null, null, null);
        EmailService.sendTemplateEmail('NonExistent_Template_XYZ', null, new Set<Id>(), new List<String>{ 'someone@example.com' });
        Integer invocationsAfterGuards = Limits.getEmailInvocations();
        // A real alert template: raw addresses only (a blank line is skipped, not sent as an empty "to" address), then a user and a raw address
        EmailService.sendTemplateEmail(sample.templateName, sample.recordId, new Set<Id>(), new List<String>{ 'ops-alert@example.com', ' ', 'second-alert@example.com' });
        EmailService.sendTemplateEmail(sample.templateName, sample.recordId, new Set<Id>{ currentUserId }, new List<String>{ 'ops-alert@example.com' });
        Integer invocationsAfterSends = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals(0, invocationsAfterGuards, 'No recipient or a missing template: nothing is sent');
        System.assertEquals(2, invocationsAfterSends, 'One sendEmail per call with recipients and an existing template');
    }

    // resolveRecipientIds and resolveAdditionalRecipientIds
    @IsTest
    static void testResolveRecipientIds() {
        User runningUser = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId()];
        Id queueId = [SELECT Id FROM Group WHERE DeveloperName = :QUEUE_NAME].Id;
        Case agentRequest = [SELECT Id, OwnerId FROM Case LIMIT 1];

        Test.startTest();

        Set<Id> emptyTypes = EmailService.resolveRecipientIds(new Set<String>(), null, null, null, null, null);
        Set<Id> nullTypes = EmailService.resolveRecipientIds(null, null, null, null, null, null);
        Set<Id> submitter = EmailService.resolveRecipientIds(new Set<String>{ 'Submitter' }, null, null, runningUser.Id, null, null);
        Set<Id> currentApprovers = EmailService.resolveRecipientIds(new Set<String>{ 'CurrentStepApprovers' }, new Set<Id>{ queueId }, null, null, null, null);
        Set<Id> nextApprovers = EmailService.resolveRecipientIds(new Set<String>{ 'NextStepApprovers' }, null, new Set<Id>{ runningUser.Id }, null, null, null);
        Set<Id> recordOwner = EmailService.resolveRecipientIds(new Set<String>{ 'RecordOwner' }, null, null, null, agentRequest.Id, 'Case');
        Set<Id> blankAdditional = EmailService.resolveAdditionalRecipientIds(null, null);
        Set<Id> additionalUser = EmailService.resolveAdditionalRecipientIds(null, runningUser.Username);
        Set<Id> additionalQueue = EmailService.resolveAdditionalRecipientIds(QUEUE_NAME, null);

        Test.stopTest();

        System.assertEquals(0, emptyTypes.size(), 'Should return empty set for empty types');
        System.assertEquals(0, nullTypes.size(), 'Should return empty set for null types');
        System.assert(submitter.contains(runningUser.Id), 'Should include the submitter');
        System.assert(currentApprovers.contains(runningUser.Id), 'Should expand queue approver to its user member');
        System.assert(nextApprovers.contains(runningUser.Id), 'Should include the next step approver');
        System.assert(recordOwner.contains(agentRequest.OwnerId), 'Should resolve the record owner');
        System.assertEquals(0, blankAdditional.size(), 'Should return empty set for blank inputs');
        System.assert(additionalUser.contains(runningUser.Id), 'Should resolve user by username');
        System.assert(additionalQueue.contains(runningUser.Id), 'Should resolve queue members as recipients');
    }

    // Engine: the org's Custom Email Recipients and real alerts, Apex-built requests, in-memory recipient rows and the configuration errors
    @IsTest
    static void testBuild() {
        String userEmail = UserInfo.getUserEmail().toLowerCase();
        Id queueId = [SELECT Id FROM Group WHERE DeveloperName = :QUEUE_NAME].Id;
        Case agentRequest = [SELECT Id FROM Case LIMIT 1];
        List<AlertSample> samples = getAlertSamples();
        // Each real alert with the running user as recipient (some alerts only have record-field recipients, empty on the test records); its own subject tells its messages apart
        List<EmailService.EmailRequest> alertRequests = new List<EmailService.EmailRequest>();
        for (AlertSample sample : samples) {
            EmailService.EmailRequest request = new EmailService.EmailRequest(sample.alertName, sample.recordId);
            request.dryRun = false;
            request.recipientId = UserInfo.getUserId();
            request.subject = sample.alertName;
            alertRequests.add(request);
        }

        EmailService.EmailRequest bulkRequest = newApexRequest();
        bulkRequest.subject = 'EST subject {X}';
        bulkRequest.htmlBody = '<p>EST body {X}</p>';
        bulkRequest.replacements.put('{X}', 'Replaced');
        for (Integer i = 0; i < 130; i++) bulkRequest.to.addresses.add('est.to' + i + '@example.com');
        for (Integer i = 0; i < 40; i++) bulkRequest.cc.addresses.add('est.cc' + i + '@example.com');
        bulkRequest.to.queues.add(QUEUE_NAME);
        bulkRequest.bcc.userOrGroupIds.add(queueId);
        EmailService.EmailRequest templateRequest = new EmailService.EmailRequest();
        templateRequest.templateDeveloperName = samples[0].templateName;
        templateRequest.whatId = samples[0].recordId;
        templateRequest.recipientId = UserInfo.getUserId();
        templateRequest.subject = 'EST override {X}';
        templateRequest.replacements.put('{X}', 'Replaced');
        templateRequest.sender = EmailService.Sender.ORG_WIDE;
        templateRequest.orgWideAddress = Label.EmailService_DefaultOrgWideAddress;
        EmailService.EmailRequest inactiveRequest = new EmailService.EmailRequest();
        inactiveRequest.isActive = false;
        EmailService.EmailRequest dryRunRequest = newApexRequest();
        dryRunRequest.dryRun = true;
        dryRunRequest.recipientId = UserInfo.getUserId();
        dryRunRequest.cc.addresses.add('est.dryrun.cc@example.com');
        EmailService.EmailRequest noToRecipient = newApexRequest();
        noToRecipient.to.addresses.clear();
        noToRecipient.cc.addresses.add('est.norecipient.cc@example.com');
        noToRecipient.whatId = agentRequest.Id;
        // In-memory Custom Email Recipients on the test Case (created by the running user, its subject filled)
        EmailService.EmailRequest ruleRequest = newApexRequest();
        ruleRequest.to.addresses.clear();
        ruleRequest.whatId = agentRequest.Id;
        ruleRequest.recipientRules.addAll(new List<CustomEmailRecipient__mdt>{ newRule('To', 'Address', 'est.rule.a@example.com', null), newRule('To', 'Address', 'est.rule.b@example.com', null), newRule('To', 'RecordField', 'CreatedById', null), newRule('Cc', 'RecordField', 'CreatedBy.Email', null), newRule('Cc', 'Address', 'est.rule.true@example.com', 'NOT(ISBLANK(Subject))'), newRule('Cc', 'Address', 'est.rule.false@example.com', 'ISBLANK(Subject)'), newRule('Cc', 'PublicGroup', GROUP_NAME, null), newRule('Bcc', 'RecordField', 'CreatedById', null), newRule('Bcc', 'Queue', QUEUE_NAME, null) });
        // US-20337: an Apex row, its users added as addresses (never as the recipient record)
        EmailService.EmailRequest resolverRequest = newRuleRequest(agentRequest.Id, newRule('Cc', 'Apex', 'EmailServiceTest.RunningUserResolver', null));

        EmailService.EmailRequest unknownTemplate = newApexRequest();
        unknownTemplate.templateDeveloperName = 'EST_Unknown_Template';
        EmailService.EmailRequest unknownQueue = newApexRequest();
        unknownQueue.to.queues.add('EST_Unknown_Queue');
        EmailService.EmailRequest noBody = newApexRequest();
        noBody.htmlBody = null;
        EmailService.EmailRequest groupRecipient = newApexRequest();
        groupRecipient.recipientId = queueId;
        EmailService.EmailRequest orgWideWithoutAddress = newApexRequest();
        orgWideWithoutAddress.sender = EmailService.Sender.ORG_WIDE;
        EmailService.EmailRequest unknownOrgWide = newApexRequest();
        unknownOrgWide.sender = EmailService.Sender.ORG_WIDE;
        unknownOrgWide.orgWideAddress = 'est.unknown.sender@example.com';
        Map<String, EmailService.EmailRequest> requestsByExpectedError = new Map<String, EmailService.EmailRequest>{ 'Email template(s) not found' => unknownTemplate, 'Queue(s) not found' => unknownQueue, 'needs a subject and an HTML body' => noBody, 'must be a Contact, Lead or User' => groupRecipient, 'has no orgWideAddress' => orgWideWithoutAddress, 'Org-wide email address(es) not found' => unknownOrgWide, 'is not a valid formula' => newRuleRequest(agentRequest.Id, newRule('Cc', 'Address', 'est.rule@example.com', 'NoSuchField__c = 1')), 'there is no Record Id' => newRuleRequest(null, newRule('Cc', 'RecordField', 'OwnerId', null)), 'not a User, Queue or Group' => newRuleRequest(agentRequest.Id, newRule('Cc', 'RecordField', 'Id', null)), 'Public group(s) not found' => newRuleRequest(null, newRule('Cc', 'PublicGroup', 'EST_Unknown_Group', null)), 'is not an Apex class implementing' => newRuleRequest(agentRequest.Id, newRule('Cc', 'Apex', 'EST_No_Such_Class', null)) };

        Test.startTest();

        List<String> invalidRules = getInvalidRules();
        Map<String, Map<String, Set<String>>> addressesByAlert = getAddressesBySubject(EmailService.build(alertRequests));
        List<Messaging.SingleEmailMessage> apexEmails = EmailService.build(new List<EmailService.EmailRequest>{ bulkRequest, templateRequest, inactiveRequest });
        List<Messaging.SingleEmailMessage> dryRunEmails = EmailService.build(new List<EmailService.EmailRequest>{ dryRunRequest });
        List<Messaging.SingleEmailMessage> noRecipientEmails = EmailService.build(new List<EmailService.EmailRequest>{ noToRecipient });
        List<Messaging.SingleEmailMessage> ruleEmails = EmailService.build(new List<EmailService.EmailRequest>{ ruleRequest });
        List<Messaging.SingleEmailMessage> ruleEmailsRebuilt = EmailService.build(new List<EmailService.EmailRequest>{ ruleRequest });
        List<Messaging.SingleEmailMessage> resolverEmails = EmailService.build(new List<EmailService.EmailRequest>{ resolverRequest });
        Map<String, String> errorsByExpectedError = new Map<String, String>();
        for (String expectedError : requestsByExpectedError.keySet()) errorsByExpectedError.put(expectedError, getBuildError(requestsByExpectedError.get(expectedError)));
        String unknownAlertError;
        try {
            EmailService.EmailRequest unknownAlert = new EmailService.EmailRequest('EST_Unknown_Alert', null);
        }
        catch (EmailService.EmailServiceException e) {
            unknownAlertError = e.getMessage();
        }

        Test.stopTest();

        System.assert(invalidRules.isEmpty(), 'Every active Custom Email Recipient must be valid: ' + invalidRules);
        // The address of each real alert's unconditional Address rows is in the list (To / Cc / Bcc) of its row
        for (EmailService.EmailRequest request : alertRequests) {
            System.assert(addressesByAlert.containsKey(request.subject), 'An active alert is built: ' + request.subject);
            for (CustomEmailRecipient__mdt rule : request.recipientRules) {
                if (rule.Type__c != 'Address' || String.isNotBlank(rule.Condition__c)) continue;

                System.assert(addressesByAlert.get(request.subject).get(rule.SendAs__c).contains(rule.Value__c.trim().toLowerCase()), request.subject + ': the address of ' + rule.DeveloperName + ' is in ' + rule.SendAs__c);
            }
        }
        System.assertEquals(3, apexEmails.size(), '132 To / 40 Cc split into 2 messages, 1 message for the template request, none for the inactive one');
        System.assertEquals(100, apexEmails[0].getToAddresses().size(), 'At most 100 To per message');
        System.assertEquals(25, apexEmails[0].getCcAddresses().size(), 'At most 25 Cc per message');
        System.assertEquals(new List<String>{ userEmail }, apexEmails[0].getBccAddresses(), 'The queue member in Bcc');
        System.assertEquals(32, apexEmails[1].getToAddresses().size(), '131 addresses + the To queue member: the rest in the second message');
        System.assertEquals(15, apexEmails[1].getCcAddresses().size(), 'The remaining Cc in the second message');
        System.assertEquals('EST subject Replaced', apexEmails[0].getSubject(), 'Replacements are applied to the subject');
        System.assertEquals('<p>EST body Replaced</p>', apexEmails[1].getHtmlBody(), 'Every message carries the same body');
        System.assertEquals(null, apexEmails[0].getOrgWideEmailAddressId(), 'Current user sender: no org-wide address');
        System.assertEquals(UserInfo.getUserId(), apexEmails[2].getTargetObjectId(), 'The recipient record receives the email');
        System.assertEquals('EST override Replaced', apexEmails[2].getSubject(), 'The request subject overrides the template subject');
        System.assertNotEquals(null, apexEmails[2].getOrgWideEmailAddressId(), 'Org-wide sender resolved');

        System.assertEquals(1, dryRunEmails.size(), 'A dry run is a single message');
        System.assertEquals(new List<String>{ DRY_RUN_ADDRESS }, dryRunEmails[0].getToAddresses(), 'A dry run goes to the dry-run addresses only');
        System.assert(dryRunEmails[0].getCcAddresses() == null || dryRunEmails[0].getCcAddresses().isEmpty(), 'A dry run has no Cc');
        System.assertEquals(null, dryRunEmails[0].getTargetObjectId(), 'The recipient record doesn\'t receive a dry run');
        System.assert(dryRunEmails[0].getSubject().startsWith(EmailService.DRY_RUN_SUBJECT_PREFIX), 'The subject is prefixed: ' + dryRunEmails[0].getSubject());
        System.assert(dryRunEmails[0].getHtmlBody().contains('est.dryrun.cc@example.com') && dryRunEmails[0].getHtmlBody().contains(UserInfo.getUserEmail() + '&gt; (recipient record)'), 'The real recipients are listed in the body, the recipient record by its email');

        System.assertEquals(1, noRecipientEmails.size(), 'An email without To recipient is still sent, as a single message');
        System.assertEquals(new List<String>{ NO_RECIPIENT_ADDRESS }, noRecipientEmails[0].getToAddresses(), 'An email without To recipient goes to the No Recipient Addresses only');
        System.assert(noRecipientEmails[0].getCcAddresses() == null || noRecipientEmails[0].getCcAddresses().isEmpty(), 'Its Cc doesn\'t receive it');
        System.assert(noRecipientEmails[0].getSubject().startsWith(EmailService.NO_RECIPIENT_SUBJECT_PREFIX), 'The subject is prefixed: ' + noRecipientEmails[0].getSubject());
        System.assert(noRecipientEmails[0].getHtmlBody().contains('est.norecipient.cc@example.com') && noRecipientEmails[0].getHtmlBody().contains(agentRequest.Id), 'Its Cc and its record are listed in the body');

        System.assertEquals(1, ruleEmails.size(), 'One message for the in-memory rows');
        System.assertEquals(new Set<String>{ 'est.rule.a@example.com', 'est.rule.b@example.com' }, new Set<String>(ruleEmails[0].getToAddresses()), 'To: the address of each Address row, the user of the record field CreatedById being the recipient record');
        System.assertEquals(UserInfo.getUserId(), ruleEmails[0].getTargetObjectId(), 'A record field user in To is the recipient record, like the Flow\'s Recipient Id');
        System.assertEquals(new Set<String>{ 'est.rule.true@example.com', userEmail }, new Set<String>(ruleEmails[0].getCcAddresses()), 'Cc: the record field path CreatedBy.Email, the row whose condition is true and the public group member, not the row whose condition is false');
        System.assertEquals(new List<String>{ userEmail }, ruleEmails[0].getBccAddresses(), 'Bcc: the user of the record field CreatedById (outside To: an address) and the queue member, once');
        System.assertEquals(new Set<String>(ruleEmails[0].getToAddresses()), new Set<String>(ruleEmailsRebuilt[0].getToAddresses()), 'A second build of the same request adds nobody');
        System.assertEquals(UserInfo.getUserId(), ruleEmailsRebuilt[0].getTargetObjectId(), 'A second build keeps the same recipient record');
        System.assertEquals(new List<String>{ userEmail }, resolverEmails[0].getCcAddresses(), 'An Apex row adds the users its class returns for the record');

        for (String expectedError : errorsByExpectedError.keySet()) System.assert(String.valueOf(errorsByExpectedError.get(expectedError)).contains(expectedError), 'Expected "' + expectedError + '", got: ' + errorsByExpectedError.get(expectedError));
        System.assertEquals('Custom Email Alert "EST_Unknown_Alert" not found.', unknownAlertError, 'An unknown alert name throws');
    }

    // Engine: send() removing the invalid addresses (the result depends on the org's deliverability, so it isn't asserted), then the Flow action built on it
    @IsTest
    static void testSend() {
        AlertSample sample = getAlertSamples()[0];
        EmailService.EmailRequest partlyInvalid = newApexRequest();
        partlyInvalid.to.addresses.add('est invalid to');
        partlyInvalid.cc.addresses.add('est invalid cc');
        EmailService.EmailRequest onlyInvalid = newApexRequest();
        onlyInvalid.to.addresses.clear();
        onlyInvalid.to.addresses.add('est invalid only');
        EmailService.EmailRequest noToRecipient = newApexRequest();
        noToRecipient.to.addresses.clear();
        List<CustomEmailAlertFlowAction.Request> flowRequests = new List<CustomEmailAlertFlowAction.Request>{ newFlowRequest(sample, new List<String>{ '{_Token_}' }, new List<String>{ 'Value' }), newFlowRequest(sample, null, null) };
        flowRequests[0].additionalToAddresses = 'est.flow.to1@example.com, est.flow.to2@example.com';
        flowRequests[0].additionalCcAddresses = 'est.flow.cc@example.com';
        flowRequests[1].dryRun = true;
        CustomEmailAlertFlowAction.Request mismatchRequest = newFlowRequest(sample, new List<String>{ '{_A_}', '{_B_}' }, new List<String>{ 'Value' });

        Test.startTest();

        Set<String> splitAddresses = EmailService.splitValues(' a@example.com, b@example.com;c@example.com\n,a@example.com ');
        // The request the Flow action builds, outside dry run (the alert's own Dry Run would send it to the dry-run addresses only)
        List<EmailService.EmailRequest> additionalRequests = CustomEmailAlertFlowAction.buildRequests(new List<CustomEmailAlertFlowAction.Request>{ flowRequests[0] });
        additionalRequests[0].dryRun = false;
        Map<String, Set<String>> additionalAddresses = getAddressesBySubject(EmailService.build(additionalRequests)).values()[0];
        EmailService.send(new List<EmailService.EmailRequest>{ partlyInvalid, onlyInvalid, noToRecipient });
        Integer invocationsBeforeFlow = Limits.getEmailInvocations();
        CustomEmailAlertFlowAction.sendCustomEmailAlerts(flowRequests);
        Integer flowInvocations = Limits.getEmailInvocations() - invocationsBeforeFlow;
        String mismatchError;
        try {
            CustomEmailAlertFlowAction.sendCustomEmailAlerts(new List<CustomEmailAlertFlowAction.Request>{ mismatchRequest });
        }
        catch (EmailService.EmailServiceException e) {
            mismatchError = e.getMessage();
        }

        Test.stopTest();

        System.assertEquals(new Set<String>{ 'a@example.com', 'b@example.com', 'c@example.com' }, splitAddresses, 'Commas, semicolons and line breaks all separate addresses, trimmed and without duplicates');
        System.assert(additionalAddresses.get('To').containsAll(new Set<String>{ 'est.flow.to1@example.com', 'est.flow.to2@example.com' }), 'The Flow\'s Additional To Addresses are in To: ' + additionalAddresses.get('To'));
        System.assert(additionalAddresses.get('Cc').contains('est.flow.cc@example.com'), 'The Flow\'s Additional Cc Addresses are in Cc: ' + additionalAddresses.get('Cc'));
        System.assertEquals(1, flowInvocations, 'Every Flow interview is sent in a single sendEmail');
        System.assert(mismatchError != null && mismatchError.contains('2 Replacement Tokens for 1 Replacement Values'), 'Tokens and values of different sizes make the Flow fail: ' + mismatchError);
    }

    // Apex-built request without template: subject, body, one To address, sent as the running user
    private static EmailService.EmailRequest newApexRequest() {
        EmailService.EmailRequest request = new EmailService.EmailRequest();
        request.subject = 'EST subject';
        request.htmlBody = '<p>EST body</p>';
        request.to.addresses.add('est.to@example.com');
        request.sender = EmailService.Sender.CURRENT_USER;
        return request;
    }

    // In-memory Custom Email Recipient row
    private static CustomEmailRecipient__mdt newRule(String sendAs, String type, String value, String condition) {
        return new CustomEmailRecipient__mdt(DeveloperName = 'EST' + sendAs + type, SendAs__c = sendAs, Type__c = type, Value__c = value, Condition__c = condition);
    }

    // Apex-built request (one To address) with one in-memory row, for the row configuration errors
    private static EmailService.EmailRequest newRuleRequest(Id recordId, CustomEmailRecipient__mdt rule) {
        EmailService.EmailRequest request = newApexRequest();
        request.whatId = recordId;
        request.recipientRules.add(rule);
        return request;
    }

    // Flow action input on a real alert, the running user as recipient (some alerts only have record-field recipients, empty on the test records)
    private static CustomEmailAlertFlowAction.Request newFlowRequest(AlertSample sample, List<String> replacementTokens, List<String> replacementValues) {
        CustomEmailAlertFlowAction.Request request = new CustomEmailAlertFlowAction.Request();
        request.alertName = sample.alertName;
        request.recordId = sample.recordId;
        request.recipientId = UserInfo.getUserId();
        request.replacementTokens = replacementTokens;
        request.replacementValues = replacementValues;
        return request;
    }

    private static String getBuildError(EmailService.EmailRequest request) {
        try {
            EmailService.build(new List<EmailService.EmailRequest>{ request });
        }
        catch (EmailService.EmailServiceException e) {
            return e.getMessage();
        }
        return null;
    }

    // The org's active alerts whose template object has a test record: the tests use whatever alerts the org has, never a given one or a given number
    private static List<AlertSample> getAlertSamples() {
        List<CustomEmailAlert__mdt> alerts = [SELECT DeveloperName, EmailTemplate__c FROM CustomEmailAlert__mdt WHERE IsActive__c = true ORDER BY DeveloperName];
        Set<String> templateNames = new Set<String>();
        for (CustomEmailAlert__mdt alert : alerts) templateNames.add(alert.EmailTemplate__c);
        Map<String, String> objectsByTemplate = getObjectsByTemplate(templateNames);
        Map<String, Id> recordIdsByObject = new Map<String, Id>();
        for (String objectName : new Set<String>(objectsByTemplate.values())) {
            List<SObject> records = objectName == null ? new List<SObject>() : Database.query('SELECT Id FROM ' + objectName + ' LIMIT 1');
            if (!records.isEmpty()) recordIdsByObject.put(objectName, records[0].Id);
        }

        List<AlertSample> samples = new List<AlertSample>();
        for (CustomEmailAlert__mdt alert : alerts) {
            Id recordId = recordIdsByObject.get(objectsByTemplate.get(alert.EmailTemplate__c));
            if (recordId != null) samples.add(new AlertSample(alert.DeveloperName, alert.EmailTemplate__c, recordId));
        }
        System.assert(!samples.isEmpty(), 'The tests need at least one active Custom Email Alert with a Lightning template whose object has a test record');
        return samples;
    }

    // Object of each Lightning template (RelatedEntityType); Classic templates have none
    private static Map<String, String> getObjectsByTemplate(Set<String> templateNames) {
        Map<String, String> objectsByTemplate = new Map<String, String>();
        for (EmailTemplate template : [SELECT DeveloperName, RelatedEntityType FROM EmailTemplate WHERE DeveloperName IN :templateNames]) objectsByTemplate.put(template.DeveloperName, template.RelatedEntityType);
        return objectsByTemplate;
    }

    // To / Cc / Bcc addresses (lower-case) of the messages of each request, the request being known by its subject
    private static Map<String, Map<String, Set<String>>> getAddressesBySubject(List<Messaging.SingleEmailMessage> emails) {
        Map<String, Map<String, Set<String>>> addressesBySubject = new Map<String, Map<String, Set<String>>>();
        for (Messaging.SingleEmailMessage email : emails) {
            if (!addressesBySubject.containsKey(email.getSubject())) addressesBySubject.put(email.getSubject(), new Map<String, Set<String>>{ 'To' => new Set<String>(), 'Cc' => new Set<String>(), 'Bcc' => new Set<String>() });
            Map<String, Set<String>> addressesBySendAs = addressesBySubject.get(email.getSubject());
            if (email.getToAddresses() != null) addressesBySendAs.get('To').addAll(email.getToAddresses());
            if (email.getCcAddresses() != null) addressesBySendAs.get('Cc').addAll(email.getCcAddresses());
            if (email.getBccAddresses() != null) addressesBySendAs.get('Bcc').addAll(email.getBccAddresses());
        }
        return addressesBySubject;
    }

    // Active Custom Email Recipients of the org that would fail when sent: unknown queue, group or Apex class, record field or condition invalid on the object of their alert's or Teams message's template
    private static List<String> getInvalidRules() {
        List<CustomEmailRecipient__mdt> rules = [SELECT DeveloperName, Type__c, Value__c, Condition__c, CustomEmailAlert__r.EmailTemplate__c, CustomTeamsMessage__r.MessageTemplate__c FROM CustomEmailRecipient__mdt WHERE IsActive__c = true];
        Set<String> templateNames = new Set<String>();
        Set<String> groupNames = new Set<String>();
        for (CustomEmailRecipient__mdt rule : rules) {
            templateNames.add(rule.CustomEmailAlert__r.EmailTemplate__c);
            templateNames.add(rule.CustomTeamsMessage__r.MessageTemplate__c);
            groupNames.add(rule.Value__c.trim());
        }
        Map<String, String> objectsByTemplate = getObjectsByTemplate(templateNames);
        Set<String> existingGroups = new Set<String>();
        for (Group existingGroup : [SELECT Type, DeveloperName FROM Group WHERE DeveloperName IN :groupNames AND Type IN ('Queue', 'Regular')]) existingGroups.add(existingGroup.Type + '|' + existingGroup.DeveloperName);

        List<String> invalidRules = new List<String>();
        for (CustomEmailRecipient__mdt rule : rules) {
            for (String templateName : new List<String>{ rule.CustomEmailAlert__r.EmailTemplate__c, rule.CustomTeamsMessage__r.MessageTemplate__c }) {
                String error = getRuleError(rule, objectsByTemplate.get(templateName), existingGroups);
                if (error != null) invalidRules.add(rule.DeveloperName + ': ' + error);
            }
        }
        return invalidRules;
    }

    // Null when the row is valid; its record field and condition are checked only when its template has an object (Lightning)
    private static String getRuleError(CustomEmailRecipient__mdt rule, String objectName, Set<String> existingGroups) {
        String value = rule.Value__c.trim();
        if (rule.Type__c == 'Queue' && !existingGroups.contains('Queue|' + value)) return 'queue ' + value + ' not found';
        if (rule.Type__c == 'PublicGroup' && !existingGroups.contains('Regular|' + value)) return 'public group ' + value + ' not found';
        if (rule.Type__c == 'Apex' && !(Type.forName(value)?.newInstance() instanceof EmailService.RecipientResolver)) return value + ' is not an Apex class implementing EmailService.RecipientResolver';
        if (objectName == null) return null;

        try {
            if (rule.Type__c == 'RecordField') Database.query('SELECT ' + value + ' FROM ' + objectName + ' LIMIT 0');
            if (String.isNotBlank(rule.Condition__c)) Formula.builder().withType(((SObject) Type.forName(objectName).newInstance()).getSObjectType()).withReturnType(FormulaEval.FormulaReturnType.BOOLEAN).withFormula(rule.Condition__c).build();
        }
        catch (Exception e) {
            return e.getMessage();
        }
        return null;
    }

    // Apex row of testBuild: the running user for every record
    public class RunningUserResolver implements EmailService.RecipientResolver {
        public Map<Id, Set<Id>> getUserIds(Set<Id> recordIds) {
            Map<Id, Set<Id>> userIdsByRecordId = new Map<Id, Set<Id>>();
            for (Id recordId : recordIds) userIdsByRecordId.put(recordId, new Set<Id>{ UserInfo.getUserId() });
            return userIdsByRecordId;
        }
    }

    // A real alert of the org, its template and a test record of the template's object
    private class AlertSample {
        public String alertName;
        public String templateName;
        public Id recordId;

        public AlertSample(String alertName, String templateName, Id recordId) {
            this.alertName = alertName;
            this.templateName = templateName;
            this.recordId = recordId;
        }
    }
}