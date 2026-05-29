@IsTest
private class ScheduleEventsBatchTest {

    private static String buildCsv() {
        return
            'TECH_ID_Schedule__c;RecordType;Name;Owner;CRM_User__c;Sales_Team__c;Type;Status;Company__c;Event_Type__c;Start_Date_Time__c;End_Date_Time__c;Local_zone__c;Commercial_Strategy__c;Participants_number__c;B2B2C__c;Description;Carmignac_office__c;Carmignac_Office_location__c;Location_name__c;Address_1__c;Address_2__c;Post_Code__c;City__c;Country__c;Map_to_Venue__c;Etouches_invitation__c;Brand__c;Thought_Leadership__c;Expertise__c;Product__c;Thought_Leadership_T__c;Expertise_T__c;Product_T__c;Event_Local_Start_Time__c;Event_Local_End_Time__c;Call_Type__c\n' +
            '00001;event;EMEA - Paris - Sales Presentation Event;;;FR;Sales Presentation;Event Validated;;;2026-04-10T09:30:00;2026-04-10T11:00:00;30;;25;;Desc 1;;;Hotel Lutetia;45 Boulevard Raspail;;75006;Paris;France;;;;;;;;;09:30;11:00;\n' +
            '00002;event;EMEA - London - One to One;;;GB;One-To-One Meeting;Outlook Invitation;;;2026-04-11T14:00:00;2026-04-11T15:30:00;27;;12;;Desc 2;;;London Office;1 King Street;;SW1;London;United Kingdom;;;;;;;;;14:00;15:30;\n' +
            '00003;event;EMEA - Webinar - Digital Paris;;;FR;Sales Presentation;Event Validated;;;2026-04-12T09:30:00;2026-04-12T11:00:00;30;;40;;Desc 3;;;;;;;Digital_ParisTime;France;;;;;;;;09:30;11:00;\n' +
            '00004;event;EMEA - Webinar - Digital London;;;GB;Partnership;Outlook Invitation;;;2026-04-13T14:00:00;2026-04-13T15:00:00;27;;18;;Desc 4;;;;;;;Digital_LondonTime;United Kingdom;;;;;;;;14:00;15:00;\n';
    }

    @IsTest
    static void testHelperBuildRowAndBuildEvent_Physical() {
        String csv = buildCsv();

        ScheduleEventsCsvHelper.ParsedCsv parsed =
            ScheduleEventsCsvHelper.loadFromCsvString(csv);

        System.assertNotEquals(null, parsed);
        System.assertNotEquals(null, parsed.headerIndex);
        System.assertEquals(4, ScheduleEventsCsvHelper.getDataRecords(parsed).size());

        String firstLine = ScheduleEventsCsvHelper.getDataRecords(parsed)[0];
        System.assertNotEquals(null, firstLine);

        ScheduleEventsCsvHelper.RowData row =
            ScheduleEventsCsvHelper.buildRow(parsed.headerIndex, firstLine);

        System.assertNotEquals(null, row);
        System.assertEquals('00001', row.scheduleId);
        System.assertEquals('Sales Presentation', row.sourceType);
        System.assertEquals('Event Validated', row.sourceStatus);
        System.assertEquals('30', row.localZone);
        System.assertEquals(Date.newInstance(2026, 4, 10), row.startDate);
        System.assertEquals(Date.newInstance(2026, 4, 10), row.endDate);
        System.assertEquals('09:30', row.startTimeText);
        System.assertEquals('11:00', row.endTimeText);
        System.assertEquals('Paris', row.city);
        System.assertEquals('France', row.country);
        System.assertEquals('France', row.salesTeam);
        System.assertEquals(null, row.originalDigitalCity);

        Event__c ev = ScheduleEventsCsvHelper.buildEvent(row);

        System.assertNotEquals(null, ev);
        System.assertEquals('00001', ev.ScheduleID__c);
        System.assertEquals('Event conference', ev.category__c);
        System.assertEquals('FullyApproved', ev.status__c);
        System.assertEquals('Europe/Paris', ev.timeZone__c);
        System.assertEquals('Paris', ev.city__c);
        System.assertEquals('France', ev.country__c);
        System.assertEquals('Physical', ev.format__c);
        System.assertEquals(25, ev.targetedAttendees__c);
    }

