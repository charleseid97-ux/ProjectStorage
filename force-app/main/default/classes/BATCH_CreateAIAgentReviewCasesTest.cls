@IsTest
private class BATCH_CreateAIAgentReviewCasesTest {

    /*
     * Verifies that the batch creates an Agent Review Case for an eligible
     * AI Agent and correctly links the Case to the agent.
     */
    @IsTest
    static void testCreateReviewCase() {
        AI_Agent__c agent = new AI_Agent__c(
            Name = 'Test AI Agent',
            AgentCreationDate__c = Date.today().addMonths(-24),
            ReviewFrequencyMonths__c = 24
        );
        insert agent;

        Test.startTest();

        Database.executeBatch(
            new BATCH_CreateAIAgentReviewCases(),
            200
        );

        Test.stopTest();

        List<Case> reviewCases = [
            SELECT Id,
                   RecordType.DeveloperName,
                   AI_Agent_Request_Type__c,
                   AgentStatus__c,
                   AIAgentRequest__c
            FROM Case
            WHERE AIAgentRequest__c = :agent.Id
            AND AI_Agent_Request_Type__c = 'Agent Review'
        ];

        System.assertEquals(
            1,
            reviewCases.size(),
            'One Agent Review Case should be created.'
        );

        Case reviewCase = reviewCases[0];

        System.assertEquals(
            'AIAgentGovernance',
            reviewCase.RecordType.DeveloperName
        );

        System.assertEquals(
            'Submitted',
            reviewCase.AgentStatus__c
        );

        System.assertEquals(
            agent.Id,
            reviewCase.AIAgentRequest__c
        );
    }

    /*
     * Verifies that the batch does not create another review Case when
     * the AI Agent already has an open Agent Review Case.
     */
    @IsTest
    static void testDoesNotCreateDuplicateOpenReview() {
        AI_Agent__c agent = new AI_Agent__c(
            Name = 'Test AI Agent Duplicate',
            AgentCreationDate__c = Date.today().addMonths(-24),
            ReviewFrequencyMonths__c = 24
        );
        insert agent;

        Id recordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('AIAgentGovernance')
            .getRecordTypeId();

        insert new Case(
            RecordTypeId = recordTypeId,
            AI_Agent_Request_Type__c = 'Agent Review',
            AgentStatus__c = 'Submitted',
            AIAgentRequest__c = agent.Id
        );

        Test.startTest();

        Database.executeBatch(
            new BATCH_CreateAIAgentReviewCases(),
            200
        );

        Test.stopTest();

        Integer reviewCaseCount = [
            SELECT COUNT()
            FROM Case
            WHERE AIAgentRequest__c = :agent.Id
            AND AI_Agent_Request_Type__c = 'Agent Review'
            AND IsClosed = false
        ];

        System.assertEquals(
            1,
            reviewCaseCount,
            'The batch must not create a duplicate open review Case.'
        );
    }
}