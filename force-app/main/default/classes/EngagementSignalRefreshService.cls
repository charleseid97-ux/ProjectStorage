/** ──────────────────────────────────────
 * @description Orchestrates the Engagement Signal refresh: starts the five source batches (Website, Newsletter,
 *              Subscription, Webinar, Meeting) with one shared run id. A full refresh reads the LookbackDays__c window
 *              of each source and then reconciles it; a partial refresh (windowDays) only reads the last N days and
 *              skips the reconciliation, which would otherwise deactivate the valid signals older than N days.
 *              Scheduled once per org from Execute Anonymous, by a user on the Europe/Paris time zone:
 *              System.schedule('Engagement Signals Refresh (14 days)', '0 0 8,12,16 * * ?', new EngagementSignalRefreshService(14));
 *              System.schedule('Engagement Signals Full Refresh', '0 0 2 ? * SUN', new EngagementSignalRefreshService());
 * @author Achraf El Hitary
 * @testClass EngagementSignalIngestionTest
 * @coverage 100%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
public with sharing class EngagementSignalRefreshService implements Schedulable {

    private final Integer windowDays;

    // Full refresh: each source batch reads its LookbackDays__c window, then reconciles.
    public EngagementSignalRefreshService() {
        this(null);
    }

    // Partial refresh limited to the last windowDays days, without reconciliation; null for a full refresh.
    public EngagementSignalRefreshService(Integer windowDays) {
        this.windowDays = windowDays;
    }

    // Scheduled entry point: runs the refresh of this job with a fresh run id at every fire.
    public void execute(SchedulableContext context) {
        runAll(windowDays);
    }

    // Starts the five source batches with one shared run id, limited to the last windowDays days when windowDays is set (manual run: runAll(null) for a full refresh).
    public static List<Id> runAll(Integer windowDays) {
        String runId = createRunId();
        List<Id> jobIds = new List<Id>();

        jobIds.add(Database.executeBatch(new EngagementWebsiteSignalBatch(runId, windowDays), 200));
        jobIds.add(Database.executeBatch(new EngagementNewsletterSignalBatch(runId, windowDays), 200));
        jobIds.add(Database.executeBatch(new EngagementSubscriptionSignalBatch(runId, windowDays), 200));
        jobIds.add(Database.executeBatch(new EngagementWebinarSignalBatch(runId, windowDays), 200));
        jobIds.add(Database.executeBatch(new EngagementMeetingSignalBatch(runId, windowDays), 200));

        return jobIds;
    }

    // Called by each source batch's finish(): reconciles its source only after a successful full run, since a partial run did not re-read the signals older than its window.
    public static void reconcileFullRun(Id jobId, String sourceType, String runId, Integer windowDays) {
        if (windowDays == null && isBatchSuccessful(jobId)) Database.executeBatch(new EngagementSignalReconciliationBatch(sourceType, runId), 200);
    }

    // Confirms that a source batch completed without scope errors before reconciliation.
    public static Boolean isBatchSuccessful(Id jobId) {
        if (jobId == null) return false;

        AsyncApexJob job = [SELECT NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        return job.NumberOfErrors == 0;
    }

    // Generates a compact id that can be persisted on every signal seen by one refresh.
    public static String createRunId() {
        return 'ENG-' + String.valueOf(Datetime.now().getTime());
    }
}