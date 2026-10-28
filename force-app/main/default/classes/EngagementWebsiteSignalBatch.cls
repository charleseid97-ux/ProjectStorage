public with sharing class EngagementWebsiteSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SOURCE_TYPE = 'WEB_VISIT';
    private final String runId;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();
    private Map<String, Id> strategyByFundName;

    /**
     * Creates a Website source batch with a generated reconciliation run id.
     */
    public EngagementWebsiteSignalBatch() {
        this(EngagementSignalRefreshService.createRunId());
    }

    /**
     * Creates a Website source batch sharing the supplied full refresh run id.
     */
    public EngagementWebsiteSignalBatch(String runId) {
        this.runId = runId;
    }

    /**
     * Selects Web visits from the configured 180-day scoring window.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null
            ? 180
            : rule.LookbackDays__c.intValue();
        Decimal minTimeSpent = rule == null ? 240 : rule.MinTimeSpentSeconds__c;
        Datetime cutoff = System.now().addDays(-lookbackDays);
        return Database.getQueryLocator([
            SELECT Id,
                   Details_Date__c,
                   FundName__c,
                   Time_Spent__c,
                   Digital_Interaction__r.Contact_lu__c
            FROM Digital_Interaction_Details__c
            WHERE Details_Date__c >= :cutoff
            AND Type__c = 'Visit'
            AND Digital_Interaction__r.Engagement_Type__c = 'Web'
            AND FundName__c != null
            AND Time_Spent__c >= :minTimeSpent
        ]);
    }

    /**
     * Resolves Contact and Strategy then upserts eligible Website engagement signals.
     */
    public void execute(
        Database.BatchableContext context,
        List<Digital_Interaction_Details__c> scope
    ) {
        ensureFundStrategyMap();
        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();

        for (Digital_Interaction_Details__c detail : scope) {
            Id contactId = detail.Digital_Interaction__r.Contact_lu__c;
            Id strategyId = EngagementFundStrategyResolver.resolveFundName(
                detail.FundName__c,
                strategyByFundName
            );

            trackResolutionIssues(detail.Id, contactId, strategyId);
            Engagement_Signal__c signal = EngagementSignalService.buildSignal(
                contactId,
                strategyId,
                'Digital_Interaction_Details__c',
                detail.Id,
                SOURCE_TYPE,
                detail.Details_Date__c,
                detail.Time_Spent__c,
                false,
                runId
            );
            if (signal != null) {
                signals.add(signal);
            }
        }

        EngagementSignalService.upsertSignals(signals);
    }

    /**
     * Logs unresolved source ids and reconciles Website signals not seen in this full run.
     */
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(
            context.getJobId(),
            SOURCE_TYPE,
            'Digital_Interaction_Details__c',
            missingContactIds,
            'Digital_Interaction_Details__c',
            missingStrategyIds,
            'EngagementWebsiteSignalBatch'
        );
        if (EngagementSignalRefreshService.isBatchSuccessful(context.getJobId())) {
            Database.executeBatch(new EngagementSignalReconciliationBatch(SOURCE_TYPE, runId), 200);
        }
    }

    /**
     * Loads the strict FundName -> legacy Strategy mapping once per stateful batch.
     */
    private void ensureFundStrategyMap() {
        if (strategyByFundName == null) {
            strategyByFundName = EngagementFundStrategyResolver.loadStrategyByFundName();
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
