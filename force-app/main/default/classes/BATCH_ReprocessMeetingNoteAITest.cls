@IsTest
private class BATCH_ReprocessMeetingNoteAITest {

    /**
     * @description Creates a test Meeting Note.
     */
    private static Meeting_Note__c createMeetingNote() {
        Account account = new Account(
            Name = 'AI Batch Test Account'
        );

        insert account;

        Meeting_Note__c meetingNote = new Meeting_Note__c(
            Name = 'AI Batch Test',
            Company__c = account.Id,
            Date__c = Date.today(),
            SalesPresentation__c = true,
            RelationshipManagement__c = false,
            Raw_Note__c = '<p>Client discussed CI.</p>',
            Note__c =
                '<h2>Client Sentiment & Feedback</h2>' +
                '<ul><li>None.</li></ul>'
        );

        insert meetingNote;

        return meetingNote;
    }

    /**
     * @description Verifies the batch updates the AI summary.
     */
    @IsTest
    static void testBatchExecution() {
        Meeting_Note__c meetingNote = createMeetingNote();

        Test.startTest();

        Database.executeBatch(
            new BATCH_ReprocessMeetingNoteAI(
                new List<Id>{ meetingNote.Id }
            ),
            1
        );

        Test.stopTest();

        Meeting_Note__c updatedMeetingNote = [
            SELECT Note__c
            FROM Meeting_Note__c
            WHERE Id = :meetingNote.Id
        ];

        System.assertEquals(
            '<h2>Test AI Summary</h2>',
            updatedMeetingNote.Note__c
        );
    }

    /**
     * @description Tests {"result":[...]} output.
     */
    @IsTest
    static void testResultFormat() {
        String json =
            '{"result":[' +
                '{' +
                    '"StrategyId":"a3qaT0000024caFQAQ",' +
                    '"ProductName":"CI",' +
                    '"Rating":4,' +
                    '"Why":"Interested"' +
                '}' +
            ']}';

        List<Object> results =
            BATCH_ReprocessMeetingNoteAI.extractInterestResults(json);

        System.assertEquals(1, results.size());

        Map<String, Object> interest =
            (Map<String, Object>) results[0];

        System.assertEquals(
            'CI',
            interest.get('ProductName')
        );
    }

    /**
     * @description Tests {"response":[...]} output.
     */
    @IsTest
    static void testResponseFormat() {
        String json =
            '{"criteria":"test","response":[' +
                '{' +
                    '"StrategyId":"a3qaT0000024caIQAQ",' +
                    '"ProductName":"CSC",' +
                    '"Rating":3' +
                '}' +
            ']}';

        List<Object> results =
            BATCH_ReprocessMeetingNoteAI.extractInterestResults(json);

        System.assertEquals(1, results.size());

        Map<String, Object> interest =
            (Map<String, Object>) results[0];

        System.assertEquals(
            'CSC',
            interest.get('ProductName')
        );
    }

    /**
     * @description Tests a single JSON object.
     */
    @IsTest
    static void testSingleObjectFormat() {
        String json =
            '{' +
                '"StrategyId":"a3qaT0000024caFQAQ",' +
                '"ProductName":"CI",' +
                '"Rating":4,' +
                '"Why":"Advanced due diligence"' +
            '}';

        List<Object> results =
            BATCH_ReprocessMeetingNoteAI.extractInterestResults(json);

        System.assertEquals(1, results.size());

        Map<String, Object> interest =
            (Map<String, Object>) results[0];

        System.assertEquals(
            4,
            Integer.valueOf(
                String.valueOf(interest.get('Rating'))
            )
        );
    }

    /**
     * @description Tests a direct JSON array.
     */
    @IsTest
    static void testDirectArrayFormat() {
        String json =
            '[' +
                '{' +
                    '"StrategyId":"a3qaT0000024cadQAA",' +
                    '"ProductName":"CTS",' +
                    '"Rating":4' +
                '},' +
                '{' +
                    '"StrategyId":"a3qaT0000024caFQAQ",' +
                    '"ProductName":"CI",' +
                    '"Rating":4' +
                '}' +
            ']';

        List<Object> results =
            BATCH_ReprocessMeetingNoteAI.extractInterestResults(json);

        System.assertEquals(2, results.size());
    }

    /**
     * @description Tests an empty AI response.
     */
    @IsTest
    static void testEmptyResult() {
        List<Object> results =
            BATCH_ReprocessMeetingNoteAI.extractInterestResults(
                '{"result":[]}'
            );

        System.assertEquals(0, results.size());
    }


    /**
 * @description Covers Client Interest creation from AI output.
 */
@IsTest
static void testBuildClientInterests() {

    Meeting_Note__c meetingNote =
        createMeetingNote();

    BATCH_ReprocessMeetingNoteAI batch =
        new BATCH_ReprocessMeetingNoteAI(
            new List<Id>{
                meetingNote.Id
            }
        );

    String json =
        '{"result":[' +
            '{' +
                '"StrategyId":"a3qaT0000024caFQAQ",' +
                '"ProductName":"CI",' +
                '"Rating":4,' +
                '"Why":"Advanced due diligence"' +
            '},' +
            '{' +
                '"StrategyId":"a3qaT0000024cadQAA",' +
                '"ProductName":"CTS",' +
                '"Rating":3,' +
                '"Why":"Product discussed"' +
            '}' +
        ']}';

    List<ClientInterest__c> results =
        batch.buildClientInterests(
            meetingNote.Id,
            json
        );


}

/**
 * @description Covers invalid and incomplete AI interests.
 */
@IsTest
static void testBuildClientInterestsInvalidValues() {

    Meeting_Note__c meetingNote =
        createMeetingNote();

    BATCH_ReprocessMeetingNoteAI batch =
        new BATCH_ReprocessMeetingNoteAI(
            new List<Id>{
                meetingNote.Id
            }
        );

    String json =
        '{"result":[' +

            // Missing StrategyId
            '{' +
                '"ProductName":"CI",' +
                '"Rating":4' +
            '},' +

            // Missing ProductName
            '{' +
                '"StrategyId":"a3qaT0000024caFQAQ",' +
                '"Rating":4' +
            '},' +

            // Missing Rating
            '{' +
                '"StrategyId":"a3qaT0000024caFQAQ",' +
                '"ProductName":"CI"' +
            '}' +

        ']}';

    List<ClientInterest__c> results =
        batch.buildClientInterests(
            meetingNote.Id,
            json
        );

    System.assertEquals(
        0,
        results.size()
    );
}

/**
 * @description Covers empty AI output.
 */
@IsTest
static void testBuildClientInterestsEmpty() {

    Meeting_Note__c meetingNote =
        createMeetingNote();

    BATCH_ReprocessMeetingNoteAI batch =
        new BATCH_ReprocessMeetingNoteAI(
            new List<Id>{
                meetingNote.Id
            }
        );

    List<ClientInterest__c> results =
        batch.buildClientInterests(
            meetingNote.Id,
            null
        );

    System.assertEquals(
        0,
        results.size()
    );
}

}