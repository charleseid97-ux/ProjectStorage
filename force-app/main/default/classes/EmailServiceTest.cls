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