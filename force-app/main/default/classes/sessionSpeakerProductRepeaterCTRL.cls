public without sharing class sessionSpeakerProductRepeaterCTRL {

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
    public static String getEventCategory(String parentEventId) {
        if (String.isBlank(parentEventId)) return null;

        Event__c ev = [
            SELECT Category__c
            FROM Event__c
            WHERE Id = :parentEventId
            LIMIT 1
        ];

        return ev.Category__c;
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

    // return PickOpt(label + value)
    @AuraEnabled(cacheable=true)
    public static List<PickOpt> getProducts() {
        List<PickOpt> out = new List<PickOpt>();

        List<String> strategyCodes = System.Label.BooklyInScopeStrategy.split(',');

        Set<Id> strategyIds = new Set<Id>();

        for (Product__c p : [
            SELECT FundStrategy__c
            FROM Product__c
            WHERE VehicleType__c = 'Funds'
            AND Validity__c = true
            AND FundStrategy__c != null
        ]) {
            strategyIds.add(p.FundStrategy__c);
        }

        for (Strategy__c s : [
            SELECT Id, Name
            FROM Strategy__c
            WHERE Id IN :strategyIds
            OR Code__c IN :strategyCodes
            ORDER BY Name
        ]) {
            out.add(new PickOpt(s.Name, s.Id));
        }

        return out;
    }
}