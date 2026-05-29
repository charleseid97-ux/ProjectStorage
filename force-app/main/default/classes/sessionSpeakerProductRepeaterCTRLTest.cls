@IsTest
public class sessionSpeakerProductRepeaterCTRLTest {

    // Crée les données communes pour les tests repeater.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Strategy__c strategy1 = BooklyDataFactory.createStrategy('Strategy1');
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);
            Event__c evt = BooklyDataFactory.createEvent(company1.Id, organizer.Id);

            SessionSpeakerProduct__c ssp = BooklyDataFactory.createSessionSpeakerProduct(
                evt.Id,
                speakerTop1.Id,
                strategy1.Id
            );

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('Strategy1', strategy1);
            data.put('SpeakerTop1', speakerTop1);
            data.put('Event1', evt);
            data.put('SSP1', ssp);
        }

        return data;
    }

    // Couvre getDefaultSpeakerForEvent avec parentEventId vide.
    @IsTest
    static void testGetDefaultSpeakerForEventBlank() {
        Test.startTest();
        String result = sessionSpeakerProductRepeaterCTRL.getDefaultSpeakerForEvent(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    // Couvre getDefaultSpeakerForEvent avec SSP existant.
    @IsTest
    static void testGetDefaultSpeakerForEventWithData() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');
        Contact speakerTop1 = (Contact) data.get('SpeakerTop1');

        Test.startTest();
        String result = sessionSpeakerProductRepeaterCTRL.getDefaultSpeakerForEvent(String.valueOf(evt.Id));
        Test.stopTest();

        System.assertEquals(String.valueOf(speakerTop1.Id), result);
    }

    // Couvre getEventCategory avec parentEventId vide.
    @IsTest
    static void testGetEventCategoryBlank() {
        Test.startTest();
        String result = sessionSpeakerProductRepeaterCTRL.getEventCategory('');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    // Couvre getEventCategory avec Event existant.
    @IsTest
    static void testGetEventCategoryWithData() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Test.startTest();
        String result = sessionSpeakerProductRepeaterCTRL.getEventCategory(String.valueOf(evt.Id));
        Test.stopTest();

        System.assertEquals('Event conference', result);
    }

    // Couvre languageOptions.
    @IsTest
    static void testLanguageOptions() {
        Test.startTest();
        List<sessionSpeakerProductRepeaterCTRL.PickOpt> result =
            sessionSpeakerProductRepeaterCTRL.languageOptions();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // Couvre getProducts même si aucun Product__c valide n'existe.
    @IsTest
    static void testGetProducts() {
        setupData();

        Test.startTest();
        List<sessionSpeakerProductRepeaterCTRL.PickOpt> result =
            sessionSpeakerProductRepeaterCTRL.getProducts();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }
}