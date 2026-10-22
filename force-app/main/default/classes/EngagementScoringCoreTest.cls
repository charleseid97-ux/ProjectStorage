@IsTest
private class EngagementScoringCoreTest {

    /**
     * Verifies deterministic signal keys.
     */
    @IsTest
    static void testBuildExternalKey() {
        Id contactId = '003000000000001';
        Id strategyId = 'a3q000000000001';

        String key = EngagementSignalKeyService.buildExternalKey(
            contactId,
            'ClientInterest__c',
            'a01000000000001',
            'MEETING_PRODUCT_INTEREST',
            strategyId
        );

        System.assertEquals(
            '003000000000001|ClientInterest__c|a01000000000001|MEETING_PRODUCT_INTEREST|a3q000000000001',
            key
        );
    }

    /**
     * Verifies the 0-10 day recency boost for a newsletter signal.
     */
    @IsTest
    static void testRecentNewsletterScore() {
        Engagement_Signal__c signal = new Engagement_Signal__c(
            SourceType__c = 'NEWSLETTER_CLICK',
            InteractionDate__c = Datetime.newInstance(Date.today().addDays(-5), Time.newInstance(12, 0, 0, 0)),
            QualityValue__c = null,
            IsActive__c = true
        );

        Decimal score = EngagementScoreCalculator.calculateSignalScore(signal);
        System.assertEquals(1.50, score);
    }

    /**
     * Verifies that Meeting Interest 5 uses the high-quality configured weight.
     */
    @IsTest
    static void testMeetingInterestFiveScore() {
        Engagement_Signal__c signal = new Engagement_Signal__c(
            SourceType__c = 'MEETING_PRODUCT_INTEREST',
            InteractionDate__c = Datetime.newInstance(Date.today().addDays(-5), Time.newInstance(12, 0, 0, 0)),
            QualityValue__c = 5,
            IsActive__c = true
        );

        Decimal score = EngagementScoreCalculator.calculateSignalScore(signal);
        System.assertEquals(15.00, score);
    }

    /**
     * Verifies that a signal older than 180 days contributes zero.
     */
    @IsTest
    static void testExpiredSignalScore() {
        Engagement_Signal__c signal = new Engagement_Signal__c(
            SourceType__c = 'WEBINAR_ATTENDANCE',
            InteractionDate__c = Datetime.newInstance(Date.today().addDays(-181), Time.newInstance(12, 0, 0, 0)),
            QualityValue__c = 85,
            IsActive__c = true
        );

        Decimal score = EngagementScoreCalculator.calculateSignalScore(signal);
        System.assertEquals(0, score);
    }
}
