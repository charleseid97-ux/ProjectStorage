@IsTest
private class EventMeetingNoteQuickActionCTRLTest {

    // Récupère le RecordType Meeting
    private static Id getMeetingRecordTypeId() {
        return Event__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('Meeting')
            .getRecordTypeId();
    }

    // Test getPayload avec eventId null
    @IsTest
    static void testGetPayloadWithNullId() {
        Test.startTest();
        EventMeetingNoteQuickActionCTRL.Payload result =
            EventMeetingNoteQuickActionCTRL.getPayload(null);
        Test.stopTest();

        System.assertEquals(null, result.eventId);
    }

    // Test getPayload sans Meeting Note
    @IsTest
    static void testGetPayloadWithoutMeetingNote() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Event__c ev = BooklyDataFactory.createEvent();
        ev.Name = 'Test Event';
        ev.RecordTypeId = getMeetingRecordTypeId();
        ev.company__c = acc.Id;
        ev.startDate__c = Date.today();
        insert ev;

        Test.startTest();
        EventMeetingNoteQuickActionCTRL.Payload result =
            EventMeetingNoteQuickActionCTRL.getPayload(ev.Id);
        Test.stopTest();

        System.assertEquals(ev.Id, result.eventId);
        System.assertEquals(false, result.hasMeetingNote);
        System.assertEquals('Meeting', result.meetingType);
    }

    // Test création Meeting Note depuis save
    @IsTest
    static void testSaveCreatesMeetingNote() {
        Account acc = new Account(Name = 'Test Account Create');
        insert acc;

        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;

        Event__c ev = BooklyDataFactory.createEvent();
        ev.Name = 'Test Event Create';
        ev.RecordTypeId = getMeetingRecordTypeId();
        ev.company__c = acc.Id;
        ev.startDate__c = Date.today();
        insert ev;

        EventAttendee__c attendee = new EventAttendee__c(
            Event__c = ev.Id,
            Contact__c = con.Id
        );
        insert attendee;

        Test.startTest();
        EventMeetingNoteQuickActionCTRL.SaveResult result =
            EventMeetingNoteQuickActionCTRL.save(ev.Id, '<p>Test note</p>');
        Test.stopTest();

        System.assertEquals(true, result.created);
        System.assertNotEquals(null, result.meetingNoteId);
    }

    // Test update Meeting Note existante
    @IsTest
    static void testSaveUpdatesMeetingNote() {
        Account acc = new Account(Name = 'Test Account Update');
        insert acc;

        Meeting_Note__c mn = new Meeting_Note__c(
            Name = 'Existing Note',
            Company__c = acc.Id,
            Date__c = Date.today(),
            Meeting_Type__c = 'Meeting',
            Raw_Note__c = 'Old note'
        );
        insert mn;

        Event__c ev = BooklyDataFactory.createEvent();
        ev.Name = 'Test Event Update';
        ev.RecordTypeId = getMeetingRecordTypeId();
        ev.company__c = acc.Id;
        ev.startDate__c = Date.today();
        ev.meetingNote__c = mn.Id;
        insert ev;

        Event stdEvent = new Event(
            Subject = 'Existing Standard Event',
            WhatId = acc.Id,
            Meeting_Note__c = mn.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert stdEvent;

        Test.startTest();
        EventMeetingNoteQuickActionCTRL.SaveResult result =
            EventMeetingNoteQuickActionCTRL.save(ev.Id, '<p>Updated note</p>');
        Test.stopTest();

        Meeting_Note__c updatedMn = [
            SELECT Raw_Note__c
            FROM Meeting_Note__c
            WHERE Id = :mn.Id
        ];

        System.assertEquals(false, result.created);
        System.assertEquals('<p>Updated note</p>', updatedMn.Raw_Note__c);
    }

    // Test save sans eventId
    @IsTest
    static void testSaveWithoutEventId() {
        Test.startTest();
        try {
            EventMeetingNoteQuickActionCTRL.save(null, 'note');
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}