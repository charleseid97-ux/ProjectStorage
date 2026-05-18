@IsTest
private class ScheduleSspBatchTest {

    // Création des données de test communes
    @TestSetup
    static void setup() {

        User organizer =
            BooklyDataFactory.createOrganizer();

        Account acc =
            BooklyDataFactory.createAccount();


        // Speaker top speaker
        Contact speaker =
            BooklyDataFactory.createSpeakerContact(
                acc.Id,
                organizer.Id,
                true
            );

        speaker.Email =
            'speaker@carmignac.com';

        update speaker;


        // Event valide
        Event__c ev =
            BooklyDataFactory.createEvent();

        ev.ScheduleID__c = 'E001';
        ev.NoAutomations__c = true;

        insert ev;


        // Strategy trouvée directement via Code__c pour les codes mappés
        Strategy__c mappedStrategy =
            BooklyDataFactory.createStrategy(
                'GLMACRO'
            );

        mappedStrategy.Code__c =
            'GLMACRO';

        update mappedStrategy;


        // Strategy utilisée via Product__c pour les codes hors mapping
        Strategy__c productStrategy =
            BooklyDataFactory.createStrategy(
                'MLD'
            );

        productStrategy.Code__c =
            'MLD';

        update productStrategy;


        // Produit lié à une strategy pour les codes hors mapping
        Product__c product =
            new Product__c(
                Name = 'MLD',
                FundStrategy__c = productStrategy.Id
            );

        insert product;
    }


    // Vérifie insertion speaker + strategy via mapping GLMA -> GLMACRO
    @IsTest
    static void testInsertWithSpeakerAndMappedStrategy() {

        String csv =
            'tech_id_speaker_schedule__c;Schedule_Key_Event__c;Start_Date_Time__c;End_Date_Time__c;Name;Thematic__c\r\n' +
            'SSP_001;E001;2026/01/01 09:00;2026/01/01 10:00;speaker@carmignac.com;GLMA';

        Test.startTest();

        ScheduleSspBatch.testCsvContent =
            csv;

        Database.executeBatch(
            new ScheduleSspBatch(),
            1
        );

        Test.stopTest();


        // Vérifie le SSP créé
        List<sessionSpeakerProduct__c> ssps = [
            SELECT Id,
                   scheduleId__c,
                   SpeakerContact__c,
                   Strategy__c,
                   presentationStatus__c
            FROM sessionSpeakerProduct__c
            WHERE scheduleId__c LIKE 'SSP_001%'
        ];

        System.assertEquals(
            1,
            ssps.size(),
            'Un SSP doit être inséré'
        );

        System.assertNotEquals(
            null,
            ssps[0].SpeakerContact__c
        );

        System.assertNotEquals(
            null,
            ssps[0].Strategy__c
        );

        System.assertEquals(
            'required',
            ssps[0].presentationStatus__c
        );
    }


    // Vérifie insertion via Product__c pour un code hors mapping
    @IsTest
    static void testInsertWithProductStrategy() {

        String csv =
            'tech_id_speaker_schedule__c;Schedule_Key_Event__c;Start_Date_Time__c;End_Date_Time__c;Name;Thematic__c\r\n' +
            'SSP_002;E001;2026/01/01 09:00;2026/01/01 10:00;speaker@carmignac.com;MLD';

        Test.startTest();

        ScheduleSspBatch.testCsvContent =
            csv;

        Database.executeBatch(
            new ScheduleSspBatch(),
            1
        );

        Test.stopTest();


        // Vérifie le SSP créé via Product__c.FundStrategy__c
        List<sessionSpeakerProduct__c> ssps = [
            SELECT Id,
                   scheduleId__c,
                   SpeakerContact__c,
                   Strategy__c,
                   presentationStatus__c
            FROM sessionSpeakerProduct__c
            WHERE scheduleId__c LIKE 'SSP_002%'
        ];

        System.assertEquals(
            1,
            ssps.size(),
            'Un SSP doit être inséré'
        );

        System.assertNotEquals(
            null,
            ssps[0].SpeakerContact__c
        );

        System.assertNotEquals(
            null,
            ssps[0].Strategy__c
        );

        System.assertEquals(
            'required',
            ssps[0].presentationStatus__c
        );
    }


