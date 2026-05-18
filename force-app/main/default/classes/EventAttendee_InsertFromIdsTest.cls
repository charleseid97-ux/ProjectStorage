@IsTest
private class EventAttendee_InsertFromIdsTest {

    // Test avec IDs en CSV
    @IsTest
    static void testExecuteWithCsvIds() {
        Event__c eventRecord = BooklyDataFactory.createEvent();
        insert eventRecord;

        Contact contactRecord = new Contact(LastName = 'Test Contact');
        insert contactRecord;

        EventAttendee_InsertFromIds.InputWrapper input = new EventAttendee_InsertFromIds.InputWrapper();
        input.eventId = eventRecord.Id;
        input.contactIdsCsv = String.valueOf(contactRecord.Id);

        Test.startTest();
        List<EventAttendee_InsertFromIds.ResultWrapper> results =
            EventAttendee_InsertFromIds.execute(new List<EventAttendee_InsertFromIds.InputWrapper>{ input });
        Test.stopTest();

        System.assertEquals(1, results[0].insertedCount);
        System.assertEquals(null, results[0].errorMessage);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM EventAttendee__c
            WHERE Event__c = :eventRecord.Id
        ]);
    }

    // Test avec IDs en JSON
    @IsTest
    static void testExecuteWithJsonIds() {
        Event__c eventRecord = BooklyDataFactory.createEvent();
        eventRecord.Name = 'Test Event JSON';
        insert eventRecord;

        Contact contactRecord = new Contact(LastName = 'Test Contact JSON');
        insert contactRecord;

        EventAttendee_InsertFromIds.InputWrapper input = new EventAttendee_InsertFromIds.InputWrapper();
        input.eventId = eventRecord.Id;
        input.contactIdsJson = '["' + String.valueOf(contactRecord.Id) + '"]';

        Test.startTest();
        List<EventAttendee_InsertFromIds.ResultWrapper> results =
            EventAttendee_InsertFromIds.execute(new List<EventAttendee_InsertFromIds.InputWrapper>{ input });
        Test.stopTest();

        System.assertEquals(1, results[0].insertedCount);
        System.assertEquals(null, results[0].errorMessage);
    }

    // Test sans eventId
    @IsTest
    static void testExecuteMissingEventId() {
        EventAttendee_InsertFromIds.InputWrapper input = new EventAttendee_InsertFromIds.InputWrapper();
        input.contactIdsCsv = UserInfo.getUserId();

        Test.startTest();
        List<EventAttendee_InsertFromIds.ResultWrapper> results =
            EventAttendee_InsertFromIds.execute(new List<EventAttendee_InsertFromIds.InputWrapper>{ input });
        Test.stopTest();

        System.assertEquals(0, results[0].insertedCount);
        System.assertEquals('Missing eventId', results[0].errorMessage);
    }

    // Test avec inputs null
    @IsTest
    static void testExecuteWithNullInputs() {
        Test.startTest();
        List<EventAttendee_InsertFromIds.ResultWrapper> results =
            EventAttendee_InsertFromIds.execute(null);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }
}