    @IsTest
    static void testHelperBuildRowAndBuildEvent_DigitalParis() {
        String csv = buildCsv();

        ScheduleEventsCsvHelper.ParsedCsv parsed =
            ScheduleEventsCsvHelper.loadFromCsvString(csv);

        String digitalLine = ScheduleEventsCsvHelper.getDataRecords(parsed)[2];

        ScheduleEventsCsvHelper.RowData row =
            ScheduleEventsCsvHelper.buildRow(parsed.headerIndex, digitalLine);

        System.assertNotEquals(null, row);
        System.assertEquals('00003', row.scheduleId);
        System.assertEquals('Digital_ParisTime', row.originalDigitalCity);
        System.assertEquals('Digital', row.city);
        System.assertEquals('Digital', row.country);
        System.assertEquals('France', row.salesTeam);
        System.assertEquals('30', row.localZone);

        Event__c ev = ScheduleEventsCsvHelper.buildEvent(row);

        System.assertNotEquals(null, ev);
        System.assertEquals('00003', ev.ScheduleID__c);
        System.assertEquals('Digital', ev.city__c);
        System.assertEquals('Digital', ev.country__c);
        System.assertEquals('Digital', ev.format__c);
        System.assertEquals('Europe/Paris', ev.timeZone__c);
        System.assertEquals('Event conference', ev.category__c);
        System.assertEquals('FullyApproved', ev.status__c);
        System.assertEquals(40, ev.targetedAttendees__c);
    }

    @IsTest
    static void testHelperBuildRowAndBuildEvent_DigitalLondon() {
        String csv = buildCsv();

        ScheduleEventsCsvHelper.ParsedCsv parsed =
            ScheduleEventsCsvHelper.loadFromCsvString(csv);

        String digitalLine = ScheduleEventsCsvHelper.getDataRecords(parsed)[3];

        ScheduleEventsCsvHelper.RowData row =
            ScheduleEventsCsvHelper.buildRow(parsed.headerIndex, digitalLine);

        System.assertNotEquals(null, row);
        System.assertEquals('00004', row.scheduleId);
        System.assertEquals('Digital_LondonTime', row.originalDigitalCity);
        System.assertEquals('Digital', row.city);
        System.assertEquals('Digital', row.country);
        System.assertEquals('United Kingdom', row.salesTeam);
        System.assertEquals('27', row.localZone);

        Event__c ev = ScheduleEventsCsvHelper.buildEvent(row);

        System.assertNotEquals(null, ev);
        System.assertEquals('00004', ev.ScheduleID__c);
        System.assertEquals('Digital', ev.city__c);
        System.assertEquals('Digital', ev.country__c);
        System.assertEquals('Digital', ev.format__c);
        System.assertEquals('Europe/London', ev.timeZone__c);
        System.assertEquals('Event conference', ev.category__c);
        System.assertEquals('FullyApproved', ev.status__c);
        System.assertEquals(18, ev.targetedAttendees__c);
    }

