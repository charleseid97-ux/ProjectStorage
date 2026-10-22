public with sharing class EngagementSignalReconciliationBatch implements Database.Batchable<SObject> {

    private final String sourceType;
    private final String runId;

    /**
     * Creates a reconciliation batch for one source after a full source scan.
     */
    public EngagementSignalReconciliationBatch(String sourceType, String runId) {
        this.sourceType = sourceType;
        this.runId = runId;
    }

    /**
     * Selects active signals for the source that were not seen by the current full run.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                   IsActive__c,
                   LastSeenRunId__c,
                   ObsoleteReason__c
            FROM Engagement_Signal__c
            WHERE SourceType__c = :sourceType
            AND IsActive__c = true
            AND (LastSeenRunId__c = null OR LastSeenRunId__c != :runId)
        ]);
    }

    /**
     * Deactivates signals that are no longer produced by the current rule set.
     */
    public void execute(Database.BatchableContext context, List<Engagement_Signal__c> scope) {
        for (Engagement_Signal__c signal : scope) {
            signal.IsActive__c = false;
            signal.ObsoleteReason__c = 'Not eligible in reconciliation run ' + runId;
        }

        if (!scope.isEmpty()) {
            update scope;
        }
    }

    /**
     * No chained processing is performed by the generic reconciliation batch.
     */
    public void finish(Database.BatchableContext context) {
        // Source orchestrators may chain the next source or scoring step externally.
    }
}
