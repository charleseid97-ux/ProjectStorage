public with sharing class EngagementSignalRefreshService {

    /**
     * Starts the five source batches with one shared run id for a complete 180-day refresh.
     */
    public static List<Id> runAll() {
        String runId = createRunId();
        List<Id> jobIds = new List<Id>();

        jobIds.add(Database.executeBatch(new EngagementWebsiteSignalBatch(runId), 200));
        jobIds.add(Database.executeBatch(new EngagementNewsletterSignalBatch(runId), 200));
        jobIds.add(Database.executeBatch(new EngagementSubscriptionSignalBatch(runId), 200));
        jobIds.add(Database.executeBatch(new EngagementWebinarSignalBatch(runId), 200));
        jobIds.add(Database.executeBatch(new EngagementMeetingSignalBatch(runId), 200));

        return jobIds;
    }

    /**
     * Confirms that a source batch completed without scope errors before reconciliation.
     */
    public static Boolean isBatchSuccessful(Id jobId) {
        if (jobId == null) {
            return false;
        }

        AsyncApexJob job = [
            SELECT NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        return job.NumberOfErrors == 0;
    }

    /**
     * Generates a compact id that can be persisted on every signal seen by one refresh.
     */
    public static String createRunId() {
        return 'ENG-' + String.valueOf(Datetime.now().getTime());
    }
}