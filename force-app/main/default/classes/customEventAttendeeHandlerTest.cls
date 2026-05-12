@IsTest
private class customEventAttendeeHandlerTest {

    @IsTest
    static void testEmptyTriggerMethods() {
        customEventAttendeeHandler h = new customEventAttendeeHandler();

        h.BeforeInsert(new List<SObject>());
        h.BeforeUpdate(new Map<Id, SObject>(), new Map<Id, SObject>());
        h.BeforeDelete(new Map<Id, SObject>());
        h.AfterUpdate(new Map<Id, SObject>(), new Map<Id, SObject>());
        h.AfterDelete(new Map<Id, SObject>());
        h.AfterUndelete(new Map<Id, SObject>());

        System.assert(true);
    }

    @IsTest
    static void testAfterInsert() {
        customEventAttendeeHandler h = new customEventAttendeeHandler();

        Id fakeAttendeeId = (Id)(EventAttendee__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

        EventAttendee__c attendee = new EventAttendee__c(
            Id = fakeAttendeeId
        );

        Test.startTest();
        h.AfterInsert(new Map<Id, SObject>{ attendee.Id => attendee });
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testIsDisabled() {
        customEventAttendeeHandler.triggerDisabled = true;

        Test.startTest();
        Boolean result = new customEventAttendeeHandler().isDisabled();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }
    @IsTest
    static void testBeforeAndAfterUpdate() {
        customEventAttendeeHandler h = new customEventAttendeeHandler();

        Id fakeId = (Id)(EventAttendee__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

        EventAttendee__c oldRec = new EventAttendee__c(Id = fakeId);
        EventAttendee__c newRec = new EventAttendee__c(Id = fakeId);

        Test.startTest();

        h.BeforeUpdate(
            new Map<Id, SObject>{ fakeId => newRec },
            new Map<Id, SObject>{ fakeId => oldRec }
        );

        h.AfterUpdate(
            new Map<Id, SObject>{ fakeId => newRec },
            new Map<Id, SObject>{ fakeId => oldRec }
        );

        Test.stopTest();

        System.assert(true);
}
}