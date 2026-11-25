/** ──────────────────────────────────────
 * @description Webinar source of the Engagement Signals: Campaign Members attending a Webinar whose Event presents
 *              one Strategy become WEBINAR_ATTENDANCE signals. Reads the configured LookbackDays__c window, or the last windowDays days
 *              on a partial refresh, and reconciles only after a full run.
 * @author Achraf El Hitary
 * @testClass EngagementSignalIngestionTest
 * @coverage 97%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
public with sharing class EngagementWebinarSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SOURCE_TYPE = 'WEBINAR_ATTENDANCE';
    private final String runId;
    private final Integer windowDays;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();

    // Creates a Webinar source batch with a generated reconciliation run id.
    public EngagementWebinarSignalBatch() {
        this(EngagementSignalRefreshService.createRunId(), null);
    }

    // Creates a Webinar source batch sharing the supplied refresh run id; windowDays limits it to the last N days (partial refresh, no reconciliation), null for the configured LookbackDays__c window.
    public EngagementWebinarSignalBatch(String runId, Integer windowDays) {
        this.runId = runId;
        this.windowDays = windowDays;
    }

    // Selects Campaign Members from Webinar Campaigns whose linked Event starts in the last 180 days, or the partial refresh window.
    public Database.QueryLocator start(Database.BatchableContext context) {
        Set<Id> webinarCampaignIds = loadWebinarCampaignIds();
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null ? 180 : rule.LookbackDays__c.intValue();
        if (windowDays != null) lookbackDays = Math.min(windowDays, lookbackDays);
        Decimal minAttendanceRate = rule == null ? 80 : rule.MinAttendanceRate__c;
        Date cutoffDate = Date.today().addDays(-lookbackDays);
        return Database.getQueryLocator([SELECT Id, ContactId, CampaignId, Attendance_rate__c, Campaign.Event__c, Campaign.Event__r.StartDate__c, Campaign.Start_Date_Time__c
                                         FROM CampaignMember
                                         WHERE CampaignId IN :webinarCampaignIds
                                         AND Campaign.Event__c != null
                                         AND Campaign.Event__r.StartDate__c >= :cutoffDate
                                         AND Attendance_rate__c >= :minAttendanceRate]);
    }

    // Creates one Webinar signal only when the Event resolves to one distinct Strategy.
    public void execute(Database.BatchableContext context, List<CampaignMember> scope) {
        Set<Id> eventIds = new Set<Id>();
        for (CampaignMember member : scope) {
            eventIds.add(member.Campaign.Event__c);
        }

        Map<Id, Set<Id>> strategiesByEvent = loadStrategiesByEvent(eventIds);
        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();
        for (CampaignMember member : scope) {
            Id contactId = member.ContactId;
            Id strategyId = getUniqueStrategy(strategiesByEvent.get(member.Campaign.Event__c));

            trackResolutionIssues(member.Id, contactId, strategyId);
            Engagement_Signal__c signal = EngagementSignalService.buildSignal(contactId, strategyId, 'CampaignMember', member.Id, SOURCE_TYPE, getInteractionDate(member), member.Attendance_rate__c, false, runId);
            if (signal != null) signals.add(signal);
        }

        EngagementSignalService.upsertSignals(signals);
    }

    // Logs unresolved source ids and, after a full run, reconciles Webinar signals not seen in it.
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(context.getJobId(), SOURCE_TYPE, 'CampaignMember', missingContactIds, 'CampaignMember', missingStrategyIds, 'EngagementWebinarSignalBatch');
        EngagementSignalRefreshService.reconcileFullRun(context.getJobId(), SOURCE_TYPE, runId, windowDays);
    }

    // Identifies Webinar Campaigns from their existing Webinar Digital Interactions.
    private static Set<Id> loadWebinarCampaignIds() {
        Set<Id> campaignIds = new Set<Id>();
        for (AggregateResult result : [SELECT Campaign__c campaignId
                                       FROM Digital_Interaction__c
                                       WHERE Engagement_Type__c = 'Webinars'
                                       AND Campaign__c != null
                                       GROUP BY Campaign__c]) {
            campaignIds.add((Id) result.get('campaignId'));
        }
        return campaignIds;
    }

    // Loads the distinct legacy Strategies presented by each Event through SSP records.
    private static Map<Id, Set<Id>> loadStrategiesByEvent(Set<Id> eventIds) {
        Map<Id, Set<Id>> strategiesByEvent = new Map<Id, Set<Id>>();
        if (eventIds.isEmpty()) return strategiesByEvent;

        for (SessionSpeakerProduct__c speakerProduct : [SELECT Session__c, Strategy__c
                                                        FROM SessionSpeakerProduct__c
                                                        WHERE Session__c IN :eventIds
                                                        AND Strategy__c != null]) {
            if (!strategiesByEvent.containsKey(speakerProduct.Session__c)) strategiesByEvent.put(speakerProduct.Session__c, new Set<Id>());
            strategiesByEvent.get(speakerProduct.Session__c).add(speakerProduct.Strategy__c);
        }
        return strategiesByEvent;
    }

    // Returns the Event Strategy only when the relationship is unambiguous.
    private static Id getUniqueStrategy(Set<Id> strategyIds) {
        if (strategyIds == null || strategyIds.size() != 1) return null;
        return new List<Id>(strategyIds)[0];
    }

    // Converts the Event business date to a deterministic DateTime used by scoring recency.
    private static Datetime getInteractionDate(CampaignMember member) {
        if (member.Campaign.Start_Date_Time__c != null) return member.Campaign.Start_Date_Time__c;

        Date eventDate = member.Campaign.Event__r.StartDate__c;
        return eventDate == null ? null : Datetime.newInstance(eventDate, Time.newInstance(0, 0, 0, 0));
    }

    // Tracks source records that cannot produce a Contact x Strategy signal.
    private void trackResolutionIssues(Id sourceId, Id contactId, Id strategyId) {
        if (contactId == null) missingContactIds.add(sourceId);
        if (strategyId == null) missingStrategyIds.add(sourceId);
    }
}