public with sharing class BATCH_CreateAIAgentReviewCases implements Database.Batchable<SObject>, Schedulable {

    /*
     * Selects overdue AI Agents and agents requiring a governance review
     * within the next seven days.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        Date reviewLimitDate = Date.today().addDays(7);

        return Database.getQueryLocator([
            SELECT Id, Name, NextReviewDate__c
            FROM AI_Agent__c
            WHERE NextReviewDate__c != NULL
            AND NextReviewDate__c <= :reviewLimitDate
        ]);
    }

    /*
     * Creates an Agent Review Case when the AI Agent does not already
     * have an open review Case.
     */
    public void execute(Database.BatchableContext context, List<AI_Agent__c> scope) {
        Set<Id> agentIds = new Map<Id, AI_Agent__c>(scope).keySet();
        Set<Id> agentsWithOpenReview = new Set<Id>();

        // Retrieve the AI Agent Governance Case Record Type dynamically.
        Id aiAgentGovernanceRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('AIAgentGovernance')
            .getRecordTypeId();

        // Identify AI Agents that already have an open Agent Review Case.
        for (Case reviewCase : [
            SELECT AIAgentRequest__c
            FROM Case
            WHERE AIAgentRequest__c IN :agentIds
            AND AI_Agent_Request_Type__c = 'Agent Review'
            AND IsClosed = false
        ]) {
            agentsWithOpenReview.add(reviewCase.AIAgentRequest__c);
        }

        List<Case> casesToInsert = new List<Case>();

        // Prepare a review Case only when no open review already exists.
        for (AI_Agent__c agent : scope) {
            if (!agentsWithOpenReview.contains(agent.Id)) {
                casesToInsert.add(new Case(
                    RecordTypeId = aiAgentGovernanceRecordTypeId,
                    AI_Agent_Request_Type__c = 'Agent Review',
                    AgentStatus__c = 'Submitted',
                    AIAgentRequest__c = agent.Id
                ));
            }
        }

        // Insert all new review Cases in a single DML operation.
        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;
        }
    }

    /*
     * No post-processing is required after the batch execution.
     */
    public void finish(Database.BatchableContext context) {
    }

    /*
     * Executes the batch when invoked by the Salesforce scheduler.
     */
    public void execute(SchedulableContext context) {
        Database.executeBatch(
            new BATCH_CreateAIAgentReviewCases(),
            200
        );
    }
}
