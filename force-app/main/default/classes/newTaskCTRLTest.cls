@IsTest
public class newTaskCTRLTest {

    @IsTest
    static void testCreateTasks_Success() {

        // Create test data (Account + Meeting Note)
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Meeting_Note__c mn = new Meeting_Note__c(
            Name = 'Test Meeting Note',
            Date__c = Date.today()
        );
        insert mn;

        // Create task list
        List<Task> tasks = new List<Task>();
        Task t = new Task(
            Subject = 'Follow Up - Event',
            ActivityDate = Date.today().addDays(5),
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = mn.Id,
            OwnerId = UserInfo.getUserId()
        );
        tasks.add(t);

        Test.startTest();
        newTaskCTRL.createTasks(tasks);
        Test.stopTest();

        // Verify task was inserted
        List<Task> insertedTasks = [
            SELECT Id, Subject, WhatId
            FROM Task
            WHERE WhatId = :mn.Id
        ];

        System.assertEquals(1, insertedTasks.size(), 'One task should be created');
        System.assertEquals('Follow Up - Event', insertedTasks[0].Subject);
    }

    @IsTest
    static void testCreateTasks_EmptyList() {

        Test.startTest();
        newTaskCTRL.createTasks(new List<Task>());
        Test.stopTest();

        // No exception should occur
        System.assert(true, 'Method should handle empty list without errors');
    }

    // -------------------------
    // Coverage for getMeetingNoteId
    // -------------------------

    @IsTest
    static void testGetMeetingNoteId_NullEventId() {
        Test.startTest();
        Id result = newTaskCTRL.getMeetingNoteId(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when eventId is null');
    }

    @IsTest
    static void testGetMeetingNoteId_ReturnsMeetingNote() {

        // Create a Meeting Note
        Meeting_Note__c mn = new Meeting_Note__c(
            Name = 'Test Meeting Note For Event',
            Date__c = Date.today()
        );
        insert mn;

        // Create an Event linked to Meeting Note
        Event e = new Event(
            Subject = 'Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addMinutes(30),
            Meeting_Note__c = mn.Id
        );
        insert e;

        Test.startTest();
        Id result = newTaskCTRL.getMeetingNoteId(e.Id);
        Test.stopTest();

        System.assertEquals(mn.Id, result, 'Should return the linked Meeting Note Id');
    }
}