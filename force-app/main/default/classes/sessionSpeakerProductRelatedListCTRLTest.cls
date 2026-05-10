@IsTest
public class sessionSpeakerProductRelatedListCTRLTest {

    // Crée les données communes pour les tests related list.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Strategy__c strategy1 = BooklyDataFactory.createStrategy('Strategy1');
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);
            Event__c evt = BooklyDataFactory.createEvent(company1.Id, organizer.Id);

            speakerTop1.SpeakerAssistant__c = organizer.Id;
            update speakerTop1;

            SessionSpeakerProduct__c ssp = new SessionSpeakerProduct__c(
                Session__c = evt.Id,
                speakerContact__c = speakerTop1.Id,
                strategy__c = strategy1.Id,
                Language__c = 'Italian',
                speakerLanguage__c = 'English',
                startTime__c = Time.newInstance(9, 0, 0, 0),
                endTime__c = Time.newInstance(10, 0, 0, 0),
                Date__c = Date.today()
            );
            insert ssp;

            EventSpeakerApprovals__c approval = new EventSpeakerApprovals__c(
                Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(speakerTop1.Id),
                Event__c = evt.Id,
                Speaker__c = speakerTop1.Id,
                ApproverUser__c = organizer.Id,
                Status__c = 'Submitted',
                approvalType__c = 'Auto'
            );
            insert approval;

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('Strategy1', strategy1);
            data.put('SpeakerTop1', speakerTop1);
            data.put('Event1', evt);
            data.put('SSP1', ssp);
            data.put('Approval1', approval);
        }

        return data;
    }

    // Couvre getByEvent avec eventId null.
    @IsTest
    static void testGetByEventNull() {
        Test.startTest();
        List<sessionSpeakerProductRelatedListCTRL.SpeakerBlock> result =
            sessionSpeakerProductRelatedListCTRL.getByEvent(null);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    // Couvre getByEvent et getBySession avec données groupées.
    @IsTest
    static void testGetByEventWithRows() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Test.startTest();
        List<sessionSpeakerProductRelatedListCTRL.SpeakerBlock> result =
            sessionSpeakerProductRelatedListCTRL.getByEvent(evt.Id);

        List<sessionSpeakerProductRelatedListCTRL.SpeakerBlock> bySession =
            sessionSpeakerProductRelatedListCTRL.getBySession(evt.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(1, result[0].productCount);
        System.assertEquals('09:00', result[0].startTime);
        System.assertEquals('10:00', result[0].endTime);
        System.assertEquals(1, bySession.size());
    }

    // Couvre getRepeaterInputByEvent avec eventId null.
    @IsTest
    static void testGetRepeaterInputByEventNull() {
        Test.startTest();
        String jsonResult = sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent(null);
        Test.stopTest();

        System.assertEquals('[]', jsonResult);
    }

    // Couvre getRepeaterInputByEvent avec données existantes.
    @IsTest
    static void testGetRepeaterInputByEventWithRows() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Test.startTest();
        String jsonResult = sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent(evt.Id);
        Test.stopTest();

        System.assert(jsonResult.contains('speakerContact__c'));
        System.assert(jsonResult.contains('strategy__c'));
    }

    // Couvre saveFromRepeaterJson avec insertion et suppression.
    @IsTest
    static void testSaveFromRepeaterJsonInsertAndDelete() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = (Event__c) data.get('Event1');
            Contact speakerTop1 = (Contact) data.get('SpeakerTop1');
            Strategy__c strategy1 = (Strategy__c) data.get('Strategy1');

            List<Object> payload = new List<Object>{
                new Map<String, Object>{
                    'speakerContact__c' => String.valueOf(speakerTop1.Id),
                    'strategy__c' => String.valueOf(strategy1.Id),
                    'Language__c' => 'French',
                    'speakerLanguage__c' => 'English',
                    'startTime__c' => '11:00:00.000Z',
                    'endTime__c' => '12:00:00.000Z',
                    'Date__c' => String.valueOf(Date.today().addDays(1))
                }
            };

            Test.startTest();
            Integer impacted = sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson(
                evt.Id,
                JSON.serialize(payload)
            );
            Test.stopTest();

            System.assert(impacted > 0);
        }
    }

    // Couvre saveFromRepeaterJson avec eventId null.
    @IsTest
    static void testSaveFromRepeaterJsonMissingEvent() {
        try {
            Test.startTest();
            sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson(null, '[]');
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre saveFromRepeaterJson avec JSON invalide.
    @IsTest
    static void testSaveFromRepeaterJsonInvalidJson() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        try {
            Test.startTest();
            sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson(evt.Id, 'invalid-json');
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre saveFromRepeaterJson avec speaker manquant.
    @IsTest
    static void testSaveFromRepeaterJsonMissingSpeaker() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        List<Object> payload = new List<Object>{
            new Map<String, Object>{
                'Language__c' => 'French'
            }
        };

        try {
            Test.startTest();
            sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson(
                evt.Id,
                JSON.serialize(payload)
            );
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre updateSpeakerSlot avec succès.
    @IsTest
    static void testUpdateSpeakerSlotSuccess() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');
        Contact speakerTop1 = (Contact) data.get('SpeakerTop1');

        Test.startTest();
        sessionSpeakerProductRelatedListCTRL.updateSpeakerSlot(
            evt.Id,
            speakerTop1.Id,
            '13:00',
            '14:00'
        );
        Test.stopTest();

        EventSpeakerApprovals__c approval = [
            SELECT start__c, end__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :evt.Id
            AND Speaker__c = :speakerTop1.Id
            LIMIT 1
        ];

        System.assertEquals(Time.newInstance(13, 0, 0, 0), approval.start__c);
        System.assertEquals(Time.newInstance(14, 0, 0, 0), approval.end__c);
    }

    // Couvre updateSpeakerSlot avec end <= start.
    @IsTest
    static void testUpdateSpeakerSlotInvalidRange() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');
        Contact speakerTop1 = (Contact) data.get('SpeakerTop1');

        try {
            Test.startTest();
            sessionSpeakerProductRelatedListCTRL.updateSpeakerSlot(
                evt.Id,
                speakerTop1.Id,
                '14:00',
                '13:00'
            );
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre updateSpeakerSlot avec paramètres obligatoires manquants.
    @IsTest
    static void testUpdateSpeakerSlotMissingParams() {
        try {
            Test.startTest();
            sessionSpeakerProductRelatedListCTRL.updateSpeakerSlot(null, null, '09:00', '10:00');
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre updateSpeakerSlot sans approval trouvée.
    @IsTest
    static void testUpdateSpeakerSlotNoApproval() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Contact otherSpeaker = BooklyDataFactory.createSpeakerContact(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id,
            false
        );

        try {
            Test.startTest();
            sessionSpeakerProductRelatedListCTRL.updateSpeakerSlot(
                evt.Id,
                otherSpeaker.Id,
                '09:00',
                '10:00'
            );
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre canUserEditEvent avec eventId null et eventId valide.
    @IsTest
    static void testCanUserEditEvent() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Test.startTest();
        Boolean nullResult = sessionSpeakerProductRelatedListCTRL.canUserEditEvent(null);
        Boolean validResult = sessionSpeakerProductRelatedListCTRL.canUserEditEvent(evt.Id);
        Test.stopTest();

        System.assertEquals(false, nullResult);
        System.assertNotEquals(null, validResult);
    }
}