public with sharing class EngagementSignalService {

    /**
     * Applies rule metadata and prepares one idempotent Engagement_Signal__c record.
     */
    public static Engagement_Signal__c buildSignal(
        Id contactId,
        Id strategyId,
        String sourceObject,
        String sourceId,
        String sourceType,
        Datetime interactionDate,
        Decimal qualityValue,
        Boolean isActiveSubscription,
        String runId
    ) {
        if (
            !EngagementScoringRuleService.isCommonEligibilityValid(
                sourceType,
                contactId,
                strategyId,
                interactionDate
            )
        ) {
            return null;
        }

        if (!EngagementScoringRuleService.isQualityEligible(
            sourceType,
            qualityValue,
            isActiveSubscription
        )) {
            return null;
        }

        String externalKey = EngagementSignalKeyService.buildExternalKey(
            contactId,
            sourceObject,
            sourceId,
            sourceType,
            strategyId
        );
        if (String.isBlank(externalKey)) return null;

        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(sourceType);
        Decimal baseWeight = EngagementScoringRuleService.getBaseWeight(sourceType, qualityValue);

        return new Engagement_Signal__c(
            ExternalKey__c = externalKey,
            Contact__c = contactId,
            Strategy__c = strategyId,
            SourceId__c = sourceId,
            SourceObject__c = sourceObject,
            SourceType__c = sourceType,
            InteractionDate__c = interactionDate,
            QualityValue__c = qualityValue,
            BaseWeight__c = baseWeight,
            IsActive__c = true,
            RuleVersion__c = rule == null ? null : rule.RuleVersion__c,
            LastSeenRunId__c = runId,
            ObsoleteReason__c = null
        );
    }

    /**
     * Upserts signals by their deterministic external key to prevent duplicates.
     */
    public static void upsertSignals(List<Engagement_Signal__c> signals) {
        if (signals == null || signals.isEmpty()) return;

        Map<String, Engagement_Signal__c> signalsByExternalKey =
            new Map<String, Engagement_Signal__c>();
        for (Engagement_Signal__c signal : signals) {
            if (signal != null && String.isNotBlank(signal.ExternalKey__c)) {
                signalsByExternalKey.put(signal.ExternalKey__c, signal);
            }
        }

        if (!signalsByExternalKey.isEmpty()) {
            List<Engagement_Signal__c> validSignals = signalsByExternalKey.values();
            upsert validSignals Engagement_Signal__c.ExternalKey__c;
        }
    }
}