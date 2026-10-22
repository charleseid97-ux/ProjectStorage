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

        if (
            !EngagementScoringRuleService.isQualityEligible(
                sourceType,
                qualityValue,
                isActiveSubscription
            )
        ) {
            return null;
        }

        // Build deterministic external key to guarantee idempotence.
        String externalKey =
            EngagementSignalKeyService.buildExternalKey(
                contactId,
                sourceObject,
                sourceId,
                sourceType,
                strategyId
            );

        if (String.isBlank(externalKey)) {
            return null;
        }

        EngagementSignalRule__mdt rule =
            EngagementScoringRuleService.getSignalRule(sourceType);

        Decimal baseWeight =
            EngagementScoringRuleService.getBaseWeight(
                sourceType,
                qualityValue
            );

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
            RuleVersion__c = rule == null
                ? null
                : rule.RuleVersion__c,
            LastSeenRunId__c = runId,
            ObsoleteReason__c = null
        );
    }

    /**
     * Upserts signals by their deterministic external key to prevent duplicates.
     */
    public static void upsertSignals(
        List<Engagement_Signal__c> signals
    ) {
        if (
            signals == null ||
            signals.isEmpty()
        ) {
            return;
        }

        List<Engagement_Signal__c> validSignals =
            new List<Engagement_Signal__c>();

        // Ignore invalid rows before upsert.
        for (Engagement_Signal__c signal : signals) {
            if (
                signal != null &&
                String.isNotBlank(signal.ExternalKey__c)
            ) {
                validSignals.add(signal);
            }
        }

        if (!validSignals.isEmpty()) {
            upsert validSignals
                Engagement_Signal__c.ExternalKey__c;
        }
    }

    /**
     * Result of one Engagement Signal generation attempt.
     */
    public class SignalBuildResult {
        public Boolean Success;
        public Boolean NotValuable;
        public String RejectionReason;
        public Engagement_Signal__c Signal;
    }

    /**
     * Creates a successful result.
     */
    private static SignalBuildResult buildSuccessResult(
        Engagement_Signal__c signal
    ) {
        SignalBuildResult result =
            new SignalBuildResult();

        result.Success = true;
        result.NotValuable = false;
        result.Signal = signal;

        return result;
    }

    /**
     * Creates a rejected result.
     */
    private static SignalBuildResult buildRejectedResult(
        String reason
    ) {
        SignalBuildResult result =
            new SignalBuildResult();

        result.Success = false;
        result.NotValuable = false;
        result.RejectionReason = reason;

        return result;
    }

    /**
     * Creates a normal non-Valuable result.
     */
    private static SignalBuildResult buildNotValuableResult() {
        SignalBuildResult result =
            new SignalBuildResult();

        result.Success = false;
        result.NotValuable = true;

        return result;
    }

    /**
     * Attempts to build one Engagement Signal and returns the processing result.
     */
    public static SignalBuildResult tryBuildSignal(
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
        EngagementSignalRule__mdt rule =
            EngagementScoringRuleService.getSignalRule(
                sourceType
            );

        // Unknown or inactive rule means the source is not Valuable.
        if (
            rule == null ||
            !rule.Active__c
        ) {
            return buildNotValuableResult();
        }

        // Missing mandatory information must be reported.
        if (contactId == null) {
            return buildRejectedResult(
                'MISSING_CONTACT'
            );
        }

        if (strategyId == null) {
            return buildRejectedResult(
                'MISSING_STRATEGY'
            );
        }

        if (interactionDate == null) {
            return buildRejectedResult(
                'MISSING_INTERACTION_DATE'
            );
        }

        if (
            String.isBlank(sourceObject) ||
            String.isBlank(sourceId) ||
            String.isBlank(sourceType)
        ) {
            return buildRejectedResult(
                'INVALID_SOURCE_DATA'
            );
        }

        // A source outside the common configured rules is simply not Valuable.
        if (
            !EngagementScoringRuleService.isCommonEligibilityValid(
                sourceType,
                contactId,
                strategyId,
                interactionDate
            )
        ) {
            return buildNotValuableResult();
        }

        // Applies the source-specific threshold.
        if (
            !EngagementScoringRuleService.isQualityEligible(
                sourceType,
                qualityValue,
                isActiveSubscription
            )
        ) {
            return buildNotValuableResult();
        }

        // Verify deterministic key before creating the signal.
        String externalKey =
            EngagementSignalKeyService.buildExternalKey(
                contactId,
                sourceObject,
                sourceId,
                sourceType,
                strategyId
            );

        if (String.isBlank(externalKey)) {
            return buildRejectedResult(
                'INVALID_EXTERNAL_KEY'
            );
        }

        // Reuse the normalized signal builder.
        Engagement_Signal__c signal =
            buildSignal(
                contactId,
                strategyId,
                sourceObject,
                sourceId,
                sourceType,
                interactionDate,
                qualityValue,
                isActiveSubscription,
                runId
            );

        if (signal == null) {
            return buildNotValuableResult();
        }

        return buildSuccessResult(signal);
    }
}