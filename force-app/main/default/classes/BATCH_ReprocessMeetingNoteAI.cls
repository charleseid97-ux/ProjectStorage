/**
 * @description Reprocesses Meeting Notes through the AI Flow.
 *              Updates the generated summary and creates Client Interests.
 *              The batch must be executed with a scope size of 1.
 */
public without sharing class BATCH_ReprocessMeetingNoteAI
    implements Database.Batchable<SObject>,
               Database.Stateful,
               Database.AllowsCallouts {

    private Set<Id> meetingNoteIds;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private Integer interestsInsertedCount = 0;

    /**
     * @description Constructor receiving the Meeting Note IDs to process.
     */
    public BATCH_ReprocessMeetingNoteAI(List<Id> meetingNoteIds) {
        this.meetingNoteIds = new Set<Id>();

        if (meetingNoteIds != null) {
            this.meetingNoteIds.addAll(meetingNoteIds);
        }
    }

    /**
     * @description Loads all accessible Meeting Note fields.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (meetingNoteIds.isEmpty()) {
            return Database.getQueryLocator(
                'SELECT Id FROM Meeting_Note__c WHERE Id = NULL'
            );
        }

        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Meeting_Note__c.fields.getMap();

        List<String> fieldNames = new List<String>();

        // Load every accessible field because the Flow receives
        // the complete Meeting_Note__c record.
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDesc =
                fieldMap.get(fieldName).getDescribe();

            if (fieldDesc.isAccessible()) {
                fieldNames.add(fieldName);
            }
        }

        fieldNames.sort();

        List<String> quotedIds = new List<String>();

        for (Id meetingNoteId : meetingNoteIds) {
            quotedIds.add(
                '\'' +
                String.escapeSingleQuotes(String.valueOf(meetingNoteId)) +
                '\''
            );
        }

        String query =
            'SELECT ' +
            String.join(fieldNames, ',') +
            ' FROM Meeting_Note__c' +
            ' WHERE Id IN (' +
            String.join(quotedIds, ',') +
            ')';

        return Database.getQueryLocator(query);
    }

    /**
     * @description Processes Meeting Notes.
     *              Execute the batch with scope size = 1.
     */
    public void execute(
        Database.BatchableContext context,
        List<SObject> scope
    ) {
        for (SObject recordItem : scope) {

            Meeting_Note__c meetingNote =
                (Meeting_Note__c) recordItem;
            processedCount++;

            try {
                System.debug(
                    LoggingLevel.ERROR,
                    '=== START === ' + meetingNote.Id + ' | ' + meetingNote.Name
                );

                FlowOutputs flowOutputs = callFlow(meetingNote);

                System.debug(
                    LoggingLevel.ERROR,
                    '=== OUTPUT_CLIENT_INTERESTS ===\n' +
                    flowOutputs.interestsJson
                );

                System.debug(
                    LoggingLevel.ERROR,
                    '=== OUTPUT_SUMMARY ===\n' +
                    flowOutputs.summaryText
                );

                List<ClientInterest__c> interestsToInsert =
                    buildClientInterests(
                        meetingNote.Id,
                        flowOutputs.interestsJson
                    );

                // Flow callout is finished before DML.
                updateSummary(
                    meetingNote.Id,
                    flowOutputs.summaryText
                );

                insertClientInterests(interestsToInsert);

                successCount++;

                System.debug(
                    LoggingLevel.ERROR,
                    '=== DONE === ' + meetingNote.Id
                );

            } catch (Exception e) {
                errorCount++;

                System.debug(
                    LoggingLevel.ERROR,
                    '=== ERROR === ' +
                    meetingNote.Id +
                    ' | ' +
                    e.getTypeName() +
                    ' | ' +
                    e.getMessage() +
                    ' | Line=' +
                    e.getLineNumber()
                );
            }
        }
    }

    /**
     * @description Calls the active AI Flow.
     */
    private FlowOutputs callFlow(Meeting_Note__c meetingNote) {
        // Prompt generation cannot be executed from unit tests.
        if (Test.isRunningTest()) {
            return new FlowOutputs(
                '<h2>Test AI Summary</h2>',
                '{"result":[]}'
            );
        }

        Flow.Interview interview =
            Flow.Interview.createInterview(
                'AL_RawText_GeneratePromptsResponses',
                new Map<String, Object>{
                    'MeetingNote' => meetingNote
                }
            );

        interview.start();

        String interestsJson =
            (String) interview.getVariableValue(
                'Output_ClientInterests'
            );

        String summaryText =
            (String) interview.getVariableValue(
                'Output_Summary'
            );

        return new FlowOutputs(summaryText, interestsJson);
    }

    /**
     * @description Parses AI output and builds Client Interests.
     */
    @TestVisible
    private List<ClientInterest__c> buildClientInterests(
        Id meetingNoteId,
        String interestsJson
    ) {
        List<ClientInterest__c> interestsToInsert =
            new List<ClientInterest__c>();

        if (String.isBlank(interestsJson)) {
            return interestsToInsert;
        }

        List<Object> results = extractInterestResults(interestsJson);

        System.debug(
            LoggingLevel.ERROR,
            '=== AI_INTEREST_COUNT === ' + results.size()
        );

        Set<String> existingKeys = new Set<String>();

        // Avoid recreating an existing product/strategy interest.
        for (ClientInterest__c existingInterest : [
            SELECT Strategy__c,
                   ProductCode__c
            FROM ClientInterest__c
            WHERE MeetingNote__c = :meetingNoteId
        ]) {
            existingKeys.add(
                String.valueOf(existingInterest.Strategy__c) +
                '|' +
                String.valueOf(existingInterest.ProductCode__c)
            );
        }

        // Convert each AI result into a ClientInterest__c.
        for (Object item : results) {
            if (!(item instanceof Map<String, Object>)) {
                continue;
            }

            Map<String, Object> data =
                (Map<String, Object>) item;

            String strategyId = getStringValue(data, 'StrategyId');
            String productName = getStringValue(data, 'ProductName');
            Object ratingValue = data.get('Rating');
            String why = getStringValue(data, 'Why');

            System.debug(
                LoggingLevel.ERROR,
                '=== AI_INTEREST === ' +
                'Strategy=' + strategyId +
                ' | Product=' + productName +
                ' | Rating=' + ratingValue +
                ' | Why=' + why
            );

            if (
                String.isBlank(strategyId) ||
                String.isBlank(productName) ||
                ratingValue == null
            ) {
                continue;
            }

            String interestKey = strategyId + '|' + productName;

            if (existingKeys.contains(interestKey)) {
                System.debug(
                    LoggingLevel.ERROR,
                    '=== DUPLICATE_SKIPPED === ' + interestKey
                );

                continue;
            }

            interestsToInsert.add(
                new ClientInterest__c(
                    MeetingNote__c = meetingNoteId,
                    Strategy__c = strategyId,
                    ProductCode__c = productName,
                    Interest__c = Integer.valueOf(
                        String.valueOf(ratingValue)
                    )
                )
            );

            existingKeys.add(interestKey);
        }

        return interestsToInsert;
    }

    /**
     * @description Supports all output formats observed from Prompt Builder.
     */
    @TestVisible
    private static List<Object> extractInterestResults(
        String interestsJson
    ) {
        List<Object> results =
            new List<Object>();

        if (String.isBlank(interestsJson)) {
            return results;
        }

        Object rootObject =
            JSON.deserializeUntyped(
                interestsJson
            );

        // Format: [{...},{...}]
        if (rootObject instanceof List<Object>) {
            return (List<Object>) rootObject;
        }

        if (!(rootObject instanceof Map<String, Object>)) {
            return results;
        }

        Map<String, Object> root =
            (Map<String, Object>) rootObject;

        // Format: {"result":[...]}
        if (
            root.containsKey('result') &&
            root.get('result') instanceof List<Object>
        ) {
            return (List<Object>) root.get('result');
        }

        // Format: {"response":[...]}
        if (
            root.containsKey('response') &&
            root.get('response') instanceof List<Object>
        ) {
            return (List<Object>) root.get('response');
        }

        // Format: {"criteria":[...]}
        if (
            root.containsKey('criteria') &&
            root.get('criteria') instanceof List<Object>
        ) {
            return (List<Object>) root.get('criteria');
        }

        // Format: {"criteria":"...", "output":[...]}
        if (
            root.containsKey('output') &&
            root.get('output') instanceof List<Object>
        ) {
            return (List<Object>) root.get('output');
        }

        // Format:
        // {"StrategyId":"...", "ProductName":"...", "Rating":4}
        if (
            root.containsKey('StrategyId') &&
            root.containsKey('ProductName') &&
            root.containsKey('Rating')
        ) {
            results.add(root);
        }

        return results;
    }

    /**
     * @description Returns a String value from an untyped JSON map.
     */
    private static String getStringValue(
        Map<String, Object> data,
        String key
    ) {
        Object value = data.get(key);

        return value == null
            ? null
            : String.valueOf(value);
    }

    /**
     * @description Updates the generated AI summary.
     */
    private void updateSummary(
        Id meetingNoteId,
        String summaryText
    ) {
        if (String.isBlank(summaryText)) {
            return;
        }

        Database.SaveResult result =
            Database.update(
                new Meeting_Note__c(
                    Id = meetingNoteId,
                    Note__c = summaryText
                ),
                false
            );

        if (result.isSuccess()) {
            System.debug(
                LoggingLevel.ERROR,
                '=== SUMMARY_UPDATED === ' + meetingNoteId
            );

            return;
        }

        for (Database.Error errorItem : result.getErrors()) {
            System.debug(
                LoggingLevel.ERROR,
                '=== SUMMARY_UPDATE_ERROR === ' +
                meetingNoteId +
                ' | ' +
                errorItem.getMessage()
            );
        }
    }

    /**
     * @description Inserts generated Client Interests.
     */
    private void insertClientInterests(
        List<ClientInterest__c> interestsToInsert
    ) {
        System.debug(
            LoggingLevel.ERROR,
            '=== CLIENT_INTERESTS_TO_INSERT === ' +
            JSON.serializePretty(interestsToInsert)
        );

        if (interestsToInsert.isEmpty()) {
            System.debug(
                LoggingLevel.ERROR,
                '=== CLIENT_INTERESTS_INSERTED === 0'
            );

            return;
        }

        Database.SaveResult[] results =
            Database.insert(interestsToInsert, false);

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                interestsInsertedCount++;

                System.debug(
                    LoggingLevel.ERROR,
                    '=== CLIENT_INTEREST_INSERTED === ' +
                    results[i].getId() +
                    ' | Product=' +
                    interestsToInsert[i].ProductCode__c +
                    ' | Rating=' +
                    interestsToInsert[i].Interest__c
                );

                continue;
            }

            for (Database.Error errorItem : results[i].getErrors()) {
                System.debug(
                    LoggingLevel.ERROR,
                    '=== CLIENT_INTEREST_INSERT_ERROR === ' +
                    interestsToInsert[i].ProductCode__c +
                    ' | ' +
                    errorItem.getMessage()
                );
            }
        }
    }

    /**
     * @description Logs global batch statistics.
     */
    public void finish(Database.BatchableContext context) {
        System.debug(
            LoggingLevel.ERROR,
            '=== BATCH FINISHED ===' +
            ' | Processed=' + processedCount +
            ' | Success=' + successCount +
            ' | Errors=' + errorCount +
            ' | InterestsInserted=' + interestsInsertedCount
        );
    }

    /**
     * @description Internal Flow response wrapper.
     */
    private class FlowOutputs {
        private String summaryText;
        private String interestsJson;

        private FlowOutputs(
            String summaryText,
            String interestsJson
        ) {
            this.summaryText = summaryText;
            this.interestsJson = interestsJson;
        }
    }
}