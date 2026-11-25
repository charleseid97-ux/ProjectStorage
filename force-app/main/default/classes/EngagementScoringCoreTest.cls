/** ──────────────────────────────────────
 * @description Unit tests of the Engagement scoring core: deterministic external key, and signal score
 *              (Base Weight x recency coefficient) for a recent Newsletter click, a high-quality Meeting interest
 *              and an expired Webinar attendance, their Contact x Strategy aggregate and the quality criteria of each rule.
 *              Expected values are read from the custom metadata at runtime.
 * @author Achraf El Hitary
 * @covers EngagementSignalKeyService   100%   [25-11-26]
 * @covers EngagementScoreCalculator   100%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
@IsTest
private class EngagementScoringCoreTest {

    // Verifies the deterministic signal key, the score of a recent Newsletter click, a Meeting interest 5 (high-quality weight) and a Webinar attendance older than 180 days (zero), their Contact x Strategy aggregate, and that every rule with a quality criterion rejects a signal without quality value.
    @IsTest
    static void testScoringCore() {
        Id contactId = '003000000000001AAA';
        Id strategyId = 'a3q000000000001AAA';
        String key = EngagementSignalKeyService.buildExternalKey(contactId, 'ClientInterest__c', 'a01000000000001', 'MEETING_PRODUCT_INTEREST', strategyId);

        System.assertEquals('003000000000001AAA|ClientInterest__c|a01000000000001|MEETING_PRODUCT_INTEREST|a3q000000000001AAA', key);
        System.assertEquals(null, EngagementSignalKeyService.buildExternalKey(null, 'ClientInterest__c', 'a01000000000001', 'MEETING_PRODUCT_INTEREST', strategyId), 'No key without Contact');

        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>{ buildSignal('NEWSLETTER_CLICK', 5, null), buildSignal('MEETING_PRODUCT_INTEREST', 5, 5), buildSignal('WEBINAR_ATTENDANCE', 181, 85), null };
        Decimal expectedTotal = 0;
        Integer expectedCount = 0;
        Set<String> expectedSourceTypes = new Set<String>();
        for (Engagement_Signal__c signal : signals) {
            Decimal expectedScore = signal == null ? 0 : EngagementScoringRuleService.getBaseWeight(signal.SourceType__c, signal.QualityValue__c) * EngagementScoringRuleService.getRecencyCoefficient(signal.InteractionDate__c.date().daysBetween(Date.today()));
            System.assertEquals(expectedScore, EngagementScoreCalculator.calculateSignalScore(signal), 'Signal ' + signal);
            if (expectedScore <= 0) continue;
            expectedTotal += expectedScore;
            expectedCount++;
            expectedSourceTypes.add(signal.SourceType__c);
        }
        EngagementScoreCalculator.ScoreResult result = EngagementScoreCalculator.calculateScore(signals);
        System.assertEquals(expectedTotal, result.score);
        System.assertEquals(expectedCount, result.signalCount);
        System.assertEquals(expectedSourceTypes.size(), result.distinctSourceCount);
        System.assertEquals(0, EngagementScoreCalculator.calculateContactStrategyScore(contactId, strategyId).score, 'No stored signal for this Contact x Strategy');
        System.assertEquals(null, EngagementScoreCalculator.calculateContactStrategyScore(null, strategyId).score);

        System.assertEquals(null, EngagementScoringRuleService.getSignalRule('UNKNOWN_SOURCE'));
        for (EngagementSignalRule__mdt rule : EngagementSignalRule__mdt.getAll().values()) {
            Boolean hasQualityCriterion = rule.MinTimeSpentSeconds__c != null || rule.MinAttendanceRate__c != null || rule.MinInterest__c != null || rule.RequireActiveSubscription__c;
            if (rule.Active__c && hasQualityCriterion) System.assertEquals(false, EngagementScoringRuleService.isQualityEligible(rule.SourceType__c, null, false), rule.SourceType__c + ' rejects a signal without quality value');
        }
    }

    // Builds an active in-memory signal of the given source type, age and quality value.
    private static Engagement_Signal__c buildSignal(String sourceType, Integer ageInDays, Decimal qualityValue) {
        return new Engagement_Signal__c(SourceType__c = sourceType, InteractionDate__c = Datetime.newInstance(Date.today().addDays(-ageInDays), Time.newInstance(12, 0, 0, 0)), QualityValue__c = qualityValue, IsActive__c = true);
    }
}