public with sharing class EngagementSignalKeyService {

    /**
     * Builds the deterministic unique key used to upsert an engagement signal.
     */
    public static String buildExternalKey(
        Id contactId,
        String sourceObject,
        String sourceId,
        String sourceType,
        Id strategyId
    ) {
        if (
            contactId == null ||
            String.isBlank(sourceObject) ||
            String.isBlank(sourceId) ||
            String.isBlank(sourceType) ||
            strategyId == null
        ) {
            return null;
        }

        return String.join(
            new List<String>{
                String.valueOf(contactId),
                sourceObject,
                sourceId,
                sourceType,
                String.valueOf(strategyId)
            },
            '|'
        );
    }
}