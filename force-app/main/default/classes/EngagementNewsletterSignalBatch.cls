/** ──────────────────────────────────────
 * @description Newsletter source of the Engagement Signals: product clicks (Digital_Interaction_Details__c, type Click)
 *              whose Newsletter also has an Open become NEWSLETTER_CLICK signals. Reads the configured LookbackDays__c window, or the last windowDays days
 *              on a partial refresh, and reconciles only after a full run.
 * @author Achraf El Hitary
 * @testClass EngagementSignalIngestionTest
 * @coverage 96%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
public with sharing class EngagementNewsletterSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SOURCE_TYPE = 'NEWSLETTER_CLICK';
    private final String runId;
    private final Integer windowDays;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();
    private Map<String, Id> strategyByFundName;

    // Creates a Newsletter source batch with a generated reconciliation run id.
    public EngagementNewsletterSignalBatch() {
        this(EngagementSignalRefreshService.createRunId(), null);
    }

    // Creates a Newsletter source batch sharing the supplied refresh run id; windowDays limits it to the last N days (partial refresh, no reconciliation), null for the configured LookbackDays__c window.
    public EngagementNewsletterSignalBatch(String runId, Integer windowDays) {
        this.runId = runId;
        this.windowDays = windowDays;
    }

    // Selects Newsletter product clicks from the configured 180-day scoring window, or the partial refresh window.
    public Database.QueryLocator start(Database.BatchableContext context) {
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null ? 180 : rule.LookbackDays__c.intValue();
        if (windowDays != null) lookbackDays = Math.min(windowDays, lookbackDays);
        Datetime cutoff = System.now().addDays(-lookbackDays);
        return Database.getQueryLocator([SELECT Id, Digital_Interaction__c, Details_Date__c, FundName__c, Digital_Interaction__r.Contact_lu__c
                                         FROM Digital_Interaction_Details__c
                                         WHERE Details_Date__c >= :cutoff
                                         AND Type__c = 'Click'
                                         AND Digital_Interaction__r.Engagement_Type__c = 'Newsletter'
                                         AND FundName__c != null]);
    }

    // Keeps only product clicks whose parent Newsletter also contains an Open event.
    public void execute(Database.BatchableContext context, List<Digital_Interaction_Details__c> scope) {
        ensureFundStrategyMap();
        Set<Id> parentIds = new Set<Id>();
        for (Digital_Interaction_Details__c detail : scope) {
            parentIds.add(detail.Digital_Interaction__c);
        }

        Set<Id> parentsWithOpen = loadParentsWithOpen(parentIds);
        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();
        for (Digital_Interaction_Details__c detail : scope) {
            if (!parentsWithOpen.contains(detail.Digital_Interaction__c)) continue;

            Id contactId = detail.Digital_Interaction__r.Contact_lu__c;
            Id strategyId = EngagementFundStrategyResolver.resolveFundName(detail.FundName__c, strategyByFundName);

            trackResolutionIssues(detail.Id, contactId, strategyId);
            Engagement_Signal__c signal = EngagementSignalService.buildSignal(contactId, strategyId, 'Digital_Interaction_Details__c', detail.Id, SOURCE_TYPE, detail.Details_Date__c, null, false, runId);
            if (signal != null) signals.add(signal);
        }

        EngagementSignalService.upsertSignals(signals);
    }

    // Logs unresolved source ids and, after a full run, reconciles Newsletter signals not seen in it.
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(context.getJobId(), SOURCE_TYPE, 'Digital_Interaction_Details__c', missingContactIds, 'Digital_Interaction_Details__c', missingStrategyIds, 'EngagementNewsletterSignalBatch');
        EngagementSignalRefreshService.reconcileFullRun(context.getJobId(), SOURCE_TYPE, runId, windowDays);
    }

    // Loads sibling Open events for the parent Digital Interactions in the current scope.
    private static Set<Id> loadParentsWithOpen(Set<Id> parentIds) {
        Set<Id> parentsWithOpen = new Set<Id>();
        if (parentIds.isEmpty()) return parentsWithOpen;

        for (Digital_Interaction_Details__c detail : [SELECT Digital_Interaction__c
                                                      FROM Digital_Interaction_Details__c
                                                      WHERE Digital_Interaction__c IN :parentIds
                                                      AND Type__c = 'Open']) {
            parentsWithOpen.add(detail.Digital_Interaction__c);
        }

        return parentsWithOpen;
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