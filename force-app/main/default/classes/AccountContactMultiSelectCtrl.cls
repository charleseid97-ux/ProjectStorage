public with sharing class AccountContactMultiSelectCtrl {
    public class OptionItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionItem(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getContactsByAccount(Id accountId, Integer limitSize) {
        List<OptionItem> results = new List<OptionItem>();

        if (accountId == null) {
            return results;
        }

        Integer safeLimit = (limitSize == null || limitSize <= 0) ? 200 : Math.min(limitSize, 2000);

        for (Contact c : [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name
            LIMIT :safeLimit
        ]) {
            results.add(new OptionItem(c.Name, c.Id));
        }

        return results;
    }
}