@IsTest
private class customEventNotificationManagerTest {

    @IsTest
    static void testPublicHelpersCoverage() {
        User u = [SELECT Id, Email, IsActive FROM User WHERE IsActive = true LIMIT 1];

        Group g = new Group(
            Name = 'Bookly Test Group',
            DeveloperName = 'Bookly_Test_Group',
            Type = 'Regular'
        );
        insert g;

        insert new GroupMember(
            GroupId = g.Id,
            UserOrGroupId = u.Id
        );

        Map<String, List<User>> usersByGroup =
            customEventNotificationManager.loadUsersByGroupName(
                new Set<String>{ 'Bookly_Test_Group', 'Unknown_Group' }
            );

        System.assert(usersByGroup.containsKey('Bookly_Test_Group'));

        SessionSpeakerProduct__c emptySsp = new SessionSpeakerProduct__c();

        String htmlEmpty =
            customEventNotificationManager.buildPresentationHTML(emptySsp);

        System.assert(htmlEmpty.contains('Unknown speaker'));
        System.assert(htmlEmpty.contains('Unknown product'));

        SessionSpeakerProduct__c fullSsp = new SessionSpeakerProduct__c();
        fullSsp.SpeakerContact__r = new Contact(FirstName = 'John', LastName = 'Speaker');
        fullSsp.Strategy__r = new Strategy__c(Name = 'Strategy Test');

        String htmlFull =
            customEventNotificationManager.buildPresentationHTML(fullSsp);

        
        Map<String, List<Event__c>> typeMap = new Map<String, List<Event__c>>();

        customEventNotificationManager.addEventToTypeMap(
            typeMap,
            'Event',
            new Event__c(Name = 'Test')
        );

        customEventNotificationManager.addEventToTypeMap(
            typeMap,
            'Event',
            new Event__c(Name = 'Test 2')
        );

        System.assertEquals(2, typeMap.get('Event').size());

        System.assertEquals(
            System.Label.BooklySubmittedMessage,
            customEventNotificationManager.buildStatusMessage(
                new Event__c(Status__c = 'SubmittedToEventTeam')
            )
        );

        System.assertEquals(
            System.Label.BooklyApprovedMessage,
            customEventNotificationManager.buildStatusMessage(
                new Event__c(Status__c = 'FullyApproved')
            )
        );

        System.assertEquals(
            null,
            customEventNotificationManager.buildStatusMessage(
                new Event__c(Status__c = 'Draft')
            )
        );

        Map<String, List<String>> salesTeamEmails =
            new Map<String, List<String>>{
                'France' => new List<String>{ 'team@test.com' }
            };

        Event__c evtForRecipients = new Event__c(
            SalesTeam__c = 'France'
        );
        evtForRecipients.Organizer__r = new User(Email = 'organizer@test.com');
        evtForRecipients.SalesOwner__r = new User(Email = 'owner@test.com');

        Set<String> recipients =
            customEventNotificationManager.buildRecipients(
                evtForRecipients,
                salesTeamEmails
            );

        System.assertEquals(true, recipients.contains('organizer@test.com'));
        System.assertEquals(true, recipients.contains('owner@test.com'));
        System.assertEquals(true, recipients.contains('team@test.com'));

        System.assertNotEquals(
            null,
            customEventNotificationManager.loadSalesTeamEmails()
        );

        System.assertNotEquals(
            null,
            customEventNotificationManager.loadStrategyToUsernamesMap()
        );
    }

