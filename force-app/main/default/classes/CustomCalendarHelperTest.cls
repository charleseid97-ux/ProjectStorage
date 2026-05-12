@IsTest
private class CustomCalendarHelperTest {

    // Couvre getUserUtcOffset + getEventPrefix.
    @IsTest
    static void testSimpleMethods() {
        Test.startTest();
        String tz = CustomCalendarHelper.getUserUtcOffset();
        String prefix = CustomCalendarHelper.getEventPrefix();
        Test.stopTest();

        System.assertNotEquals(null, tz);
        System.assertNotEquals(null, prefix);
    }

    // Couvre getEvents sans recordId.
    @IsTest
    static void testGetEventsWithoutRecordId() {
        Test.startTest();

        List<CustomCalendarHelper.EventDto> res =
            CustomCalendarHelper.getEvents(
                null,
                'Event__c',
                'ParentEvent__c',
                'startDate__c',
                'endDate__c',
                'Name',
                Date.today(),
                'color__c',
                Date.today().addDays(30),
                null,
                null,
                null,
                null
            );

        Test.stopTest();

        System.assertNotEquals(null, res);
    }

    // Couvre getEvents avec speaker filter.
    @IsTest
    static void testGetEventsWithSpeakerFilter() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        evt.color__c = '#FFFFFF';
        update evt;

        BooklyDataFactory.createSessionSpeakerProduct(
            evt.Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((Strategy__c) data.get('Strategy1')).Id
        );

        Test.startTest();

        List<CustomCalendarHelper.EventDto> res =
            CustomCalendarHelper.getEvents(
                evt.Id,
                'Event__c',
                'ParentEvent__c',
                'startDate__c',
                'endDate__c',
                'Name',
                Date.today(),
                'color__c',
                Date.today().addDays(30),
                new List<String>{ 'Belgium' },
                new List<Id>{ ((Contact) data.get('SpeakerTop1')).Id },
                new List<String>{ 'Analyst' },
                'Europe/Paris'
            );

        Test.stopTest();

       // System.assert(res.size() > 0);
       // System.assertEquals('#000000', res[0].textColor);
    }

    // Couvre computeTextColor sombre.
    @IsTest
    static void testGetEventsDarkColor() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        evt.color__c = '#000000';
        update evt;

        Test.startTest();

        List<CustomCalendarHelper.EventDto> res =
            CustomCalendarHelper.getEvents(
                null,
                'Event__c',
                'ParentEvent__c',
                'startDate__c',
                'endDate__c',
                'Name',
                Date.today(),
                'color__c',
                Date.today().addDays(30),
                null,
                null,
                null,
                null
            );

        Test.stopTest();

        System.assert(res.size() > 0);
        System.assertEquals('#FFFFFF', res[0].textColor);
    }

    // Couvre parseHourMinute invalide.
    @IsTest
    static void testGetEventsInvalidTime() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        evt.startTime__c = '99:99';
        update evt;

        Test.startTest();

        List<CustomCalendarHelper.EventDto> res =
            CustomCalendarHelper.getEvents(
                null,
                'Event__c',
                'ParentEvent__c',
                'startDate__c',
                'endDate__c',
                'Name',
                Date.today(),
                'color__c',
                Date.today().addDays(30),
                null,
                null,
                null,
                null
            );

        Test.stopTest();

        System.assertNotEquals(null, res);
    }

    // Couvre getEventColors.
    @IsTest
    static void testGetEventColors() {
        Test.startTest();
        List<CustomCalendarHelper.EventColorLegendDto> res =
            CustomCalendarHelper.getEventColors();
        Test.stopTest();

        System.assertNotEquals(null, res);
    }

    // Couvre getSpeakerContacts sans parentEventId.
    @IsTest
    static void testGetSpeakerContactsWithoutParent() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Test.startTest();
        List<CustomCalendarHelper.Option> res =
            CustomCalendarHelper.getSpeakerContacts(null);
        Test.stopTest();

        System.assert(res.size() > 0);
    }

    // Couvre getSpeakerContacts avec parentEventId.
    @IsTest
    static void testGetSpeakerContactsWithParent() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        BooklyDataFactory.createSessionSpeakerProduct(
            evt.Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((Strategy__c) data.get('Strategy1')).Id
        );

        Test.startTest();
        List<CustomCalendarHelper.Option> res =
            CustomCalendarHelper.getSpeakerContacts(evt.Id);
        Test.stopTest();

        System.assert(res.size() > 0);
    }
}