/** ──────────────────────────────────────
 * @description Prospace source of the Engagement Signals: active Web_Communication__c subscriptions on a Fund
 *              become PROSPACE_SUBSCRIPTION signals. Reads the configured LookbackDays__c window, or the last windowDays days
 *              on a partial refresh, and reconciles only after a full run.
 * @author Achraf El Hitary
 * @testClass EngagementSignalIngestionTest
 * @coverage 93%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
public with sharing class EngagementSubscriptionSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SOURCE_TYPE = 'PROSPACE_SUBSCRIPTION';
    private final String runId;
    private final Integer windowDays;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();

    // Creates a Subscription source batch with a generated reconciliation run id.
    public EngagementSubscriptionSignalBatch() {
        this(EngagementSignalRefreshService.createRunId(), null);
    }

    // Creates a Subscription source batch sharing the supplied refresh run id; windowDays limits it to the last N days (partial refresh, no reconciliation), null for the configured LookbackDays__c window.
    public EngagementSubscriptionSignalBatch(String runId, Integer windowDays) {
        this.runId = runId;
        this.windowDays = windowDays;
    }

    // Selects active Web Communications created inside the 180-day scoring window, or the partial refresh window.
    public Database.QueryLocator start(Database.BatchableContext context) {
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null ? 180 : rule.LookbackDays__c.intValue();
        if (windowDays != null) lookbackDays = Math.min(windowDays, lookbackDays);
        Datetime cutoff = System.now().addDays(-lookbackDays);
        return Database.getQueryLocator([SELECT Id, Contact__c, Fund__c, Fund__r.FundStrategy__c, IsActive__c, CreatedDate
                                         FROM Web_Communication__c
                                         WHERE CreatedDate >= :cutoff
                                         AND IsActive__c = true
                                         AND isPublication__c = false]);
    }

    // Uses the Product Catalog Fund lookup to resolve the legacy Strategy directly.
    public void execute(Database.BatchableContext context, List<Web_Communication__c> scope) {
        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();
        for (Web_Communication__c subscription : scope) {
            Id contactId = subscription.Contact__c;
            Id strategyId = subscription.Fund__c == null ? null : subscription.Fund__r.FundStrategy__c;

            trackResolutionIssues(subscription.Id, contactId, strategyId);
            Engagement_Signal__c signal = EngagementSignalService.buildSignal(contactId, strategyId, 'Web_Communication__c', subscription.Id, SOURCE_TYPE, subscription.CreatedDate, null, subscription.IsActive__c, runId);
            if (signal != null) signals.add(signal);
        }

        EngagementSignalService.upsertSignals(signals);
    }

    // Logs unresolved source ids and, after a full run, reconciles Subscription signals not seen in it.
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(context.getJobId(), SOURCE_TYPE, 'Web_Communication__c', missingContactIds, 'Web_Communication__c', missingStrategyIds, 'EngagementSubscriptionSignalBatch');
        EngagementSignalRefreshService.reconcileFullRun(context.getJobId(), SOURCE_TYPE, runId, windowDays);
    }

    // Tracks source records that cannot produce a Contact x Strategy signal.
    private void trackResolutionIssues(Id sourceId, Id contactId, Id strategyId) {
        if (contactId == null) missingContactIds.add(sourceId);
        if (strategyId == null) missingStrategyIds.add(sourceId);
    }
}