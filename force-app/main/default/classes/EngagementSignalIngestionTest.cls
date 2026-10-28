@IsTest
private class EngagementSignalIngestionTest {

    /**
     * Verifies strict FundName normalization without fuzzy product matching.
     */
    @IsTest
    static void testResolveFundName() {
        Id strategyId = 'a3q000000000001';
        Map<String, Id> strategyByFundName = new Map<String, Id>{
            'carmignac investissement' => strategyId
        };

        System.assertEquals(
            strategyId,
            EngagementFundStrategyResolver.resolveFundName(
                '  Carmignac   Investissement ',
                strategyByFundName
            )
        );
        System.assertEquals(
            null,
            EngagementFundStrategyResolver.resolveFundName(
                'Carmignac Investissement IE000TEST',
                strategyByFundName
            )
        );
    }

    /**
     * Verifies that one refresh run id is compact and stable in format.
     */
    @IsTest
    static void testCreateRunId() {
        String runId = EngagementSignalRefreshService.createRunId();

        System.assert(runId.startsWith('ENG-'));
        System.assert(runId.length() < 100);
    }
}
