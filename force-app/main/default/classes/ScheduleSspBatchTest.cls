@IsTest
private class ScheduleSspBatchTest {

    // Test batch SSP complet
    @IsTest
    static void testBatch() {

        Account acc =
            BooklyDataFactory.createAccount();

        User organizer =
            BooklyDataFactory.createOrganizer();

        Contact c =
            BooklyDataFactory.createSpeakerContact(
                acc.Id,
                organizer.Id,
                false
            );


        Strategy__c strategy =
            BooklyDataFactory.createStrategy(
                'Strategy Test'
            );

        strategy.Code__c = 'NOTH';

        update strategy;


        Event__c ev =
            BooklyDataFactory.createEvent();

        ev.ScheduleID__c = '19525';

        ev.NoAutomations__c = true;

        insert ev;


        String csv =
            'TECH_ID_Speaker_Schedule__c;Schedule_Key_Event__c;Schedule_Key_Session__c;Start_Date_Time__c;End_Date_Time__c;Name;Thematic__c;Is_Valid_Speaker__c\n' +
            c.Email +
            '_22160_19525;19525;22160;25/01/2024 11:00;25/01/2024 12:30;' +
            c.Email +
            ';NOTH;1';


        ScheduleSspBatch.testCsvContent = csv;

        Test.startTest();

        Database.executeBatch(
            new ScheduleSspBatch(0, 1),
            1
        );

        Test.stopTest();


        sessionSpeakerProduct__c ssp = [

            SELECT Id,
                   scheduleId__c,
                   Session__c,
                   SpeakerContact__c,
                   Strategy__c,
                   date__c,
                   startTime__c,
                   endTime__c
            FROM sessionSpeakerProduct__c
            LIMIT 1
        ];


        System.assertEquals(
            ev.Id,
            ssp.Session__c
        );

        System.assertEquals(
            c.Id,
            ssp.SpeakerContact__c
        );

        System.assertEquals(
            strategy.Id,
            ssp.Strategy__c
        );

        System.assertEquals(
            Date.newInstance(2024, 1, 25),
            ssp.date__c
        );
    }
}