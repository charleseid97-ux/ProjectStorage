@IsTest
public class SessionSpeakerProduct_InsertFromJsonTest {

    // Couvre input null.
    @IsTest
    static void testExecuteNullInputs() {
        Test.startTest();
        List<SessionSpeakerProduct_InsertFromJson.ResultWrapper> res =
            SessionSpeakerProduct_InsertFromJson.execute(null);
        Test.stopTest();

        System.assertEquals(0, res.size());
    }

    // Couvre input invalide.
    @IsTest
    static void testExecuteInvalidInput() {
        SessionSpeakerProduct_InsertFromJson.InputWrapper input =
            new SessionSpeakerProduct_InsertFromJson.InputWrapper();

        Test.startTest();
        List<SessionSpeakerProduct_InsertFromJson.ResultWrapper> res =
            SessionSpeakerProduct_InsertFromJson.execute(
                new List<SessionSpeakerProduct_InsertFromJson.InputWrapper>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(0, res[0].insertedCount);
    }

    // Couvre insertion SSP depuis JSON.
    @IsTest
    static void testExecuteInsertSuccess() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        List<Object> payload = new List<Object>{
            new Map<String, Object>{
                'speakerContact__c' => String.valueOf(((Contact) data.get('SpeakerTop1')).Id),
                'strategy__c' => String.valueOf(((Strategy__c) data.get('Strategy1')).Id),
                'Language__c' => 'Italian',
                'speakerLanguage__c' => 'English',
                'startTime__c' => '09:00:00.000Z',
                'endTime__c' => '10:00:00.000Z'
            }
        };

        SessionSpeakerProduct_InsertFromJson.InputWrapper input =
            new SessionSpeakerProduct_InsertFromJson.InputWrapper();
        input.sessionId = evt.Id;
        input.json = JSON.serialize(payload);

        Test.startTest();
        List<SessionSpeakerProduct_InsertFromJson.ResultWrapper> res =
            SessionSpeakerProduct_InsertFromJson.execute(
                new List<SessionSpeakerProduct_InsertFromJson.InputWrapper>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, res[0].insertedCount);
        System.assertEquals(null, res[0].errorMessage);
    }

    // Couvre payload vide avec update Event.
    @IsTest
    static void testExecuteEmptyPayload() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        SessionSpeakerProduct_InsertFromJson.InputWrapper input =
            new SessionSpeakerProduct_InsertFromJson.InputWrapper();
        input.sessionId = evt.Id;
        input.json = '[]';

        Test.startTest();
        List<SessionSpeakerProduct_InsertFromJson.ResultWrapper> res =
            SessionSpeakerProduct_InsertFromJson.execute(
                new List<SessionSpeakerProduct_InsertFromJson.InputWrapper>{ input }
            );
        Test.stopTest();

        System.assertEquals(0, res[0].insertedCount);
        System.assertEquals(null, res[0].errorMessage);
    }

    // Couvre JSON invalide.
    @IsTest
    static void testExecuteInvalidJson() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        SessionSpeakerProduct_InsertFromJson.InputWrapper input =
            new SessionSpeakerProduct_InsertFromJson.InputWrapper();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        input.sessionId = evt.Id;
        input.json = 'invalid-json';

        Test.startTest();
        List<SessionSpeakerProduct_InsertFromJson.ResultWrapper> res =
            SessionSpeakerProduct_InsertFromJson.execute(
                new List<SessionSpeakerProduct_InsertFromJson.InputWrapper>{ input }
            );
        Test.stopTest();

        System.assertNotEquals(null, res[0].errorMessage);
    }
}