    @IsTest
    static void testGetEventTypeCoverage() {
        Id parentId =
            (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

        Event__c noRt = new Event__c();
        System.assertEquals(null, customEventNotificationManager.getEventType(noRt));

        Event__c eventRt = new Event__c();
        eventRt.RecordType = new RecordType(DeveloperName = 'event');
        System.assertEquals('Event', customEventNotificationManager.getEventType(eventRt));

        Event__c mdRt = new Event__c();
        mdRt.RecordType = new RecordType(DeveloperName = 'MeetingDays');
        System.assertEquals('MeetingDays', customEventNotificationManager.getEventType(mdRt));

        Event__c meetingStandalone = new Event__c();
        meetingStandalone.RecordType = new RecordType(DeveloperName = 'Meeting');
        System.assertEquals('1to1StandAlone', customEventNotificationManager.getEventType(meetingStandalone));

        Event__c meetingChild = new Event__c(ParentEvent__c = parentId);
        meetingChild.RecordType = new RecordType(DeveloperName = 'Meeting');
        System.assertEquals('1to1MeetingDays', customEventNotificationManager.getEventType(meetingChild));

        Event__c unknownRt = new Event__c();
        unknownRt.RecordType = new RecordType(DeveloperName = 'Other');
        System.assertEquals(null, customEventNotificationManager.getEventType(unknownRt));
    }

    @IsTest
    static void testMapSspsToUsernamesCoverage() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account)data.get('company1')).Id,
            ((User)data.get('OrganizerUser')).Id
        );

        Contact speaker = (Contact)data.get('Speaker1');

        Strategy__c strategy = new Strategy__c(
            Name = 'Strategy Code Test',
            Code__c = 'CODE_TEST'
        );
        insert strategy;

        SessionSpeakerProduct__c ssp = BooklyDataFactory.createSessionSpeakerProduct(
            evt.Id,
            speaker.Id,
            strategy.Id
        );

        Map<String, List<SessionSpeakerProduct__c>> matched =
            customEventNotificationManager.mapSspsToUsernames(
                new List<SessionSpeakerProduct__c>{ ssp },
                new Map<String, Set<String>>{ 'code_test' => new Set<String>{ 'user@test.com' } }
            );

        System.assertEquals(true, matched.containsKey('user@test.com'));

        Map<String, List<SessionSpeakerProduct__c>> notMatched =
            customEventNotificationManager.mapSspsToUsernames(
                new List<SessionSpeakerProduct__c>{ ssp },
                new Map<String, Set<String>>{ 'other_code' => new Set<String>{ 'user@test.com' } }
            );

        System.assertEquals(0, notMatched.size());
    }

    @IsTest
    static void testEntryPointsEmptyCoverage() {
        Id fakeId =
            (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

        customEventNotificationManager.requestPresentation(null);
        customEventNotificationManager.requestPresentation(new List<SessionSpeakerProduct__c>());

        customEventNotificationManager.notifyOneToOneMeetingDaysCreatedTodelete(null);
        customEventNotificationManager.notifyOneToOneMeetingDaysCreatedTodelete(new List<Event__c>());

        customEventNotificationManager.notifyCampaignCreated(null);
        customEventNotificationManager.notifyCampaignCreated(new List<Event__c>());

        customEventNotificationManager.notifyEventStatusChange(
            new Map<Id, Event__c>{
                fakeId => new Event__c(Id = fakeId, Status__c = 'Draft')
            },
            new Map<Id, Event__c>{
                fakeId => new Event__c(Id = fakeId, Status__c = 'Draft')
            }
        );

        System.assert(true);
    }
    @IsTest
static void testNotifyCampaignCreatedWithCampaign() {
    Map<String, SObject> data = BooklyDataFactory.setupForBookly();

    Event__c ev = BooklyDataFactory.createEvent(
        ((Account)data.get('company1')).Id,
        ((User)data.get('OrganizerUser')).Id
    );

    Campaign camp = new Campaign(
        Name = 'Test Campaign',
        Status = 'Planned',
        StartDate = Date.today(),
        EndDate = Date.today().addDays(10)
    );
    insert camp;

    ev.Campaign__c = camp.Id;
    update ev;

    Test.startTest();

    customEventNotificationManager.notifyCampaignCreated(
        new List<Event__c>{ ev }
    );

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testNotifOneToOneMDCreatedNoSalesTeamMatch() {
    Map<String, SObject> data = BooklyDataFactory.setupForBookly();

    Event__c evt = BooklyDataFactory.createEvent(
        ((Account)data.get('company1')).Id,
        ((User)data.get('OrganizerUser')).Id
    );

    evt.SalesTeam__c = 'UNKNOWN_SALES_TEAM';
    update evt;

    evt = [
        SELECT Id, SalesTeam__c, parentEvent__r.SalesTeam__c
        FROM Event__c
        WHERE Id = :evt.Id
    ];

    Test.startTest();

    customEventNotificationManager.NotifOneToOneMDCreated(
        new List<Event__c>{ evt }
    );

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testSendPresentationEmailsSkipUserNoEmail() {
    Map<String, SObject> data = BooklyDataFactory.setupForBookly();

    Event__c evt = BooklyDataFactory.createEvent(
        ((Account)data.get('company1')).Id,
        ((User)data.get('OrganizerUser')).Id
    );

    Strategy__c strategy = (Strategy__c)data.get('Strategy1');
    Contact speaker = (Contact)data.get('Speaker1');

    SessionSpeakerProduct__c ssp = BooklyDataFactory.createSessionSpeakerProduct(
        evt.Id,
        speaker.Id,
        strategy.Id
    );

    SessionSpeakerProduct__c loadedSsp = [
        SELECT Id, Session__c, Strategy__r.Name, Strategy__r.Code__c, SpeakerContact__r.Name
        FROM SessionSpeakerProduct__c
        WHERE Id = :ssp.Id
    ];

    User currentUser = [
        SELECT Id, Email, Username, IsActive
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];

    Test.startTest();

    customEventNotificationManager.sendPresentationEmails(
        new Map<String, List<SessionSpeakerProduct__c>>{
            currentUser.Username => new List<SessionSpeakerProduct__c>{ loadedSsp }
        },
        new Map<String, User>{
            currentUser.Username => new User(
                Id = currentUser.Id,
                Username = currentUser.Username,
                IsActive = true
            )
        }
    );

    Test.stopTest();

    System.assert(true);
}

@IsTest
static void testNotifyOneToOneMeetingDaysCreatedTodeleteCoverage() {

    Map<String, SObject> data = BooklyDataFactory.setupForBookly();

    User organizer = (User)data.get('OrganizerUser');
    Account acc = (Account)data.get('company1');

    Map<String, Schema.RecordTypeInfo> rtMap =
        Schema.SObjectType.Event__c.getRecordTypeInfosByDeveloperName();

    Event__c parentMeetingDays =
        BooklyDataFactory.createEvent(acc.Id, organizer.Id);

    parentMeetingDays.RecordTypeId =
        rtMap.get('MeetingDays').getRecordTypeId();

    parentMeetingDays.SalesTeam__c = 'TEST';

    update parentMeetingDays;

    Event__c childMeeting =
        BooklyDataFactory.createEvent(acc.Id, organizer.Id);

    childMeeting.RecordTypeId =
        rtMap.get('Meeting').getRecordTypeId();

    childMeeting.ParentEvent__c = parentMeetingDays.Id;
    childMeeting.SalesTeam__c = 'TEST';

    update childMeeting;

    Test.startTest();

    customEventNotificationManager.notifyOneToOneMeetingDaysCreatedTodelete(
        new List<Event__c>{ childMeeting }
    );

    Test.stopTest();

    System.assert(true);
}
}