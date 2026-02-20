@IsTest
private class MeetingNoteShareControllerTest {

    @TestSetup
    static void setupData() {
        // Meeting Note (Date__c est requis dans ton org)
        Meeting_Note__c mn = new Meeting_Note__c(
            Name   = 'MN Test',
            Date__c = Date.today()
        );
        insert mn;

        Contact c = new Contact(LastName = 'Tester');
        insert c;

        // Event lié au Meeting Note
        Event evt = new Event(
            Subject       = 'Evt Test',
            StartDateTime = System.now(),
            EndDateTime   = System.now().addHours(1),
            WhoId         = c.Id
        );
        evt.put('Meeting_Note__c', mn.Id);
        insert evt;
    }

    @IsTest
    static void test_getMeetingNoteIdByEvent_nullInput() {
        Test.startTest();
        Id res = MeetingNoteShareController.getMeetingNoteIdByEvent(null);
        Test.stopTest();

        System.assertEquals(null, res, 'Null input must return null.');
    }

    @IsTest
    static void test_getMeetingNoteIdByEvent_returnsMeetingNoteId() {
        Event evt = [SELECT Id, Meeting_Note__c FROM Event WHERE Meeting_Note__c != null LIMIT 1];

        Test.startTest();
        Id res = MeetingNoteShareController.getMeetingNoteIdByEvent(evt.Id);
        Test.stopTest();

        System.assertEquals(evt.Meeting_Note__c, res, 'Must return Meeting_Note__c from the Event.');
    }

    @IsTest
    static void test_getMeetingNoteIdByEvent_eventWithoutMeetingNote() {
        // Create an event without Meeting_Note__c
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Event evt = new Event(
            Subject       = 'Evt No MN',
            StartDateTime = System.now(),
            EndDateTime   = System.now().addHours(1),
            WhoId         = c.Id
        );
        insert evt;

        Test.startTest();
        Id res = MeetingNoteShareController.getMeetingNoteIdByEvent(evt.Id);
        Test.stopTest();

        System.assertEquals(null, res, 'If Event.Meeting_Note__c is null, must return null.');
    }
}