    @IsTest
    static void testBatchCreatesEvents() {
        ScheduleEventsBatch.testCsvContent = buildCsv();

        Test.startTest();
        Id jobId = Database.executeBatch(new ScheduleEventsBatch(0, 3), 4);
        Test.stopTest();

        System.assertNotEquals(null, jobId);

        List<Event__c> events = [
            SELECT Id, ScheduleID__c, Name, category__c, status__c, timeZone__c,
                   city__c, country__c, format__c
            FROM Event__c
            WHERE ScheduleID__c IN ('00001', '00002', '00003', '00004')
            ORDER BY ScheduleID__c
        ];

        System.assertEquals(4, events.size());

        Map<String, Event__c> byScheduleId = new Map<String, Event__c>();
        for (Event__c ev : events) {
            byScheduleId.put(ev.ScheduleID__c, ev);
        }

        System.assert(byScheduleId.containsKey('00001'));
        System.assert(byScheduleId.containsKey('00002'));
        System.assert(byScheduleId.containsKey('00003'));
        System.assert(byScheduleId.containsKey('00004'));

        System.assertEquals('Event conference', byScheduleId.get('00001').category__c);
        System.assertEquals('FullyApproved', byScheduleId.get('00001').status__c);
        System.assertEquals('Europe/Paris', byScheduleId.get('00001').timeZone__c);
        System.assertEquals('Paris', byScheduleId.get('00001').city__c);
        System.assertEquals('France', byScheduleId.get('00001').country__c);
        System.assertEquals('Physical', byScheduleId.get('00001').format__c);

        System.assertEquals('One To One meeting', byScheduleId.get('00002').category__c);
        System.assertEquals('FullyApproved', byScheduleId.get('00002').status__c);
        System.assertEquals('Europe/London', byScheduleId.get('00002').timeZone__c);
        System.assertEquals('London', byScheduleId.get('00002').city__c);
        System.assertEquals('United Kingdom', byScheduleId.get('00002').country__c);
        System.assertEquals('Physical', byScheduleId.get('00002').format__c);

        System.assertEquals('Event conference', byScheduleId.get('00003').category__c);
        System.assertEquals('FullyApproved', byScheduleId.get('00003').status__c);
        System.assertEquals('Europe/Paris', byScheduleId.get('00003').timeZone__c);
        System.assertEquals('Digital', byScheduleId.get('00003').city__c);
        System.assertEquals('Digital', byScheduleId.get('00003').country__c);
        System.assertEquals('Digital', byScheduleId.get('00003').format__c);

        System.assertEquals('Event conference', byScheduleId.get('00004').category__c);
        System.assertEquals('FullyApproved', byScheduleId.get('00004').status__c);
        System.assertEquals('Europe/London', byScheduleId.get('00004').timeZone__c);
        System.assertEquals('Digital', byScheduleId.get('00004').city__c);
        System.assertEquals('Digital', byScheduleId.get('00004').country__c);
        System.assertEquals('Digital', byScheduleId.get('00004').format__c);
    }

    @IsTest
    static void testBatchCreatesOnlyFilteredRange() {
        ScheduleEventsBatch.testCsvContent = buildCsv();

        Test.startTest();
        Database.executeBatch(new ScheduleEventsBatch(1, 2), 2);
        Test.stopTest();

        List<Event__c> events = [
            SELECT ScheduleID__c
            FROM Event__c
            WHERE ScheduleID__c IN ('00001', '00002', '00003', '00004')
        ];

        Set<String> ids = new Set<String>();
        for (Event__c ev : events) {
            ids.add(ev.ScheduleID__c);
        }

        System.assertEquals(2, ids.size());
        System.assert(!ids.contains('00001'));
        System.assert(ids.contains('00002'));
        System.assert(ids.contains('00003'));
        System.assert(!ids.contains('00004'));
    }

    @IsTest
    static void testBatchNoRecordsWhenRangeOutsideFile() {
        ScheduleEventsBatch.testCsvContent = buildCsv();

        Test.startTest();
        Database.executeBatch(new ScheduleEventsBatch(10, 20), 5);
        Test.stopTest();

        Integer countEvents = [
            SELECT count()
            FROM Event__c
            WHERE ScheduleID__c IN ('00001', '00002', '00003', '00004')
        ];

        System.assertEquals(0, countEvents);
    }

