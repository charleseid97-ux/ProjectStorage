public with sharing class EngagementSubscriptionSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SOURCE_TYPE = 'PROSPACE_SUBSCRIPTION';
    private final String runId;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();

    /**
     * Creates a Subscription source batch with a generated reconciliation run id.
     */
    public EngagementSubscriptionSignalBatch() {
        this(EngagementSignalRefreshService.createRunId());
    }

    /**
     * Creates a Subscription source batch sharing the supplied full refresh run id.
     */
    public EngagementSubscriptionSignalBatch(String runId) {
        this.runId = runId;
    }

    /**
     * Selects active Web Communications created inside the 180-day scoring window.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null
            ? 180
            : rule.LookbackDays__c.intValue();
        Datetime cutoff = System.now().addDays(-lookbackDays);
        return Database.getQueryLocator([
            SELECT Id,
                   Contact__c,
                   Fund__c,
                   Fund__r.FundStrategy__c,
                   IsActive__c,
                   CreatedDate
            FROM Web_Communication__c
            WHERE CreatedDate >= :cutoff
            AND IsActive__c = true
            AND isPublication__c = false
        ]);
    }

    /**
     * Uses the Product Catalog Fund lookup to resolve the legacy Strategy directly.
     */
    public void execute(Database.BatchableContext context, List<Web_Communication__c> scope) {
        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();
        for (Web_Communication__c subscription : scope) {
            Id contactId = subscription.Contact__c;
            Id strategyId = subscription.Fund__c == null
                ? null
                : subscription.Fund__r.FundStrategy__c;

            trackResolutionIssues(subscription.Id, contactId, strategyId);
            Engagement_Signal__c signal = EngagementSignalService.buildSignal(
                contactId,
                strategyId,
                'Web_Communication__c',
                subscription.Id,
                SOURCE_TYPE,
                subscription.CreatedDate,
                null,
                subscription.IsActive__c,
                runId
            );
            if (signal != null) {
                signals.add(signal);
            }
        }

        EngagementSignalService.upsertSignals(signals);
    }

    /**
     * Logs unresolved source ids and reconciles Subscription signals not seen in this full run.
     */
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(
            context.getJobId(),
            SOURCE_TYPE,
            'Web_Communication__c',
            missingContactIds,
            'Web_Communication__c',
            missingStrategyIds,
            'EngagementSubscriptionSignalBatch'
        );
        if (EngagementSignalRefreshService.isBatchSuccessful(context.getJobId())) {
            Database.executeBatch(new EngagementSignalReconciliationBatch(SOURCE_TYPE, runId), 200);
        }
    }

    /**
     * Tracks source records that cannot produce a Contact x Strategy signal.
     */
    private void trackResolutionIssues(Id sourceId, Id contactId, Id strategyId) {
        if (contactId == null) {
            missingContactIds.add(sourceId);
        }
        if (strategyId == null) {
            missingStrategyIds.add(sourceId);
        }
    }
}
