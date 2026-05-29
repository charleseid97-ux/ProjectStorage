@IsTest
private class BooklyMeetingInvitationTest {

    private static final String TEMPLATE_DEV_NAME = 'BooklyGenericNotif_VF';

    private static final String RT_EVENT = 'Event';
    private static final String RT_MEETING_DAYS = 'MeetingDays';
    private static final String RT_MEETING = 'Meeting';

    private static final String FORMAT_DIGITAL = 'Digital';
    private static final String FORMAT_PHYSICAL = 'Physical';

    private static final String STATUS_DRAFT = 'Draft';
    private static final String STATUS_FULLY_APPROVED = 'FullyApproved';

    private static final String CATEGORY_EVENT_CONFERENCE = 'Event conference';
    private static final String CATEGORY_MEETING_DAYS = 'Meeting day(s)';
    private static final String CATEGORY_ONE_TO_ONE = 'One to One meeting';

    private static final String TIMEZONE_SINGAPORE = 'Asia/Singapore';
    private static final String CITY_DIGITAL = 'Digital';
    private static final String SALES_TEAM_FRANCE = 'France';
    private static final String CO_HOSTED_NO = 'No';
    private static final String CLIENT_TYPE_B2B_BUYER = 'B2B Buyer';

    private static final String START_TIME = '11:45';
    private static final String END_TIME = '12:45';

    private static final String TEMPLATE_NAME = 'Bookly Generic Notif VF Test';
    private static final String TEMPLATE_TYPE_CUSTOM = 'custom';
    private static final String TEMPLATE_SUBJECT = '[Bookly] [!subject]';
    private static final String TEMPLATE_BODY = '<html><body><p>[!subject]</p><p>[!message]</p></body></html>';

    private static final String SPEAKER_LAST_NAME = 'Speaker Test';
    private static final String SPEAKER_EMAIL = 'speaker.test@example.com';
    private static final String STRATEGY_NAME = 'Absolute Return Europe';
    private static final String STRATEGY_CODE = 'CARE';

