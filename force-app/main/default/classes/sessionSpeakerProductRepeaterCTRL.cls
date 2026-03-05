public with sharing class sessionSpeakerProductRepeaterCTRL {

    public class PickOpt {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PickOpt(String l, String v) { 
            label = l; 
            value = v; 
        }
    }
    @AuraEnabled(cacheable=true)
    public static String getDefaultSpeakerForEvent(String parentEventId) {
        if (String.isBlank(parentEventId)) return null;

        // ✅ Hypothèse : relation via Session__c
        List<sessionSpeakerProduct__c> recs = [
            SELECT Id, speakerContact__c, CreatedDate
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :parentEventId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (recs.isEmpty()) return null;
        return (String)recs[0].speakerContact__c;
    }

    @AuraEnabled(cacheable=true)
    public static List<PickOpt> languageOptions() {
        Schema.DescribeFieldResult d = sessionSpeakerProduct__c.Language__c.getDescribe();
        if (d != null && d.getType() == Schema.DisplayType.Picklist) {
            List<Schema.PicklistEntry> entries = d.getPicklistValues();
            List<PickOpt> out = new List<PickOpt>();
            for (Schema.PicklistEntry p : entries) {
                if (p.isActive()) {
                    out.add(new PickOpt(p.getLabel(), p.getValue()));
                }
            }
            return out;
        }
        return new List<PickOpt>();
    }

    //   return PickOpt (label + value) 
    @AuraEnabled(cacheable=true)
    public static List<PickOpt> getProducts() {
        List<PickOpt> out = new List<PickOpt>();
        Id StrategyRT = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Strategy').getRecordTypeId();
        for (Product__c p : [
            SELECT Id, Product_Name__c
            FROM Product__c
            WHERE recordTypeId =:StrategyRT
            ORDER BY Product_Name__c
        ]) {
            // label = Product_Name__c, value = Id
            out.add(new PickOpt(p.Product_Name__c, p.Id));
        }

        return out;
    }
}