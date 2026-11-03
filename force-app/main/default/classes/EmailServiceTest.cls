/** ──────────────────────────────────────
 * @description Test class for EmailService.
 *              Covers recipient type resolution (submitter, current/next approvers,
 *              record owner, queue expansion), additional recipient resolution,
 *              and sendTemplateEmail early-return guards.
 *              Email engine (US-ImproveEmailServiceEngine): build() on the real Custom Email Alerts (AIAgent*), Apex-built requests (no template, queues, users, chunking, template subject override),
 *                  configuration errors, send() removing the invalid addresses Salesforce rejects (WARN logs), the dry run (dry-run addresses, subject prefix, real recipients banner), and the Flow action CustomEmailAlertFlowAction.
 * @author Charles EID
 * @covers EmailService   98%   [03-11-26]
 * @covers CustomEmailAlertFlowAction   100%   [03-11-26]
 * @lastModifiedBy Charles EID   [03-11-26]
 ────────────────────────────────────── */
@IsTest
public class EmailServiceTest {

    private static final String QUEUE_NAME = 'EST_Queue';
    private static final String DRY_RUN_ADDRESS = 'est.dryrun@example.com';

    // A queue whose only member is the running user, the dry-run address (tests don't see the org's custom setting data), and the records the real AIAgent* templates are rendered with (AI_Agent__c, Case)
    @TestSetup
    static void setupTestData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group queue = new Group(Name = QUEUE_NAME, DeveloperName = QUEUE_NAME, Type = 'Queue');
            insert queue;
            insert new GroupMember(GroupId = queue.Id, UserOrGroupId = UserInfo.getUserId());
        }
        insert new EmailServiceSettings__c(SetupOwnerId = UserInfo.getOrganizationId(), DryRunAddresses__c = DRY_RUN_ADDRESS);
        insert new AI_Agent__c(Name = 'EST Agent', Connectors__c = 'Outlook', Status__c = 'Active');
        insert new Case(Subject = 'EST AI Agent request', AgentName__c = 'EST Requested Agent');
    }

    @IsTest
    static void testSendTemplateEmail() {
        Id currentUserId = UserInfo.getUserId();
        Id agentId = [SELECT Id FROM AI_Agent__c LIMIT 1].Id;

        Test.startTest();

        // Early returns: no recipient, or a template that doesn't exist
        EmailService.sendTemplateEmail('SomeTemplate', null, null);
        EmailService.sendTemplateEmail('SomeTemplate', null, new Set<Id>());
        EmailService.sendTemplateEmail('NonExistent_Template_XYZ', currentUserId, new Set<Id>{ currentUserId });
        EmailService.sendTemplateEmail('SomeTemplate', null, null, null);
        EmailService.sendTemplateEmail('NonExistent_Template_XYZ', null, new Set<Id>(), new List<String>{ 'someone@example.com' });
        Integer invocationsAfterGuards = Limits.getEmailInvocations();
        // Real template: raw addresses only (a blank line is skipped, not sent as an empty "to" address), then a user and a raw address
        EmailService.sendTemplateEmail('AIAgentActivationRGPD', agentId, new Set<Id>(), new List<String>{ 'ops-alert@example.com', ' ', 'second-alert@example.com' });
        EmailService.sendTemplateEmail('AIAgentActivationRGPD', agentId, new Set<Id>{ currentUserId }, new List<String>{ 'ops-alert@example.com' });
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
        Id caseId = [SELECT Id FROM Case LIMIT 1].Id;

        Test.startTest();

        Set<Id> emptyTypes = EmailService.resolveRecipientIds(new Set<String>(), null, null, null, null, null);
        Set<Id> nullTypes = EmailService.resolveRecipientIds(null, null, null, null, null, null);
        Set<Id> submitter = EmailService.resolveRecipientIds(new Set<String>{ 'Submitter' }, null, null, runningUser.Id, null, null);
        Set<Id> currentApprovers = EmailService.resolveRecipientIds(new Set<String>{ 'CurrentStepApprovers' }, new Set<Id>{ queueId }, null, null, null, null);
        Set<Id> nextApprovers = EmailService.resolveRecipientIds(new Set<String>{ 'NextStepApprovers' }, null, new Set<Id>{ runningUser.Id }, null, null, null);
        Set<Id> recordOwner = EmailService.resolveRecipientIds(new Set<String>{ 'RecordOwner' }, null, null, null, caseId, 'Case');
        Set<Id> blankAdditional = EmailService.resolveAdditionalRecipientIds(null, null);
        Set<Id> additionalUser = EmailService.resolveAdditionalRecipientIds(null, runningUser.Username);
        Set<Id> additionalQueue = EmailService.resolveAdditionalRecipientIds(QUEUE_NAME, null);

        Test.stopTest();

        System.assertEquals(0, emptyTypes.size(), 'Should return empty set for empty types');
        System.assertEquals(0, nullTypes.size(), 'Should return empty set for null types');
        System.assert(submitter.contains(runningUser.Id), 'Should include the submitter');
        System.assert(currentApprovers.contains(runningUser.Id), 'Should expand queue approver to its user member');
        System.assert(nextApprovers.contains(runningUser.Id), 'Should include the next step approver');
        System.assert(recordOwner.contains(runningUser.Id), 'Should resolve the record owner');
        System.assertEquals(0, blankAdditional.size(), 'Should return empty set for blank inputs');
        System.assert(additionalUser.contains(runningUser.Id), 'Should resolve user by username');
        System.assert(additionalQueue.contains(runningUser.Id), 'Should resolve queue members as recipients');
    }

    // Engine: the real Custom Email Alerts, Apex-built requests and the configuration errors
    @IsTest
    static void testBuild() {
        Group regularGroup = new Group(Name = 'EST Regular Group', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert regularGroup;
        }
        Id queueId = [SELECT Id FROM Group WHERE DeveloperName = :QUEUE_NAME].Id;
        AI_Agent__c agent = [SELECT Id FROM AI_Agent__c LIMIT 1];
        Case agentRequest = [SELECT Id FROM Case LIMIT 1];
        List<EmailService.EmailRequest> alertRequests = new List<EmailService.EmailRequest>{ new EmailService.EmailRequest('AIAgentActivationRGPD', agent.Id), new EmailService.EmailRequest('AIAgentGovernanceDPOAssessment', agent.Id), new EmailService.EmailRequest('AIAgentGovernancePendingImplementation', agent.Id), new EmailService.EmailRequest('AIAgentGovernanceRSSIAssessment', agent.Id), new EmailService.EmailRequest('AIAgentRequestReminder', agentRequest.Id) };

        EmailService.EmailRequest bulkRequest = newApexRequest();
        bulkRequest.subject = 'EST subject {X}';
        bulkRequest.htmlBody = '<p>EST body {X}</p>';
        bulkRequest.replacements.put('{X}', 'Replaced');
        for (Integer i = 0; i < 130; i++) bulkRequest.to.addresses.add('est.to' + i + '@example.com');
        for (Integer i = 0; i < 40; i++) bulkRequest.cc.addresses.add('est.cc' + i + '@example.com');
        bulkRequest.to.queues.add(QUEUE_NAME);
        bulkRequest.bcc.userOrGroupIds.add(queueId);
        EmailService.EmailRequest templateRequest = new EmailService.EmailRequest();
        templateRequest.templateDeveloperName = 'AIAgentActivationRGPD';
        templateRequest.whatId = agent.Id;
        templateRequest.recipientId = UserInfo.getUserId();
        templateRequest.subject = 'EST override {X}';
        templateRequest.replacements.put('{X}', 'Replaced');
        templateRequest.sender = EmailService.Sender.ORG_WIDE;
        templateRequest.orgWideAddress = Label.EmailService_DefaultOrgWideAddress;
        EmailService.EmailRequest inactiveRequest = new EmailService.EmailRequest();
        inactiveRequest.isActive = false;
        EmailService.EmailRequest dryRunRequest = new EmailService.EmailRequest('AIAgentActivationRGPD', agent.Id);
        dryRunRequest.dryRun = true;
        dryRunRequest.recipientId = UserInfo.getUserId();
        dryRunRequest.cc.addresses.add('est.dryrun.cc@example.com');

        EmailService.EmailRequest unknownTemplate = newApexRequest();
        unknownTemplate.templateDeveloperName = 'EST_Unknown_Template';
        EmailService.EmailRequest unknownQueue = newApexRequest();
        unknownQueue.to.queues.add('EST_Unknown_Queue');
        EmailService.EmailRequest noToRecipient = newApexRequest();
        noToRecipient.to.addresses.clear();
        noToRecipient.cc.addresses.add('est.cc@example.com');
        EmailService.EmailRequest noBody = newApexRequest();
        noBody.htmlBody = null;
        EmailService.EmailRequest groupRecipient = newApexRequest();
        groupRecipient.recipientId = regularGroup.Id;
        EmailService.EmailRequest orgWideWithoutAddress = newApexRequest();
        orgWideWithoutAddress.sender = EmailService.Sender.ORG_WIDE;
        EmailService.EmailRequest unknownOrgWide = newApexRequest();
        unknownOrgWide.sender = EmailService.Sender.ORG_WIDE;
        unknownOrgWide.orgWideAddress = 'est.unknown.sender@example.com';
        Map<String, EmailService.EmailRequest> requestsByExpectedError = new Map<String, EmailService.EmailRequest>{ 'Email template(s) not found' => unknownTemplate, 'Queue(s) not found' => unknownQueue, 'has no To recipient' => noToRecipient, 'needs a subject and an HTML body' => noBody, 'must be a Contact, Lead or User' => groupRecipient, 'has no orgWideAddress' => orgWideWithoutAddress, 'Org-wide email address(es) not found' => unknownOrgWide };

        Test.startTest();

        List<Messaging.SingleEmailMessage> alertEmails = EmailService.build(alertRequests);
        List<Messaging.SingleEmailMessage> apexEmails = EmailService.build(new List<EmailService.EmailRequest>{ bulkRequest, templateRequest, inactiveRequest });
        List<Messaging.SingleEmailMessage> dryRunEmails = EmailService.build(new List<EmailService.EmailRequest>{ dryRunRequest });
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

        System.assertEquals(5, alertEmails.size(), 'One message per alert');
        for (Integer i = 0; i < alertEmails.size(); i++) {
            String expectedName = i < 4 ? 'EST Agent' : 'EST Requested Agent';
            System.assert(alertEmails[i].getSubject().contains(expectedName), 'The template merge field is rendered in the subject: ' + alertEmails[i].getSubject());
            System.assert(String.isNotBlank(alertEmails[i].getHtmlBody()), 'The template body is rendered');
            System.assert(!alertEmails[i].getToAddresses().isEmpty(), 'The alert To addresses are set');
            System.assertNotEquals(null, alertEmails[i].getOrgWideEmailAddressId(), 'No Reply alerts are sent from the default org-wide address');
        }

        System.assertEquals(3, apexEmails.size(), '132 To / 40 Cc split into 2 messages, 1 message for the template request, none for the inactive one');
        System.assertEquals(100, apexEmails[0].getToAddresses().size(), 'At most 100 To per message');
        System.assertEquals(25, apexEmails[0].getCcAddresses().size(), 'At most 25 Cc per message');
        System.assertEquals(1, apexEmails[0].getBccAddresses().size(), 'The queue member in Bcc');
        System.assertEquals(32, apexEmails[1].getToAddresses().size(), '131 addresses + the To queue member: the rest in the second message');
        System.assertEquals(15, apexEmails[1].getCcAddresses().size(), 'The remaining Cc in the second message');
        System.assertEquals('EST subject Replaced', apexEmails[0].getSubject(), 'Replacements are applied to the subject');
        System.assertEquals('<p>EST body Replaced</p>', apexEmails[1].getHtmlBody(), 'Every message carries the same body');
        System.assertEquals(null, apexEmails[0].getOrgWideEmailAddressId(), 'Current user sender: no org-wide address');
        System.assertEquals(UserInfo.getUserId(), apexEmails[2].getTargetObjectId(), 'The recipient record receives the email');
        System.assertEquals('EST override Replaced', apexEmails[2].getSubject(), 'The request subject overrides the template subject');
        System.assert(apexEmails[2].getHtmlBody().contains('EST Agent'), 'The template body is rendered with the record');
        System.assertNotEquals(null, apexEmails[2].getOrgWideEmailAddressId(), 'Org-wide sender resolved');

        System.assertEquals(1, dryRunEmails.size(), 'A dry run is a single message');
        System.assertEquals(new List<String>{ DRY_RUN_ADDRESS }, dryRunEmails[0].getToAddresses(), 'A dry run goes to the dry-run addresses only');
        System.assert(dryRunEmails[0].getCcAddresses() == null || dryRunEmails[0].getCcAddresses().isEmpty(), 'A dry run has no Cc');
        System.assertEquals(null, dryRunEmails[0].getTargetObjectId(), 'The recipient record doesn\'t receive a dry run');
        System.assert(dryRunEmails[0].getSubject().startsWith('DRY RUN - ') && dryRunEmails[0].getSubject().contains('EST Agent'), 'The rendered subject is prefixed: ' + dryRunEmails[0].getSubject());
        System.assert(dryRunEmails[0].getHtmlBody().contains('est.dryrun.cc@example.com') && dryRunEmails[0].getHtmlBody().contains('Recipient record: ' + UserInfo.getUserId()), 'The real recipients are listed in the body');

        for (String expectedError : errorsByExpectedError.keySet()) System.assert(String.valueOf(errorsByExpectedError.get(expectedError)).contains(expectedError), 'Expected "' + expectedError + '", got: ' + errorsByExpectedError.get(expectedError));
        System.assertEquals('Custom Email Alert "EST_Unknown_Alert" not found.', unknownAlertError, 'An unknown alert name throws');
    }

    // Engine: send() removing the invalid addresses, then the Flow action built on it
    @IsTest
    static void testSend() {
        AI_Agent__c agent = [SELECT Id FROM AI_Agent__c LIMIT 1];
        EmailService.EmailRequest partlyInvalid = newApexRequest();
        partlyInvalid.to.addresses.add('est invalid to');
        partlyInvalid.cc.addresses.add('est invalid cc');
        EmailService.EmailRequest onlyInvalid = newApexRequest();
        onlyInvalid.to.addresses.clear();
        onlyInvalid.to.addresses.add('est invalid only');
        List<CustomEmailAlertFlowAction.Request> flowRequests = new List<CustomEmailAlertFlowAction.Request>{ newFlowRequest(agent.Id, new List<String>{ '{_Token_}' }, new List<String>{ 'Value' }), newFlowRequest(agent.Id, null, null) };
        flowRequests[1].dryRun = true;
        CustomEmailAlertFlowAction.Request mismatchRequest = newFlowRequest(agent.Id, new List<String>{ '{_A_}', '{_B_}' }, new List<String>{ 'Value' });

        Test.startTest();

        EmailService.send(new List<EmailService.EmailRequest>{ partlyInvalid, onlyInvalid });
        // Read before the Flow action, which flushes the log buffer
        List<String> warnings = new List<String>();
        for (OperationLog__c log : OperationLogService.buffer) {
            if (log.Level__c == 'WARN') warnings.add(log.Message__c);
        }
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

        System.assertEquals(2, warnings.size(), 'One WARN per message with invalid addresses: ' + warnings);
        System.assert(warnings[0].contains('est invalid to') && warnings[0].contains('est invalid cc') && warnings[0].contains('resent'), 'Invalid To and Cc removed, email resent to the valid address: ' + warnings[0]);
        System.assert(warnings[1].contains('est invalid only') && warnings[1].contains('No recipient left'), 'Nothing left to send: ' + warnings[1]);
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

    // Flow action input on the real AIAgentActivationRGPD alert
    private static CustomEmailAlertFlowAction.Request newFlowRequest(Id recordId, List<String> replacementTokens, List<String> replacementValues) {
        CustomEmailAlertFlowAction.Request request = new CustomEmailAlertFlowAction.Request();
        request.alertName = 'AIAgentActivationRGPD';
        request.recordId = recordId;
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
}