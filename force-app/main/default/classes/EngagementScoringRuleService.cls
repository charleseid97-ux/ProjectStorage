public with sharing class EngagementScoringRuleService {

    /**
     * Returns the active rule configured for one normalized source type.
     */
    public static EngagementSignalRule__mdt getSignalRule(String sourceType) {
        if (String.isBlank(sourceType)) return null;

        for (EngagementSignalRule__mdt rule : EngagementSignalRule__mdt.getAll().values()) {
            if (rule.Active__c && rule.SourceType__c == sourceType) {
                return rule;
            }
        }

        return null;
    }

    /**
     * Returns the base weight to use for a signal, including an optional high-quality threshold.
     */
    public static Decimal getBaseWeight(String sourceType, Decimal qualityValue) {
        EngagementSignalRule__mdt rule = getSignalRule(sourceType);
        if (rule == null || rule.BaseWeight__c == null) return 0;

        if (
            qualityValue != null &&
            rule.HighQualityThreshold__c != null &&
            rule.HighQualityBaseWeight__c != null &&
            qualityValue >= rule.HighQualityThreshold__c
        ) {
            return rule.HighQualityBaseWeight__c;
        }

        return rule.BaseWeight__c;
    }

    /**
     * Returns the configured recency coefficient for an age in days.
     */
    public static Decimal getRecencyCoefficient(Integer ageInDays) {
        if (ageInDays == null || ageInDays < 0) return 0;

        for (EngagementRecencyRule__mdt rule : EngagementRecencyRule__mdt.getAll().values()) {
            if (
                rule.MinDays__c != null &&
                rule.MaxDays__c != null &&
                ageInDays >= rule.MinDays__c.intValue() &&
                ageInDays <= rule.MaxDays__c.intValue()
            ) {
                return rule.Coefficient__c == null ? 0 : rule.Coefficient__c;
            }
        }

        return 0;
    }

    /**
     * Checks common eligibility criteria that are independent from the source SObject schema.
     */
    public static Boolean isCommonEligibilityValid(
        String sourceType,
        Id contactId,
        Id strategyId,
        Datetime interactionDate
    ) {
        EngagementSignalRule__mdt rule = getSignalRule(sourceType);
        if (rule == null || interactionDate == null) return false;

        if (rule.RequireContact__c && contactId == null) return false;
        if (rule.RequireStrategy__c && strategyId == null) return false;

        Integer ageInDays = interactionDate.date().daysBetween(Date.today());
        Integer lookbackDays = rule.LookbackDays__c == null
            ? 180
            : rule.LookbackDays__c.intValue();

        return ageInDays >= 0 && ageInDays <= lookbackDays;
    }
    /**
     * Checks source-specific quality criteria configured in Custom Metadata.
     */
    public static Boolean isQualityEligible(
        String sourceType,
        Decimal qualityValue,
        Boolean isActiveSubscription
    ) {
        EngagementSignalRule__mdt rule = getSignalRule(sourceType);
        if (rule == null) return false;

        if (rule.MinTimeSpentSeconds__c != null &&
            (qualityValue == null || qualityValue < rule.MinTimeSpentSeconds__c)) {
            return false;
        }

        if (rule.MinAttendanceRate__c != null &&
            (qualityValue == null || qualityValue < rule.MinAttendanceRate__c)) {
            return false;
        }

        if (rule.MinInterest__c != null &&
            (qualityValue == null || qualityValue < rule.MinInterest__c)) {
            return false;
        }

        if (rule.RequireActiveSubscription__c && isActiveSubscription != true) {
            return false;
        }

        return true;
    }
}