    // Vérifie insertion sans strategy métier
    @IsTest
    static void testInsertWithoutStrategy() {

        String csv =
            'tech_id_speaker_schedule__c;Schedule_Key_Event__c;Start_Date_Time__c;End_Date_Time__c;Name;Thematic__c\r\n' +
            'SSP_003;E001;2026/01/01 09:00;2026/01/01 10:00;speaker@carmignac.com;NOTH';

        Test.startTest();

        ScheduleSspBatch.testCsvContent =
            csv;

        Database.executeBatch(
            new ScheduleSspBatch(),
            1
        );

        Test.stopTest();


        // Vérifie SSP sans strategy
        List<sessionSpeakerProduct__c> ssps = [
            SELECT Id,
                   scheduleId__c,
                   SpeakerContact__c,
                   Strategy__c,
                   presentationStatus__c
            FROM sessionSpeakerProduct__c
            WHERE scheduleId__c = 'SSP_003'
        ];

        System.assertEquals(
            1,
            ssps.size(),
            'Un SSP sans strategy doit être inséré'
        );

        System.assertNotEquals(
            null,
            ssps[0].SpeakerContact__c
        );

        System.assertEquals(
            null,
            ssps[0].Strategy__c
        );

        System.assertEquals(
            'required',
            ssps[0].presentationStatus__c
        );
    }


    // Vérifie erreur strategy inconnue
    @IsTest
    static void testStrategyNotFound() {

        String csv =
            'tech_id_speaker_schedule__c;Schedule_Key_Event__c;Start_Date_Time__c;End_Date_Time__c;Name;Thematic__c\r\n' +
            'SSP_004;E001;2026/01/01 09:00;2026/01/01 10:00;speaker@carmignac.com;UNKNOWN_PRODUCT';

        Test.startTest();

        ScheduleSspBatch.testCsvContent =
            csv;

        Database.executeBatch(
            new ScheduleSspBatch(),
            1
        );

        Test.stopTest();


        // Aucun SSP inséré
        Integer countSsp = [
            SELECT COUNT()
            FROM sessionSpeakerProduct__c
            WHERE scheduleId__c LIKE 'SSP_004%'
        ];

        System.assertEquals(
            0,
            countSsp
        );
    }


    // Vérifie insertion sans speaker métier
    @IsTest
    static void testInsertWithoutSpeaker() {

        String csv =
            'tech_id_speaker_schedule__c;Schedule_Key_Event__c;Start_Date_Time__c;End_Date_Time__c;Name;Thematic__c\r\n' +
            'SSP_005;E001;2026/01/01 09:00;2026/01/01 10:00;nospeaker@carmignac.com;GLMA';

        Test.startTest();

        ScheduleSspBatch.testCsvContent =
            csv;

        Database.executeBatch(
            new ScheduleSspBatch(),
            1
        );

        Test.stopTest();


        // Vérifie SSP sans speaker
        List<sessionSpeakerProduct__c> ssps = [
            SELECT Id,
                   scheduleId__c,
                   SpeakerContact__c,
                   Strategy__c,
                   presentationStatus__c
            FROM sessionSpeakerProduct__c
            WHERE scheduleId__c LIKE 'SSP_005%'
        ];

        System.assertEquals(
            1,
            ssps.size(),
            'Un SSP sans speaker doit être inséré'
        );

        System.assertEquals(
            null,
            ssps[0].SpeakerContact__c
        );

        System.assertNotEquals(
            null,
            ssps[0].Strategy__c
        );
    }
}