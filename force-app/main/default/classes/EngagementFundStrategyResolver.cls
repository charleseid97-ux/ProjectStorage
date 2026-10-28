public with sharing class EngagementFundStrategyResolver {

    /**
     * Builds a normalized Fund name -> legacy Strategy__c map from Product Catalog Funds.
     */
    public static Map<String, Id> loadStrategyByFundName() {
        Map<String, Id> strategyByFundName = new Map<String, Id>();
        Set<String> ambiguousFundNames = new Set<String>();

        for (Product__c product : [
            SELECT ProductName__c,
                   FundStrategy__c
            FROM Product__c
            WHERE ProductName__c != null
            AND FundStrategy__c != null
        ]) {
            String normalizedFundName = normalizeFundName(product.ProductName__c);
            if (String.isBlank(normalizedFundName)) {
                continue;
            }

            // A duplicated Fund name pointing to different Strategies is not safe to auto-resolve.
            if (
                strategyByFundName.containsKey(normalizedFundName) &&
                strategyByFundName.get(normalizedFundName) != product.FundStrategy__c
            ) {
                strategyByFundName.remove(normalizedFundName);
                ambiguousFundNames.add(normalizedFundName);
                continue;
            }

            if (!ambiguousFundNames.contains(normalizedFundName)) {
                strategyByFundName.put(normalizedFundName, product.FundStrategy__c);
            }
        }

        return strategyByFundName;
    }

    /**
     * Resolves one FundName text only when an exact normalized Product Catalog Fund exists.
     */
    public static Id resolveFundName(String fundName, Map<String, Id> strategyByFundName) {
        if (String.isBlank(fundName) || strategyByFundName == null) {
            return null;
        }

        return strategyByFundName.get(normalizeFundName(fundName));
    }

    /**
     * Normalizes harmless text differences without applying fuzzy business matching.
     */
    @TestVisible
    private static String normalizeFundName(String fundName) {
        return String.isBlank(fundName)
            ? null
            : fundName.trim().replaceAll('\\s+', ' ').toLowerCase();
    }
}
