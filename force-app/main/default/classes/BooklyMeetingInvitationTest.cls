@IsTest
private class BooklyMeetingInvitationTest {

    private static final String TEMPLATE_DEV_NAME = 'BooklyGenericNotif_VF';

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

        Id eventRtId = getRecordTypeId('Event');
        Id meetingDaysRtId = getRecordTypeId('MeetingDays');
        Id meetingRtId = getRecordTypeId('Meeting');

        Event__c eventRecord = buildEvent(eventRtId, 'Event Title', 'Digital');
        eventRecord.category__c = 'Event conference';
        Event__c meetingDays = buildEvent(meetingDaysRtId, 'Meeting Days Title', 'Physical');
        meetingDays.category__c = 'Meeting day(s)';
        Event__c meeting = buildEvent(meetingRtId, 'Meeting Title', 'Digital');
        meeting.category__c = 'One to One meeting';

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

        Id eventRtId = getRecordTypeId('Event');

        Event__c eventRecord = buildEvent(eventRtId, 'Approved On Insert', 'Digital');
        eventRecord.Status__c = 'FullyApproved';
        eventRecord.category__c = 'Event conference';
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

        Id meetingRtId = getRecordTypeId('Meeting');

        Event__c oldEvent = buildEvent(meetingRtId, 'Update Approval', 'Digital');
        oldEvent.Status__c = 'Draft';
        oldEvent.category__c = 'One to One meeting';
        insert oldEvent;

        createSpeakerLinks(new Set<Id>{ oldEvent.Id });

        Event__c newEvent = oldEvent.clone(true, true, true, true);
        newEvent.Status__c = 'FullyApproved';

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

        Id eventRtId = getRecordTypeId('Event');

        Event__c oldEvent = buildEvent(eventRtId, 'Already Approved', 'Digital');
        oldEvent.Status__c = 'FullyApproved';
        oldEvent.category__c = 'Event conference';
        insert oldEvent;

        Event__c newEvent = oldEvent.clone(true, true, true, true);
        newEvent.Status__c = 'FullyApproved';

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
        eventRecord.Status__c = 'Draft';
        eventRecord.StartDate__c = Date.today().addDays(10);
        eventRecord.StartTime__c = '11:45';
        eventRecord.EndDate__c = Date.today().addDays(10);
        eventRecord.EndTime__c = '12:45';
        eventRecord.TimeZone__c = 'Asia/Singapore';
        eventRecord.City__c = 'Digital';
        eventRecord.SalesTeam__c = 'France';
        eventRecord.Co_hosted__c = 'No';
        eventRecord.clientType__c = 'B2B Buyer';
        eventRecord.country__c = 'Digital';

        eventRecord.Organizer__c = UserInfo.getUserId();
        eventRecord.SalesOwner__c = UserInfo.getUserId();
        eventRecord.OwnerId = UserInfo.getUserId();

        return eventRecord;
    }

    private static void createSpeakerLinks(Set<Id> eventIds) {
        Contact speaker = new Contact(
            LastName = 'Speaker Test',
            Email = 'speaker.test@example.com',
            SpeakerAssistant__c = UserInfo.getUserId()
        );
        insert speaker;

        Strategy__c strategy = new Strategy__c(
            Name = 'Absolute Return Europe',
            Code__c = 'CARE'
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
        template.Name = 'Bookly Generic Notif VF Test';
        template.DeveloperName = TEMPLATE_DEV_NAME;
        template.TemplateType = 'custom';
        template.FolderId = UserInfo.getUserId();
        template.Subject = '[Bookly] [!subject]';
        template.HtmlValue = '<html><body><p>[!subject]</p><p>[!message]</p></body></html>';
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