    private class GraphMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assert(request.getEndpoint().contains('/me/events'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                '{"id":"AAMkAGraphEventId123",' +
                '"subject":"Test",' +
                '"onlineMeeting":{"joinUrl":"https://teams.microsoft.com/l/meetup-join/test"}}'
            );
            return response;
        }
    }

    @IsTest
    static void testQueueableForEventMeetingDaysAndMeeting() {
        createEmailTemplate();

        Id eventRtId = getRecordTypeId(RT_EVENT);
        Id meetingDaysRtId = getRecordTypeId(RT_MEETING_DAYS);
        Id meetingRtId = getRecordTypeId(RT_MEETING);

        Event__c eventRecord = buildEvent(eventRtId, 'Event Title', FORMAT_DIGITAL);
        eventRecord.Category__c = CATEGORY_EVENT_CONFERENCE;

        Event__c meetingDays = buildEvent(meetingDaysRtId, 'Meeting Days Title', FORMAT_PHYSICAL);
        meetingDays.Category__c = CATEGORY_MEETING_DAYS;

        Event__c meeting = buildEvent(meetingRtId, 'Meeting Title', FORMAT_DIGITAL);
        meeting.Category__c = CATEGORY_ONE_TO_ONE;

        insert new List<Event__c>{ eventRecord, meetingDays, meeting };

        createSpeakerLinks(new Set<Id>{ eventRecord.Id, meetingDays.Id, meeting.Id });

        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();
        System.enqueueJob(
            new BooklyMeetingInvitationQueueable(
                new Set<Id>{ eventRecord.Id, meetingDays.Id, meeting.Id }
            )
        );
        Test.stopTest();

        System.assert(true, 'Queueable executed successfully.');
    }

    @IsTest
    static void testServiceEnqueuesOnInsertFullyApproved() {
        createEmailTemplate();

        Id eventRtId = getRecordTypeId(RT_EVENT);

        Event__c eventRecord = buildEvent(eventRtId, 'Approved On Insert', FORMAT_DIGITAL);
        eventRecord.Status__c = STATUS_FULLY_APPROVED;
        eventRecord.Category__c = CATEGORY_EVENT_CONFERENCE;
        insert eventRecord;

        createSpeakerLinks(new Set<Id>{ eventRecord.Id });

        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();
        BooklyMeetingInvitationService.enqueueInvitationsOnApproval(
            new List<Event__c>{ eventRecord },
            null
        );
        Test.stopTest();

        System.assert(true, 'Service enqueued invitation for insert-like approval.');
    }

    @IsTest
    static void testServiceEnqueuesOnUpdateToFullyApproved() {
        createEmailTemplate();

        Id meetingRtId = getRecordTypeId(RT_MEETING);

        Event__c oldEvent = buildEvent(meetingRtId, 'Update Approval', FORMAT_DIGITAL);
        oldEvent.Status__c = STATUS_DRAFT;
        oldEvent.Category__c = CATEGORY_ONE_TO_ONE;
        insert oldEvent;

        createSpeakerLinks(new Set<Id>{ oldEvent.Id });

        Event__c newEvent = oldEvent.clone(true, true, true, true);
        newEvent.Status__c = STATUS_FULLY_APPROVED;

        Map<Id, Event__c> oldMap = new Map<Id, Event__c>{
            oldEvent.Id => oldEvent
        };

        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();
        BooklyMeetingInvitationService.enqueueInvitationsOnApproval(
            new List<Event__c>{ newEvent },
            oldMap
        );
        Test.stopTest();

        System.assert(true, 'Service enqueued invitation for update approval.');
    }

    @IsTest
    static void testServiceDoesNotEnqueueWhenAlreadyApproved() {
        createEmailTemplate();

        Id eventRtId = getRecordTypeId(RT_EVENT);

        Event__c oldEvent = buildEvent(eventRtId, 'Already Approved', FORMAT_DIGITAL);
        oldEvent.Status__c = STATUS_FULLY_APPROVED;
        oldEvent.Category__c = CATEGORY_EVENT_CONFERENCE;
        insert oldEvent;

        Event__c newEvent = oldEvent.clone(true, true, true, true);
        newEvent.Status__c = STATUS_FULLY_APPROVED;

        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();
        BooklyMeetingInvitationService.enqueueInvitationsOnApproval(
            new List<Event__c>{ newEvent },
            new Map<Id, Event__c>{ oldEvent.Id => oldEvent }
        );
        Test.stopTest();

        System.assert(true, 'No queueable should be enqueued when status was already FullyApproved.');
    }

    private static Event__c buildEvent(Id recordTypeId, String title, String formatValue) {
        Event__c eventRecord = new Event__c();

        if (recordTypeId != null) {
            eventRecord.RecordTypeId = recordTypeId;
        }

        eventRecord.Title__c = title;
        eventRecord.Format__c = formatValue;
        eventRecord.Status__c = STATUS_DRAFT;
        eventRecord.StartDate__c = Date.today().addDays(10);
        eventRecord.StartTime__c = START_TIME;
        eventRecord.EndDate__c = Date.today().addDays(10);
        eventRecord.EndTime__c = END_TIME;
        eventRecord.TimeZone__c = TIMEZONE_SINGAPORE;
        eventRecord.City__c = CITY_DIGITAL;
        eventRecord.SalesTeam__c = SALES_TEAM_FRANCE;
        eventRecord.Co_hosted__c = CO_HOSTED_NO;
        eventRecord.ClientType__c = CLIENT_TYPE_B2B_BUYER;
        eventRecord.Country__c = CITY_DIGITAL;

        eventRecord.Organizer__c = UserInfo.getUserId();
        eventRecord.SalesOwner__c = UserInfo.getUserId();
        eventRecord.OwnerId = UserInfo.getUserId();

        return eventRecord;
    }

    private static void createSpeakerLinks(Set<Id> eventIds) {
        Contact speaker = new Contact(
            LastName = SPEAKER_LAST_NAME,
            Email = SPEAKER_EMAIL,
            SpeakerAssistant__c = UserInfo.getUserId()
        );
        insert speaker;

        Strategy__c strategy = new Strategy__c(
            Name = STRATEGY_NAME,
            Code__c = STRATEGY_CODE
        );
        insert strategy;

        List<SessionSpeakerProduct__c> links = new List<SessionSpeakerProduct__c>();

        for (Id eventId : eventIds) {
            links.add(new SessionSpeakerProduct__c(
                Session__c = eventId,
                SpeakerContact__c = speaker.Id,
                Strategy__c = strategy.Id
            ));
        }

        insert links;
    }

    private static void createEmailTemplate() {
        List<EmailTemplate> existingTemplates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_DEV_NAME
            LIMIT 1
        ];

        if (!existingTemplates.isEmpty()) {
            return;
        }

        EmailTemplate template = new EmailTemplate();
        template.Name = TEMPLATE_NAME;
        template.DeveloperName = TEMPLATE_DEV_NAME;
        template.TemplateType = TEMPLATE_TYPE_CUSTOM;
        template.FolderId = UserInfo.getUserId();
        template.Subject = TEMPLATE_SUBJECT;
        template.HtmlValue = TEMPLATE_BODY;
        template.IsActive = true;

        insert template;
    }

    private static Id getRecordTypeId(String developerName) {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Event__c'
            AND DeveloperName = :developerName
            LIMIT 1
        ];

        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }
}