    @IsTest
    static void testBatchUpdatesExistingEvent() {
        Event__c existing = new Event__c(
            ScheduleID__c = '00001',
            Name = 'Old Name',
            Title__c = 'Old Title',
            category__c = 'Event conference',
            status__c = 'Draft',
            timeZone__c = 'Europe/Paris',
            salesTeam__c = 'France',
            format__c = 'Physical',
            Co_hosted__c = 'No',
            startDate__c = Date.newInstance(2026, 4, 10),
            endDate__c = Date.newInstance(2026, 4, 10),
            city__c = 'Paris',
            country__c = 'France',
            clientType__c = 'B2B',
            Organizer__c = UserInfo.getUserId()
        );
        insert existing;

        ScheduleEventsBatch.testCsvContent = buildCsv();

        Test.startTest();
        Database.executeBatch(new ScheduleEventsBatch(0, 0), 1);
        Test.stopTest();

        List<Event__c> events = [
            SELECT Id, ScheduleID__c, Name, Title__c, category__c, status__c,
                timeZone__c, city__c, country__c, format__c, salesTeam__c
            FROM Event__c
            WHERE ScheduleID__c = '00001'
        ];

        System.assertEquals(1, events.size());
        System.assertEquals(existing.Id, events[0].Id);
        System.assertEquals('00001', events[0].ScheduleID__c);
        System.assertEquals('Event conference', events[0].category__c);
        System.assertEquals('FullyApproved', events[0].status__c);
        System.assertEquals('Europe/Paris', events[0].timeZone__c);
        System.assertEquals('Paris', events[0].city__c);
        System.assertEquals('France', events[0].country__c);
        System.assertEquals('Physical', events[0].format__c);
        System.assertEquals('France', events[0].salesTeam__c);
    }

    @IsTest
    static void testBatchWithEmptyCsvContent() {
        ScheduleEventsBatch.testCsvContent =
            'TECH_ID_Schedule__c;RecordType;Name;Owner;CRM_User__c;Sales_Team__c;Type;Status;Company__c;Event_Type__c;Start_Date_Time__c;End_Date_Time__c;Local_zone__c;Commercial_Strategy__c;Participants_number__c;B2B2C__c;Description;Carmignac_office__c;Carmignac_Office_location__c;Location_name__c;Address_1__c;Address_2__c;Post_Code__c;City__c;Country__c;Map_to_Venue__c;Etouches_invitation__c;Brand__c;Thought_Leadership__c;Expertise__c;Product__c;Thought_Leadership_T__c;Expertise_T__c;Product_T__c;Event_Local_Start_Time__c;Event_Local_End_Time__c;Call_Type__c\n';

        Test.startTest();
        Database.executeBatch(new ScheduleEventsBatch(0, 10), 5);
        Test.stopTest();

        Integer countEvents = [SELECT count() FROM Event__c];
        System.assertEquals(0, countEvents);
    }

    @IsTest
    static void testBuildSsps_ok() {
        Contact c = new Contact(LastName = 'Speaker One', Email = 'speaker1@test.com');
        insert c;

        Id strategy1 = 'a01580000000001AAA';
        Id strategy2 = 'a01580000000002AAA';
        Id eventId = 'a41580000000001AAA';

        ScheduleEventsCsvHelper.RowData row = new ScheduleEventsCsvHelper.RowData();
        row.speakerEmails = new Set<String>{ 'speaker1@test.com' };
        row.productNames = new Set<String>{ 'ProdA', 'ProdB' };
        row.startTime = Time.newInstance(10, 0, 0, 0);
        row.endTime = Time.newInstance(11, 30, 0, 0);

        Map<String, Contact> contactsByEmail = new Map<String, Contact>{
            'speaker1@test.com' => c
        };

        Map<String, Id> strategyByProductName = new Map<String, Id>{
            'ProdA' => strategy1,
            'ProdB' => strategy2
        };

        List<sessionSpeakerProduct__c> result = ScheduleEventsCsvHelper.buildSsps(
            row,
            eventId,
            contactsByEmail,
            strategyByProductName
        );

        System.assertEquals(2, result.size());

        Set<Id> strategyIds = new Set<Id>();
        for (sessionSpeakerProduct__c ssp : result) {
            System.assertEquals(eventId, ssp.Session__c);
            System.assertEquals(c.Id, ssp.SpeakerContact__c);
            System.assertEquals('English', ssp.Language__c);
            System.assertEquals('English', ssp.SpeakerLanguage__c);
            System.assertEquals(row.startTime, ssp.startTime__c);
            System.assertEquals(row.endTime, ssp.endTime__c);
            strategyIds.add(ssp.Strategy__c);
        }

        System.assert(strategyIds.contains(strategy1));
        System.assert(strategyIds.contains(strategy2));
    }

