public with sharing class EngagementScoreCalculator {

    public class ScoreResult {
        @AuraEnabled public Decimal score;
        @AuraEnabled public Integer signalCount;
        @AuraEnabled public Integer distinctSourceCount;
        @AuraEnabled public Datetime lastInteractionDate;
    }

    /**
     * Calculates the current contribution of one active signal.
     */
    public static Decimal calculateSignalScore(Engagement_Signal__c signal) {
        if (
            signal == null ||
            signal.IsActive__c != true ||
            signal.InteractionDate__c == null ||
            String.isBlank(signal.SourceType__c)
        ) {
            return 0;
        }

        Integer ageInDays = signal.InteractionDate__c.date().daysBetween(Date.today());
        Decimal recencyCoefficient = EngagementScoringRuleService.getRecencyCoefficient(ageInDays);
        if (recencyCoefficient == 0) return 0;

        // Resolve the current metadata weight so a rule change affects scoring immediately.
        Decimal baseWeight = EngagementScoringRuleService.getBaseWeight(
            signal.SourceType__c,
            signal.QualityValue__c
        );

        return baseWeight * recencyCoefficient;
    }

    /**
     * Calculates the score for a Contact x Strategy from already loaded signals.
     */
    public static ScoreResult calculateScore(List<Engagement_Signal__c> signals) {
        ScoreResult result = new ScoreResult();
        result.score = 0;
        result.signalCount = 0;
        result.distinctSourceCount = 0;

        if (signals == null || signals.isEmpty()) return result;

        Set<String> sourceTypes = new Set<String>();
        for (Engagement_Signal__c signal : signals) {
            Decimal contribution = calculateSignalScore(signal);
            if (contribution <= 0) continue;

            result.score += contribution;
            result.signalCount++;
            sourceTypes.add(signal.SourceType__c);

            if (
                result.lastInteractionDate == null ||
                signal.InteractionDate__c > result.lastInteractionDate
            ) {
                result.lastInteractionDate = signal.InteractionDate__c;
            }
        }

        result.distinctSourceCount = sourceTypes.size();
        return result;
    }

    /**
     * Loads active signals and calculates one Contact x Strategy score on demand.
     */
    @AuraEnabled(cacheable=true)
    public static ScoreResult calculateContactStrategyScore(Id contactId, Id strategyId) {
        if (contactId == null || strategyId == null) return new ScoreResult();

        Datetime cutoff = System.now().addDays(-180);

        List<Engagement_Signal__c> signals = [
            SELECT Id,
                   SourceType__c,
                   InteractionDate__c,
                   QualityValue__c,
                   BaseWeight__c,
                   IsActive__c
            FROM Engagement_Signal__c
            WHERE Contact__c = :contactId
            AND Strategy__c = :strategyId
            AND IsActive__c = true
            AND InteractionDate__c >= :cutoff
        ];

        return calculateScore(signals);
    }
}
