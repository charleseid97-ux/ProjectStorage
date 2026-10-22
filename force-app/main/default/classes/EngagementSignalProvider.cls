public interface EngagementSignalProvider {

    /**
     * Converts source records into normalized engagement signals.
     */
    List<Engagement_Signal__c> buildSignals(List<SObject> sourceRecords, String runId);
}