    @IsTest
    static void testBuildSsps_noEventId() {
        Contact c = new Contact(LastName = 'Speaker One', Email = 'speaker1@test.com');
        insert c;

        ScheduleEventsCsvHelper.RowData row = new ScheduleEventsCsvHelper.RowData();
        row.speakerEmails = new Set<String>{ 'speaker1@test.com' };
        row.productNames = new Set<String>{ 'ProdA' };
        row.startTime = Time.newInstance(10, 0, 0, 0);
        row.endTime = Time.newInstance(11, 0, 0, 0);

        Map<String, Contact> contactsByEmail = new Map<String, Contact>{
            'speaker1@test.com' => c
        };

        Map<String, Id> strategyByProductName = new Map<String, Id>{
            'ProdA' => 'a01580000000001AAA'
        };

        List<sessionSpeakerProduct__c> result = ScheduleEventsCsvHelper.buildSsps(
            row,
            null,
            contactsByEmail,
            strategyByProductName
        );

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testBuildSsps_noSpeakers() {
        ScheduleEventsCsvHelper.RowData row = new ScheduleEventsCsvHelper.RowData();
        row.speakerEmails = new Set<String>();
        row.productNames = new Set<String>{ 'ProdA' };

        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        Map<String, Id> strategyByProductName = new Map<String, Id>{
            'ProdA' => 'a01580000000001AAA'
        };

        List<sessionSpeakerProduct__c> result = ScheduleEventsCsvHelper.buildSsps(
            row,
            'a41580000000001AAA',
            contactsByEmail,
            strategyByProductName
        );

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testBuildSsps_noStrategies() {
        Contact c = new Contact(LastName = 'Speaker One', Email = 'speaker1@test.com');
        insert c;

        ScheduleEventsCsvHelper.RowData row = new ScheduleEventsCsvHelper.RowData();
        row.speakerEmails = new Set<String>{ 'speaker1@test.com' };
        row.productNames = new Set<String>{ 'ProdA' };

        Map<String, Contact> contactsByEmail = new Map<String, Contact>{
            'speaker1@test.com' => c
        };

        Map<String, Id> strategyByProductName = new Map<String, Id>();

        List<sessionSpeakerProduct__c> result = ScheduleEventsCsvHelper.buildSsps(
            row,
            'a41580000000001AAA',
            contactsByEmail,
            strategyByProductName
        );

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testBuildSsps_ignoreUnknownSpeaker() {
        Id strategy1 = 'a01580000000001AAA';

        ScheduleEventsCsvHelper.RowData row = new ScheduleEventsCsvHelper.RowData();
        row.speakerEmails = new Set<String>{ 'unknown@test.com' };
        row.productNames = new Set<String>{ 'ProdA' };

        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        Map<String, Id> strategyByProductName = new Map<String, Id>{
            'ProdA' => strategy1
        };

        List<sessionSpeakerProduct__c> result = ScheduleEventsCsvHelper.buildSsps(
            row,
            'a41580000000001AAA',
            contactsByEmail,
            strategyByProductName
        );

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testBuildSsps_deduplicateStrategies() {
        Contact c = new Contact(LastName = 'Speaker One', Email = 'speaker1@test.com');
        insert c;

        Id sameStrategy = 'a01580000000001AAA';

        ScheduleEventsCsvHelper.RowData row = new ScheduleEventsCsvHelper.RowData();
        row.speakerEmails = new Set<String>{ 'speaker1@test.com' };
        row.productNames = new Set<String>{ 'ProdA', 'ProdB' };

        Map<String, Contact> contactsByEmail = new Map<String, Contact>{
            'speaker1@test.com' => c
        };

        Map<String, Id> strategyByProductName = new Map<String, Id>{
            'ProdA' => sameStrategy,
            'ProdB' => sameStrategy
        };

        List<sessionSpeakerProduct__c> result = ScheduleEventsCsvHelper.buildSsps(
            row,
            'a41580000000001AAA',
            contactsByEmail,
            strategyByProductName
        );

        System.assertEquals(1, result.size());
        System.assertEquals(sameStrategy, result[0].Strategy__c);
    }
}