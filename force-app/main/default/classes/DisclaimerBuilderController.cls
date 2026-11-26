/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Disclaimer Builder screen.
 *              Searches the Footnote / End Disclaimer Narrative__c records matching the selected Country / Language / Media and, per Type, the selected Sub Types (Type => Sub Types map, as many Types as the picklist holds),
 *                plus the "Logical Rule" narratives matching the same filters whose rule passes for the selected products (DisclaimerLogicalRules, only called when some are found).
 *              Concatenates their Content__c per Footnote / End Disclaimer bucket, and persists the resulting Disclaimer__c + DisclaimerDetail__c records.
 *              Builder options: Country / Language / Media from the field describe (step 1), and per record type the Type => Sub Types sections offered in step 2,
 *                built from the narratives matching the step 1 settings (same filter as the search, so every Sub Type offered finds narratives), the Sub Types active and valid for their Type (dependency).
 * @author Charles EID
 * @testClass DisclaimerBuilderControllerTest
 * @coverage 100%   [26-11-26]
 * @lastModifiedBy Charles EID   [26-11-26]
 ────────────────────────────────────── */
public with sharing class DisclaimerBuilderController {

    @TestVisible
    private static final String LOGICAL_RULE_TYPE = DisclaimerLogicalRules.LOGICAL_RULE_TYPE;
    @TestVisible
    private static final String FOOTNOTE_RECORD_TYPE = 'FootnoteDisclaimer';
    @TestVisible
    private static final String END_DISCLAIMER_RECORD_TYPE = 'EndDisclaimer';
    // Type__c and SubType__c values in picklist order: a Type's position is its bit in the Sub Types' dependency bitmap (validFor)
    private static final List<Schema.PicklistEntry> TYPE_ENTRIES = Narrative__c.Type__c.getDescribe().getPicklistValues();
    private static final List<Schema.PicklistEntry> SUB_TYPE_ENTRIES = Narrative__c.SubType__c.getDescribe().getPicklistValues();
    private static final String HEX_DIGITS = '0123456789abcdef';

    // Step 1 options (active Country, Language and Media values from the field describe), the record types of the tabs, and the valid products.
    @AuraEnabled(cacheable=true)
    public static BuilderOptions getBuilderOptions() {
        Map<String, Schema.RecordTypeInfo> recordTypeByName = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName();
        BuilderOptions options = new BuilderOptions();
        options.footnoteRecordTypeId = recordTypeByName.get(FOOTNOTE_RECORD_TYPE).getRecordTypeId();
        options.endDisclaimerRecordTypeId = recordTypeByName.get(END_DISCLAIMER_RECORD_TYPE).getRecordTypeId();
        options.countries = getPicklistOptions(Narrative__c.Country__c);
        options.languages = getPicklistOptions(Narrative__c.Language__c);
        options.media = getPicklistOptions(Narrative__c.Media__c);
        for (Product__c product : [SELECT InternalShortName__c, ProductName__c FROM Product__c WHERE InternalShortName__c != null AND Validity__c = true ORDER BY InternalShortName__c]) {
            String label = String.isBlank(product.ProductName__c) ? product.InternalShortName__c : product.InternalShortName__c + ' - ' + product.ProductName__c;
            options.products.add(new Option(label, product.InternalShortName__c));
        }
        return options;
    }

    // Step 2 Type sections of each record type: only the Type / Sub Type pairs used by the narratives matching the step 1 settings (Logical Rule left out).
    @AuraEnabled
    public static ContentOptions getContentOptions(String criteriaJson) {
        DisclaimerCriteria criteria = (DisclaimerCriteria) JSON.deserialize(criteriaJson, DisclaimerCriteria.class);
        Map<String, Object> binds = new Map<String, Object>{ 'logicalRuleType' => LOGICAL_RULE_TYPE };
        String narrativeQuery = 'SELECT RecordType.DeveloperName, Type__c, SubType__c FROM Narrative__c WHERE ' + getSettingsCondition(criteria, binds) + ' AND Type__c != :logicalRuleType AND SubType__c != null';
        List<Narrative__c> narratives = Database.queryWithBinds(narrativeQuery, binds, AccessLevel.USER_MODE);

        // Type => Sub Types used by the narratives of each record type
        Map<String, Map<String, Set<String>>> usedSubTypesByRecordType = new Map<String, Map<String, Set<String>>>{
            FOOTNOTE_RECORD_TYPE       => new Map<String, Set<String>>(),
            END_DISCLAIMER_RECORD_TYPE => new Map<String, Set<String>>()
        };
        Set<String> usedSubTypes = new Set<String>();
        for (Narrative__c narrative : narratives) {
            if (String.isBlank(narrative.Type__c)) continue;
            Map<String, Set<String>> usedSubTypesByType = usedSubTypesByRecordType.get(narrative.RecordType.DeveloperName);
            if (!usedSubTypesByType.containsKey(narrative.Type__c)) usedSubTypesByType.put(narrative.Type__c, new Set<String>());
            usedSubTypesByType.get(narrative.Type__c).add(narrative.SubType__c);
            usedSubTypes.add(narrative.SubType__c);
        }

        Map<String, Set<String>> validTypesBySubType = getValidTypesBySubType(usedSubTypes);
        ContentOptions options = new ContentOptions();
        options.footnote = buildTypeSections(usedSubTypesByRecordType.get(FOOTNOTE_RECORD_TYPE), validTypesBySubType);
        options.endDisclaimer = buildTypeSections(usedSubTypesByRecordType.get(END_DISCLAIMER_RECORD_TYPE), validTypesBySubType);
        return options;
    }

    @AuraEnabled
    public static NarrativeSearchResult searchNarratives(String criteriaJson) {
        DisclaimerCriteria criteria = (DisclaimerCriteria) JSON.deserialize(criteriaJson, DisclaimerCriteria.class);

        // One branch per Type with selected Sub Types, plus every Logical Rule narrative (its rule decides afterwards, the Logical Rule key sent by the client is ignored)
        Map<String, Object> binds = new Map<String, Object>{ 'logicalRuleType' => LOGICAL_RULE_TYPE };
        List<String> typeConditions = new List<String>();
        for (String typeName : criteria.subTypesByType.keySet()) {
            List<String> subTypes = criteria.subTypesByType.get(typeName);
            if (typeName == LOGICAL_RULE_TYPE || subTypes == null || subTypes.isEmpty()) continue;
            Integer index = typeConditions.size();
            typeConditions.add('(Type__c = :type' + index + ' AND SubType__c IN :subTypes' + index + ')');
            binds.put('type' + index, typeName);
            binds.put('subTypes' + index, subTypes);
        }
        typeConditions.add('Type__c = :logicalRuleType');

        NarrativeSearchResult result = new NarrativeSearchResult();
        String narrativeQuery = 'SELECT Id, Content__c, RecordType.DeveloperName, Type__c, SubType__c, Product__c'
                              + ' FROM Narrative__c'
                              + ' WHERE ' + getSettingsCondition(criteria, binds)
                              + ' AND (' + String.join(typeConditions, ' OR ') + ')'
                              + ' ORDER BY DisplayOrder__c NULLS LAST, Name';
        List<Narrative__c> foundNarratives = Database.queryWithBinds(narrativeQuery, binds, AccessLevel.USER_MODE);

        List<Narrative__c> narratives;
        try {
            narratives = DisclaimerLogicalRules.filter(foundNarratives, criteria.products);
        }
        catch (DisclaimerLogicalRules.LogicalRuleException e) {
            AuraHandledException auraException = new AuraHandledException(e.getMessage());
            auraException.setMessage(e.getMessage());
            throw auraException;
        }
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

    // Narratives of the disclaimer record types (or the criteria's one) for the step 1 settings, no media selected meaning narratives without media. Shared by the Type sections and the search, so every Sub Type offered finds narratives.
    private static String getSettingsCondition(DisclaimerCriteria criteria, Map<String, Object> binds) {
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
        return 'RecordType.DeveloperName IN :recordTypes AND Country__c = :country AND Language__c = :language' + mediaCondition;
    }

    // Active values of a picklist field, in picklist order.
    private static List<Option> getPicklistOptions(Schema.SObjectField field) {
        List<Option> options = new List<Option>();
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) options.add(new Option(entry.getLabel(), entry.getValue()));
        }
        return options;
    }

    // Types each given active Sub Type is valid for, decoded from its dependency bitmap (validFor: one bit per Type, in Type picklist order, most significant bit first).
    private static Map<String, Set<String>> getValidTypesBySubType(Set<String> subTypes) {
        Map<String, Set<String>> validTypesBySubType = new Map<String, Set<String>>();
        for (Schema.PicklistEntry subType : SUB_TYPE_ENTRIES) {
            if (!subType.isActive() || !subTypes.contains(subType.getValue())) continue;
            String validFor = (String) ((Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(subType))).get('validFor');
            String bits = String.isBlank(validFor) ? '' : EncodingUtil.convertToHex(EncodingUtil.base64Decode(validFor));
            Set<String> validTypes = new Set<String>();
            for (Integer index = 0; index < TYPE_ENTRIES.size(); index++) {
                if (isBitSet(bits, index)) validTypes.add(TYPE_ENTRIES[index].getValue());
            }
            validTypesBySubType.put(subType.getValue(), validTypes);
        }
        return validTypesBySubType;
    }

    // Bit at the given index of a hexadecimal string, 4 bits per digit, most significant bit first.
    private static Boolean isBitSet(String hex, Integer index) {
        Integer digitIndex = index / 4;
        if (digitIndex >= hex.length()) return false;
        Integer digit = HEX_DIGITS.indexOf(hex.substring(digitIndex, digitIndex + 1));
        return (digit & (8 >> Math.mod(index, 4))) != 0;
    }

    // One section per active Type used, in picklist order, with its used Sub Types that are active and valid for it, in picklist order. A Type without such Sub Type gets no section.
    private static List<TypeSection> buildTypeSections(Map<String, Set<String>> usedSubTypesByType, Map<String, Set<String>> validTypesBySubType) {
        List<TypeSection> sections = new List<TypeSection>();
        for (Schema.PicklistEntry typeEntry : TYPE_ENTRIES) {
            Set<String> usedSubTypes = usedSubTypesByType.get(typeEntry.getValue());
            if (!typeEntry.isActive() || usedSubTypes == null) continue;
            TypeSection section = new TypeSection(typeEntry.getLabel(), typeEntry.getValue());
            for (Schema.PicklistEntry subType : SUB_TYPE_ENTRIES) {
                Set<String> validTypes = validTypesBySubType.get(subType.getValue());
                if (usedSubTypes.contains(subType.getValue()) && validTypes != null && validTypes.contains(typeEntry.getValue())) section.options.add(new Option(subType.getLabel(), subType.getValue()));
            }
            if (!section.options.isEmpty()) sections.add(section);
        }
        return sections;
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
        @AuraEnabled public List<Option> countries { get; set; }
        @AuraEnabled public List<Option> languages { get; set; }
        @AuraEnabled public List<Option> media { get; set; }
        @AuraEnabled public List<Option> products { get; set; }
        public BuilderOptions() {
            this.products = new List<Option>();
        }
    }

    public class ContentOptions {
        @AuraEnabled public List<TypeSection> footnote { get; set; }
        @AuraEnabled public List<TypeSection> endDisclaimer { get; set; }
    }

    public class TypeSection {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String typeName { get; set; }
        @AuraEnabled public List<Option> options { get; set; }
        public TypeSection(String label, String typeName) {
            this.label    = label;
            this.typeName = typeName;
            this.options  = new List<Option>();
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