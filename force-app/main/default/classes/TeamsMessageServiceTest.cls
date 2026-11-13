/** ──────────────────────────────────────
 * @description Tests of the Microsoft Teams messages engine (US-20337): TeamsMessageService.build() on a real Custom Teams Message of the org (its rows replaced by in-memory ones),
 *                  the dry run and the No Recipient fallback, the configuration errors, PMTTeamOwnerRecipients on a project, its milestone and a document (team owners, the teams'
 *                  Notification Conditions evaluated on the project), send() through TeamsMessageQueueable with mocked Microsoft Graph calls (sent, recipient not found, message
 *                  refused, masked address skipped) and the Flow action CustomTeamsMessageFlowAction. No Custom Teams Message of the org uses a Custom Email Alert's template.
 *              Assertions pass in any org: the Teams messages and the teams' Notification Conditions are read at runtime, never hard-coded.
 * @author Charles EID
 * @covers TeamsMessageService   98%   [12-11-26]
 * @covers TeamsMessageQueueable   86%   [12-11-26]
 * @covers CustomTeamsMessageFlowAction   100%   [12-11-26]
 * @covers PMTTeamOwnerRecipients   100%   [12-11-26]
 ────────────────────────────────────── */
@IsTest
public class TeamsMessageServiceTest {

    private static final String DRY_RUN_ADDRESS = 'tms.dryrun@example.com';
    private static final String NO_RECIPIENT_ADDRESS = 'tms.norecipient@example.com';
    private static final String SENT_ADDRESS = 'tms.sent@example.com';
    private static final String UNKNOWN_ADDRESS = 'tms.unknown@example.com';
    private static final String REFUSED_ADDRESS = 'tms.refused@example.com';
    private static final String MASKED_ADDRESS = 'tms.masked@example.com.invalid';
    private static final String CONDITIONAL_OWNER_ALIAS = 'tmsCond';

