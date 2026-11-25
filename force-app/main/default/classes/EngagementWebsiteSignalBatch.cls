/** ──────────────────────────────────────
 * @description Website source of the Engagement Signals: Web visits (Digital_Interaction_Details__c, type Visit) on a
 *              resolved Fund name become WEB_VISIT signals. Reads the configured LookbackDays__c window, or the last windowDays days
 *              on a partial refresh, and reconciles only after a full run.
 * @author Achraf El Hitary
 * @testClass EngagementSignalIngestionTest
 * @coverage 100%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
public with sharing class EngagementWebsiteSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SOURCE_TYPE = 'WEB_VISIT';
    private final String runId;
    private final Integer windowDays;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();
    private Map<String, Id> strategyByFundName;

    // Creates a Website source batch with a generated reconciliation run id.
    public EngagementWebsiteSignalBatch() {
        this(EngagementSignalRefreshService.createRunId(), null);
    }

    // Creates a Website source batch sharing the supplied refresh run id; windowDays limits it to the last N days (partial refresh, no reconciliation), null for the configured LookbackDays__c window.
    public EngagementWebsiteSignalBatch(String runId, Integer windowDays) {
        this.runId = runId;
        this.windowDays = windowDays;
    }

    // Selects Web visits from the configured 180-day scoring window, or the partial refresh window.
    public Database.QueryLocator start(Database.BatchableContext context) {
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null ? 180 : rule.LookbackDays__c.intValue();
        if (windowDays != null) lookbackDays = Math.min(windowDays, lookbackDays);
        Decimal minTimeSpent = rule == null ? 240 : rule.MinTimeSpentSeconds__c;
        Datetime cutoff = System.now().addDays(-lookbackDays);
        return Database.getQueryLocator([SELECT Id, Details_Date__c, FundName__c, Time_Spent__c, Digital_Interaction__r.Contact_lu__c
                                         FROM Digital_Interaction_Details__c
                                         WHERE Details_Date__c >= :cutoff
                                         AND Type__c = 'Visit'
                                         AND Digital_Interaction__r.Engagement_Type__c = 'Web'
                                         AND FundName__c != null
                                         AND Digital_Interaction__r.Time_Spent__c >= :minTimeSpent]);
    }

    // Resolves Contact and Strategy then upserts eligible Website engagement signals.
    public void execute(Database.BatchableContext context, List<Digital_Interaction_Details__c> scope) {
        ensureFundStrategyMap();
        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();

        for (Digital_Interaction_Details__c detail : scope) {
            Id contactId = detail.Digital_Interaction__r.Contact_lu__c;
            Id strategyId = EngagementFundStrategyResolver.resolveFundName(detail.FundName__c, strategyByFundName);

            trackResolutionIssues(detail.Id, contactId, strategyId);
            Engagement_Signal__c signal = EngagementSignalService.buildSignal(contactId, strategyId, 'Digital_Interaction_Details__c', detail.Id, SOURCE_TYPE, detail.Details_Date__c, detail.Time_Spent__c, false, runId);
            if (signal != null) signals.add(signal);
        }

        EngagementSignalService.upsertSignals(signals);
    }

    // Logs unresolved source ids and, after a full run, reconciles Website signals not seen in it.
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(context.getJobId(), SOURCE_TYPE, 'Digital_Interaction_Details__c', missingContactIds, 'Digital_Interaction_Details__c', missingStrategyIds, 'EngagementWebsiteSignalBatch');
        EngagementSignalRefreshService.reconcileFullRun(context.getJobId(), SOURCE_TYPE, runId, windowDays);
    }

    // Loads the strict FundName -> legacy Strategy mapping once per stateful batch.
    private void ensureFundStrategyMap() {
        if (strategyByFundName == null) strategyByFundName = EngagementFundStrategyResolver.loadStrategyByFundName();
    }

    // Tracks source records that cannot produce a Contact x Strategy signal.
    private void trackResolutionIssues(Id sourceId, Id contactId, Id strategyId) {
        if (contactId == null) missingContactIds.add(sourceId);
        if (strategyId == null) missingStrategyIds.add(sourceId);
    }
}