public with sharing class EngagementSignalBatchLogService {

    private static final Integer LOG_CHUNK_SIZE = 100;
    private static final String OPERATION_NAME = 'EngagementSignalResolution';

    /**
     * Writes WARN logs at the end of a source batch for every unresolved source record id.
     */
    public static void logResolutionIssues(
        Id batchJobId,
        String sourceType,
        String contactSourceObject,
        Set<Id> missingContactIds,
        String strategySourceObject,
        Set<Id> missingStrategyIds,
        String apexClass
    ) {
        logIdChunks(
            batchJobId,
            sourceType,
            contactSourceObject,
            'MISSING_CONTACT',
            missingContactIds,
            apexClass
        );
        logIdChunks(
            batchJobId,
            sourceType,
            strategySourceObject,
            'MISSING_STRATEGY',
            missingStrategyIds,
            apexClass
        );

        OperationLogService.flush();
    }

    /**
     * Splits potentially large id collections into bounded structured Operation Logs.
     */
    private static void logIdChunks(
        Id batchJobId,
        String sourceType,
        String sourceObject,
        String issueType,
        Set<Id> recordIds,
        String apexClass
    ) {
        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        List<String> ids = new List<String>();
        for (Id recordId : recordIds) {
            ids.add(String.valueOf(recordId));
        }
        ids.sort();

        Integer totalChunks = (ids.size() + LOG_CHUNK_SIZE - 1) / LOG_CHUNK_SIZE;
        for (Integer startIndex = 0; startIndex < ids.size(); startIndex += LOG_CHUNK_SIZE) {
            Integer endIndex = startIndex + LOG_CHUNK_SIZE;
            if (endIndex > ids.size()) {
                endIndex = ids.size();
            }
            List<String> chunkIds = new List<String>();
            for (Integer index = startIndex; index < endIndex; index++) {
                chunkIds.add(ids[index]);
            }

            Map<String, Object> logContext = new Map<String, Object>{
                'sourceType' => sourceType,
                'sourceObject' => sourceObject,
                'issueType' => issueType,
                'recordCount' => ids.size(),
                'chunk' => (startIndex / LOG_CHUNK_SIZE) + 1,
                'totalChunks' => totalChunks,
                'recordIds' => chunkIds
            };

            OperationLogService.logWithContext(
                OperationLogService.Level.WARN,
                String.valueOf(batchJobId),
                'AsyncApexJob',
                OPERATION_NAME,
                'Engagement source records could not be fully resolved.',
                logContext,
                null,
                apexClass,
                'finish'
            );
        }
    }
}
