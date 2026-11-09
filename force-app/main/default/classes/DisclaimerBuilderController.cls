/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Disclaimer Builder screen.
 *              Searches the Footnote / End Disclaimer Narrative__c records matching the selected Country / Language / Media and, per Type, the selected Sub Types (Type => Sub Types map, as many Types as the picklist holds),
 *                plus the "Logical Rule" narratives whose rule passes for the selected products (DisclaimerLogicalRules).
 *              Concatenates their Content__c per Footnote / End Disclaimer bucket, and persists the resulting Disclaimer__c + DisclaimerDetail__c records.
 * @author Charles EID
 * @testClass DisclaimerBuilderControllerTest
 * @coverage 100%   [09-11-26]
 * @lastModifiedBy Charles EID   [06-11-26]
 ────────────────────────────────────── */
public with sharing class DisclaimerBuilderController {

    @TestVisible
    private static final String LOGICAL_RULE_TYPE = 'Logical Rule';
    @TestVisible
    private static final String FOOTNOTE_RECORD_TYPE = 'FootnoteDisclaimer';
    @TestVisible
    private static final String END_DISCLAIMER_RECORD_TYPE = 'EndDisclaimer';

    // Record types whose picklists build the filters (read by the LWC through the UI API), the Type left out of them, and the valid products.
    @AuraEnabled(cacheable=true)
    public static BuilderOptions getBuilderOptions() {
        Map<String, Schema.RecordTypeInfo> recordTypeByName = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName();
        BuilderOptions options = new BuilderOptions();
        options.footnoteRecordTypeId = recordTypeByName.get(FOOTNOTE_RECORD_TYPE).getRecordTypeId();
        options.endDisclaimerRecordTypeId = recordTypeByName.get(END_DISCLAIMER_RECORD_TYPE).getRecordTypeId();
        options.logicalRuleType = LOGICAL_RULE_TYPE;
        for (Product__c product : [SELECT InternalShortName__c, ProductName__c FROM Product__c WHERE InternalShortName__c != null AND Validity__c = true ORDER BY InternalShortName__c]) {
            String label = String.isBlank(product.ProductName__c) ? product.InternalShortName__c : product.InternalShortName__c + ' - ' + product.ProductName__c;
            options.products.add(new Option(label, product.InternalShortName__c));
        }
        return options;
    }

    @AuraEnabled
    public static NarrativeSearchResult searchNarratives(String criteriaJson) {
        DisclaimerCriteria criteria = (DisclaimerCriteria) JSON.deserialize(criteriaJson, DisclaimerCriteria.class);
        Set<String> ruleNames;
        try {
            ruleNames = DisclaimerLogicalRules.getMatchingRules(criteria);
        }
        catch (DisclaimerLogicalRules.LogicalRuleException e) {
            AuraHandledException auraException = new AuraHandledException(e.getMessage());
            auraException.setMessage(e.getMessage());
            throw auraException;
        }

        // One branch per Type with selected Sub Types, plus the passing Logical Rules
        Map<String, Object> binds = new Map<String, Object>();
        List<String> typeConditions = new List<String>();
        for (String typeName : criteria.subTypesByType.keySet()) {
            List<String> subTypes = criteria.subTypesByType.get(typeName);
            if (typeName == LOGICAL_RULE_TYPE || subTypes == null || subTypes.isEmpty()) continue;
            Integer index = typeConditions.size();
            typeConditions.add('(Type__c = :type' + index + ' AND SubType__c IN :subTypes' + index + ')');
            binds.put('type' + index, typeName);
            binds.put('subTypes' + index, subTypes);
        }
        if (!ruleNames.isEmpty()) {
            typeConditions.add('(Type__c = :logicalRuleType AND LogicalRule__c IN :ruleNames)');
            binds.put('logicalRuleType', LOGICAL_RULE_TYPE);
            binds.put('ruleNames', new List<String>(ruleNames));
        }

        NarrativeSearchResult result = new NarrativeSearchResult();
        if (typeConditions.isEmpty()) return result;
        List<String> recordTypes = new List<String>{ FOOTNOTE_RECORD_TYPE, END_DISCLAIMER_RECORD_TYPE };
        if (criteria.recordTypeId != null) recordTypes = new List<String>{ Schema.SObjectType.Narrative__c.getRecordTypeInfosById().get(criteria.recordTypeId).getDeveloperName() };
        binds.put('recordTypes', recordTypes);
        binds.put('country', criteria.country);
        binds.put('language', criteria.language);
        String mediaCondition = ' AND Media__c = null';
        if (!criteria.media.isEmpty()) {
            mediaCondition = ' AND Media__c IN :media';
            binds.put('media', criteria.media);
        }
        String narrativeQuery = 'SELECT Id, Content__c, RecordType.DeveloperName'
                              + ' FROM Narrative__c'
                              + ' WHERE RecordType.DeveloperName IN :recordTypes AND Country__c = :country AND Language__c = :language' + mediaCondition
                              + ' AND (' + String.join(typeConditions, ' OR ') + ')'
                              + ' ORDER BY DisplayOrder__c NULLS LAST, Name';

        List<Narrative__c> narratives = Database.queryWithBinds(narrativeQuery, binds, AccessLevel.USER_MODE);
        List<Narrative__c> footnotes = new List<Narrative__c>();
        List<Narrative__c> endDisclaimers = new List<Narrative__c>();
        for (Narrative__c narrative : narratives) {
            if (narrative.RecordType.DeveloperName == FOOTNOTE_RECORD_TYPE) {
                footnotes.add(narrative);
            }
            else {
                endDisclaimers.add(narrative);
            }
        }
        result.footnote = buildBucket(footnotes);
        result.endDisclaimer = buildBucket(endDisclaimers);
        return result;
    }

    @AuraEnabled
    public static Id buildDisclaimer(String criteriaJson, String previewJson) {
        DisclaimerCriteria criteria    = (DisclaimerCriteria) JSON.deserialize(criteriaJson, DisclaimerCriteria.class);
        NarrativeSearchResult preview  = (NarrativeSearchResult) JSON.deserialize(previewJson, NarrativeSearchResult.class);

        Disclaimer__c disclaimer = new Disclaimer__c(
            SelectedProducts__c         = String.join(criteria.products, ', '),
            SelectedTypesAndSubtypes__c = JSON.serializePretty(criteria.subTypesByType),
            SelectedMedia__c            = String.join(criteria.media, ', '),
            SelectedCountry__c          = criteria.country,
            SelectedLanguage__c         = criteria.language
        );
        insert disclaimer;

        List<DisclaimerDetail__c> details = new List<DisclaimerDetail__c>{
            new DisclaimerDetail__c(
                Disclaimer__c       = disclaimer.Id,
                Type__c             = 'End Disclaimer',
                Content__c          = preview.endDisclaimer.content,
                SourceNarratives__c = String.join(preview.endDisclaimer.narrativeIds, ', ')
            ),
            new DisclaimerDetail__c(
                Disclaimer__c       = disclaimer.Id,
                Type__c             = 'Footnote',
                Content__c          = preview.footnote.content,
                SourceNarratives__c = String.join(preview.footnote.narrativeIds, ', ')
            )
        };
        insert details;

        return disclaimer.Id;
    }

    private static NarrativeBucket buildBucket(List<Narrative__c> narratives) {
        NarrativeBucket bucket = new NarrativeBucket();
        List<String> contentParts = new List<String>();
        for (Narrative__c n : narratives) {
            if (String.isNotBlank(n.Content__c)) {
                contentParts.add(n.Content__c);
            }
            bucket.narrativeIds.add(n.Id);
        }
        bucket.content    = String.join(contentParts, '\n\n');
        bucket.matchCount = narratives.size();
        return bucket;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class BuilderOptions {
        @AuraEnabled public Id footnoteRecordTypeId { get; set; }
        @AuraEnabled public Id endDisclaimerRecordTypeId { get; set; }
        @AuraEnabled public String logicalRuleType { get; set; }
        @AuraEnabled public List<Option> products { get; set; }
        public BuilderOptions() {
            this.products = new List<Option>();
        }
    }

    public class Option {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class DisclaimerCriteria {
        @AuraEnabled public List<String> products { get; set; }
        @AuraEnabled public Map<String, List<String>> subTypesByType { get; set; }
        @AuraEnabled public List<String> media { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String language { get; set; }
        @AuraEnabled public Id recordTypeId { get; set; }
    }

    public class NarrativeSearchResult {
        @AuraEnabled public NarrativeBucket footnote { get; set; }
        @AuraEnabled public NarrativeBucket endDisclaimer { get; set; }
        public NarrativeSearchResult() {
            this.footnote      = new NarrativeBucket();
            this.endDisclaimer = new NarrativeBucket();
        }
    }

    public class NarrativeBucket {
        @AuraEnabled public String content { get; set; }
        @AuraEnabled public List<String> narrativeIds { get; set; }
        @AuraEnabled public Integer matchCount { get; set; }
        public NarrativeBucket() {
            this.content      = '';
            this.narrativeIds = new List<String>();
            this.matchCount   = 0;
        }
    }
}