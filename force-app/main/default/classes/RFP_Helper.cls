public with sharing class RFP_Helper {

    /**
     * Returns SubCategory picklist values (label = "value | label") 
     * filtered by Category and by actual usage in records.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getSubCategories(String category) {
        if (String.isBlank(category)) return new List<PicklistOption>();

        // ---- 1️⃣  Get all picklist entries from field describe ----
        Schema.DescribeFieldResult subCatDescribe = 
            RFP_Library__c.SubCategory__c.getDescribe();
        List<Schema.PicklistEntry> allEntries = subCatDescribe.getPicklistValues();

        // ---- 2️⃣  Query existing RFP_Library__c to find used values ----
        Set<String> usedValues = new Set<String>();
        for (AggregateResult ar : [
            SELECT SubCategory__c subCat
            FROM RFP_Library__c
            WHERE Category__c = :category
              AND SubCategory__c != NULL
            GROUP BY SubCategory__c
        ]) {
            usedValues.add((String) ar.get('subCat'));
        }

        // ---- 3️⃣  Build results only for used picklist values ----
        List<PicklistOption> results = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : allEntries) {
            String value = entry.getValue();
            if (usedValues.contains(value)) {
                String label = entry.getLabel();
                results.add(new PicklistOption(
                    value,
                    value + ' | ' + label // "CP | Patrimoine"
                ));
            }
        }

        // Sort alphabetically by label for UI friendliness
        // results.sort();
        return results;
    }

    // Simple DTO wrapper for LWC combobox options
    public class PicklistOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }

        public PicklistOption(String v, String l) {
            value = v;
            label = l;
        }

    }
}