    // The settings' addresses (tests don't see the org's custom setting data), a project whose teams are owned by the running user, except the teams with a Notification Condition
    // owned by another user, and the project's milestone and document
    @TestSetup
    static void setupTestData() {
        insert new EmailServiceSettings__c(SetupOwnerId = UserInfo.getOrganizationId(), DryRunAddresses__c = DRY_RUN_ADDRESS, NoRecipientAddresses__c = NO_RECIPIENT_ADDRESS);
        User conditionalOwner = PMTTestFactoryData.createTestUser(CONDITIONAL_OWNER_ALIAS);
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        Map<String, String> conditionByTeam = getConditionByTeam();
        Map<String, Schema.SObjectField> projectFields = Schema.SObjectType.ProjectProduct__c.fields.getMap();
        for (PMTMatrix.Team team : PMTMatrix.get().teams) {
            if (projectFields.containsKey(team.key + '__c')) project.put(team.key + '__c', conditionByTeam.containsKey(team.name) ? conditionalOwner.Id : UserInfo.getUserId());
        }
        update project;
        PMTTestFactoryData.createMilestone(project.Id, 'TMS milestone', Date.today());
        insert new ProjectDocuments__c(Name = 'TMS document', Project_product__c = project.Id, RecordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectDocuments__c', 'Core_Document'), Type__c = 'Prospectus');
    }

    // Engine: a real Teams message with in-memory rows, dry run, No Recipient fallback, configuration errors; PMTTeamOwnerRecipients on the project and its records
    @IsTest
    static void testBuild() {
        ProjectProduct__c project = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        Milestone__c milestone = [SELECT Id FROM Milestone__c WHERE Name = 'TMS milestone' LIMIT 1];
        ProjectDocuments__c document = [SELECT Id FROM ProjectDocuments__c LIMIT 1];
        Id conditionalOwnerId = [SELECT Id FROM User WHERE Alias = :CONDITIONAL_OWNER_ALIAS].Id;
        Set<Id> recordIds = new Set<Id>{ project.Id, milestone.Id, document.Id };
        MessageSample sample = getMessageSample(project.Id, milestone.Id);
        TeamsMessageService.TeamsMessageRequest rowRequest = newRequest(sample, new List<CustomEmailRecipient__mdt>{ newRule('To', 'Address', 'tms.to@example.com'), newRule('Cc', 'Address', 'tms.cc@example.com') });
        TeamsMessageService.TeamsMessageRequest dryRunRequest = newRequest(sample, new List<CustomEmailRecipient__mdt>{ newRule('To', 'Address', 'tms.to@example.com') });
        dryRunRequest.emailRequest.dryRun = true;
        TeamsMessageService.TeamsMessageRequest noRecipientRequest = newRequest(sample, new List<CustomEmailRecipient__mdt>());
        // A record without lookup to ProjectProduct__c: PMTTeamOwnerRecipients can't find its project
        TeamsMessageService.TeamsMessageRequest noProjectRequest = newRequest(sample, new List<CustomEmailRecipient__mdt>{ newRule('To', 'Apex', 'PMTTeamOwnerRecipients') });
        noProjectRequest.emailRequest.whatId = UserInfo.getUserId();

        Test.startTest();

        Map<Id, Set<Id>> userIdsByRecordId = new PMTTeamOwnerRecipients().getUserIds(recordIds);
        Boolean conditionalOwnerExpected = isAnyConditionTrue(project.Id);
        List<TeamsMessageService.Delivery> rowDeliveries = TeamsMessageService.build(new List<TeamsMessageService.TeamsMessageRequest>{ rowRequest });
        List<TeamsMessageService.Delivery> dryRunDeliveries = TeamsMessageService.build(new List<TeamsMessageService.TeamsMessageRequest>{ dryRunRequest });
        List<TeamsMessageService.Delivery> noRecipientDeliveries = TeamsMessageService.build(new List<TeamsMessageService.TeamsMessageRequest>{ noRecipientRequest });
        String noProjectError = getBuildError(noProjectRequest);
        // Each platform has its own template: a template used by a Custom Email Alert is never the body of a Custom Teams Message
        Set<String> emailTemplates = new Set<String>();
        for (CustomEmailAlert__mdt alert : [SELECT EmailTemplate__c FROM CustomEmailAlert__mdt]) emailTemplates.add(alert.EmailTemplate__c);
        List<String> sharedTemplates = new List<String>();
        for (CustomTeamsMessage__mdt message : [SELECT DeveloperName, MessageTemplate__c FROM CustomTeamsMessage__mdt]) {
            if (emailTemplates.contains(message.MessageTemplate__c)) sharedTemplates.add(message.DeveloperName + ' (' + message.MessageTemplate__c + ')');
        }
        String unknownMessageError;
        try {
            new TeamsMessageService.TeamsMessageRequest('TMS_Unknown_Message', null);
        }
        catch (EmailService.EmailServiceException e) {
            unknownMessageError = e.getMessage();
        }

        Test.stopTest();

        for (Id recordId : recordIds) {
            System.assert(userIdsByRecordId.get(recordId).contains(UserInfo.getUserId()), 'The owner of the teams without Notification Condition is notified, from the project, its milestone or its document');
            System.assertEquals(conditionalOwnerExpected, userIdsByRecordId.get(recordId).contains(conditionalOwnerId), 'The owner of the conditional teams is notified only when one of their conditions is true for the project');
        }
        Set<String> rowAddresses = new Set<String>();
        for (TeamsMessageService.Delivery delivery : rowDeliveries) rowAddresses.add(delivery.address);
        System.assertEquals(new Set<String>{ 'tms.to@example.com', 'tms.cc@example.com' }, rowAddresses, 'A Teams message goes to every row, whatever its Send As');
        System.assert(String.isNotBlank(rowDeliveries[0].content) && rowDeliveries[0].content == rowDeliveries[1].content, 'Every recipient receives the same rendered template');
        System.assertEquals(sample.messageName, rowDeliveries[0].messageName, 'The delivery knows its Teams message');

        System.assertEquals(1, dryRunDeliveries.size(), 'A dry run goes to the dry-run addresses only');
        System.assertEquals(DRY_RUN_ADDRESS, dryRunDeliveries[0].address, 'A dry run goes to the dry-run addresses only');
        System.assert(dryRunDeliveries[0].content.contains(EmailService.DRY_RUN_SUBJECT_PREFIX + 'This Teams message') && dryRunDeliveries[0].content.contains('tms.to@example.com'), 'The real recipients are listed at the top of the dry run');

        System.assertEquals(1, noRecipientDeliveries.size(), 'A Teams message without recipient is still sent');
        System.assertEquals(NO_RECIPIENT_ADDRESS, noRecipientDeliveries[0].address, 'A Teams message without recipient goes to the No Recipient Addresses');
        System.assert(noRecipientRequest.emailRequest.noRecipient, 'The request is flagged for the WARN log of send()');

        System.assert(noProjectError != null && noProjectError.contains('needs exactly one lookup to ProjectProduct__c'), 'A record without project is a configuration error: ' + noProjectError);
        System.assertEquals('Custom Teams Message "TMS_Unknown_Message" not found.', unknownMessageError, 'An unknown Teams message name throws');
        System.assert(sharedTemplates.isEmpty(), 'A Custom Teams Message uses its own Teams template, never the template of a Custom Email Alert: ' + sharedTemplates);
    }

    // Callouts: one message sent, one recipient not in Microsoft 365 (WARN), one message refused (ERROR), a masked address skipped; then the Flow action
    @IsTest
    static void testSend() {
        ProjectProduct__c project = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        Milestone__c milestone = [SELECT Id FROM Milestone__c WHERE Name = 'TMS milestone' LIMIT 1];
        MessageSample sample = getMessageSample(project.Id, milestone.Id);
        TeamsMessageService.TeamsMessageRequest request = newRequest(sample, new List<CustomEmailRecipient__mdt>{ newRule('To', 'Address', SENT_ADDRESS), newRule('To', 'Address', UNKNOWN_ADDRESS), newRule('Cc', 'Address', REFUSED_ADDRESS), newRule('Cc', 'Address', MASKED_ADDRESS) });
        CustomTeamsMessageFlowAction.Request flowRequest = newFlowRequest(sample, new List<String>{ '{_Token_}' }, new List<String>{ 'Value' });
        flowRequest.additionalAddresses = 'tms.flow1@example.com, tms.flow2@example.com';
        flowRequest.dryRun = true;
        CustomTeamsMessageFlowAction.Request mismatchRequest = newFlowRequest(sample, new List<String>{ '{_A_}', '{_B_}' }, new List<String>{ 'Value' });
        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();

        TeamsMessageService.TeamsMessageRequest flowBuilt = CustomTeamsMessageFlowAction.buildRequests(new List<CustomTeamsMessageFlowAction.Request>{ flowRequest })[0];
        TeamsMessageService.send(new List<TeamsMessageService.TeamsMessageRequest>{ request });
        CustomTeamsMessageFlowAction.sendCustomTeamsMessages(new List<CustomTeamsMessageFlowAction.Request>{ flowRequest });
        String mismatchError;
        try {
            CustomTeamsMessageFlowAction.sendCustomTeamsMessages(new List<CustomTeamsMessageFlowAction.Request>{ mismatchRequest });
        }
        catch (EmailService.EmailServiceException e) {
            mismatchError = e.getMessage();
        }

        Test.stopTest();

        Map<String, String> levelByRecipient = new Map<String, String>();
        for (OperationLog__c log : [SELECT Level__c, Context__c FROM OperationLog__c WHERE Operation__c = :request.emailRequest.logOperation]) {
            for (String address : new List<String>{ SENT_ADDRESS, UNKNOWN_ADDRESS, REFUSED_ADDRESS, MASKED_ADDRESS, DRY_RUN_ADDRESS }) {
                if (log.Context__c.contains(address)) levelByRecipient.put(address, log.Level__c);
            }
        }
        System.assertEquals('WARN', levelByRecipient.get(UNKNOWN_ADDRESS), 'A recipient not found in Microsoft 365 is logged as WARN');
        System.assertEquals('ERROR', levelByRecipient.get(REFUSED_ADDRESS), 'A message Teams refuses is logged as ERROR');
        System.assert(!levelByRecipient.containsKey(SENT_ADDRESS) && !levelByRecipient.containsKey(DRY_RUN_ADDRESS), 'A sent message is not logged');
        System.assert(!levelByRecipient.containsKey(MASKED_ADDRESS), 'A masked sandbox address is skipped without log');
        System.assert(flowBuilt.emailRequest.to.addresses.containsAll(new Set<String>{ 'tms.flow1@example.com', 'tms.flow2@example.com' }) && flowBuilt.emailRequest.dryRun, 'The Flow\'s Additional Addresses and Dry Run reach the request');
        System.assert(mismatchError != null && mismatchError.contains('2 Replacement Tokens for 1 Replacement Values'), 'Tokens and values of different sizes make the Flow fail: ' + mismatchError);
    }

    // A real Teams message, its rows replaced by in-memory ones, outside dry run and with its failures logged (whatever the record says)
    private static TeamsMessageService.TeamsMessageRequest newRequest(MessageSample sample, List<CustomEmailRecipient__mdt> rules) {
        TeamsMessageService.TeamsMessageRequest request = new TeamsMessageService.TeamsMessageRequest(sample.messageName, sample.recordId);
        request.emailRequest.recipientRules.clear();
        request.emailRequest.recipientRules.addAll(rules);
        request.emailRequest.dryRun = false;
        request.emailRequest.logFailures = true;
        return request;
    }

    private static CustomEmailRecipient__mdt newRule(String sendAs, String type, String value) {
        return new CustomEmailRecipient__mdt(DeveloperName = 'TMS' + sendAs + type, SendAs__c = sendAs, Type__c = type, Value__c = value);
    }

    private static CustomTeamsMessageFlowAction.Request newFlowRequest(MessageSample sample, List<String> replacementTokens, List<String> replacementValues) {
        CustomTeamsMessageFlowAction.Request request = new CustomTeamsMessageFlowAction.Request();
        request.teamsMessageName = sample.messageName;
        request.recordId = sample.recordId;
        request.replacementTokens = replacementTokens;
        request.replacementValues = replacementValues;
        return request;
    }

    private static String getBuildError(TeamsMessageService.TeamsMessageRequest request) {
        try {
            TeamsMessageService.build(new List<TeamsMessageService.TeamsMessageRequest>{ request });
        }
        catch (EmailService.EmailServiceException e) {
            return e.getMessage();
        }
        return null;
    }

    // An active Teams message of the org whose template is on the project or the milestone: the tests use whatever messages the org has
    private static MessageSample getMessageSample(Id projectId, Id milestoneId) {
        Map<String, Id> recordIdByObject = new Map<String, Id>{ 'ProjectProduct__c' => projectId, 'Milestone__c' => milestoneId };
        Map<String, String> templateByMessage = new Map<String, String>();
        for (CustomTeamsMessage__mdt message : [SELECT DeveloperName, MessageTemplate__c FROM CustomTeamsMessage__mdt WHERE IsActive__c = true ORDER BY DeveloperName]) templateByMessage.put(message.DeveloperName, message.MessageTemplate__c);
        Map<String, String> objectByTemplate = new Map<String, String>();
        for (EmailTemplate template : [SELECT DeveloperName, RelatedEntityType FROM EmailTemplate WHERE DeveloperName IN :templateByMessage.values()]) objectByTemplate.put(template.DeveloperName, template.RelatedEntityType);
        for (String messageName : templateByMessage.keySet()) {
            Id recordId = recordIdByObject.get(objectByTemplate.get(templateByMessage.get(messageName)));
            if (recordId != null) return new MessageSample(messageName, recordId);
        }
        System.assert(false, 'The tests need one active Custom Teams Message whose Lightning template is on ProjectProduct__c or Milestone__c');
        return null;
    }

    // Notification Condition of each PMT team that has one, by team name
    private static Map<String, String> getConditionByTeam() {
        Map<String, String> conditionByTeam = new Map<String, String>();
        for (PMTTeam__mdt team : [SELECT MasterLabel, NotificationCondition__c FROM PMTTeam__mdt]) {
            if (String.isNotBlank(team.NotificationCondition__c)) conditionByTeam.put(team.MasterLabel, team.NotificationCondition__c);
        }
        return conditionByTeam;
    }

    // True when one of the teams' Notification Conditions is true for the project, read from the records like PMTTeamOwnerRecipients does
    private static Boolean isAnyConditionTrue(Id projectId) {
        List<PMTCondition> conditions = new List<PMTCondition>();
        Set<String> fields = new Set<String>();
        for (String condition : getConditionByTeam().values()) {
            conditions.add(PMTCondition.compile(condition));
            fields.addAll(PMTCondition.compile(condition).projectFields);
        }
        ProjectProduct__c project = PMTCondition.queryProjects(new Set<Id>{ projectId }, fields, new Set<String>())[0];
        for (PMTCondition condition : conditions) {
            if (condition.evaluate(project, null)) return true;
        }
        return false;
    }

    // Microsoft Graph: an unknown address has no user, the refused address's chat refuses the message, everything else succeeds
    private class GraphMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            String endpoint = EncodingUtil.urlDecode(request.getEndpoint(), 'UTF-8');
            if (endpoint.endsWith('/me')) setResponse(response, 200, '{"id": "tms-sender"}');
            else if (endpoint.contains('/users?')) setResponse(response, 200, endpoint.contains(UNKNOWN_ADDRESS) ? '{"value": []}' : '{"value": [{"id": "' + (endpoint.contains(REFUSED_ADDRESS) ? 'tms-refused' : 'tms-user') + '"}]}');
            else if (endpoint.endsWith('/chats')) setResponse(response, 201, '{"id": "' + (request.getBody().contains('tms-refused') ? 'chat-refused' : 'chat-ok') + '"}');
            else setResponse(response, endpoint.contains('chat-refused') ? 403 : 201, '{}');
            return response;
        }

        private void setResponse(HttpResponse response, Integer statusCode, String body) {
            response.setStatusCode(statusCode);
            response.setBody(body);
        }
    }

    // A real Teams message of the org and a test record of its template's object
    private class MessageSample {
        public String messageName;
        public Id recordId;

        public MessageSample(String messageName, Id recordId) {
            this.messageName = messageName;
            this.recordId = recordId;
        }
    }
}
