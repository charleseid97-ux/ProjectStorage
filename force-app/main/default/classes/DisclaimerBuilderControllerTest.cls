/** ──────────────────────────────────────
 * @description Test class for the Disclaimer Builder: builder options (record types, valid products), narrative search (one branch per Type with selected Sub Types,
 *              Logical Rule narratives through their rule, Footnote / End Disclaimer bucketing, invalid rule error), Logical Rule criteria (number of products, products,
 *              condition and its scope, invalid conditions) on in-memory DisclaimerLogicalRule__mdt, and the Disclaimer__c + DisclaimerDetail__c creation.
 *              Runs with the DisclaimerBuilderPermissions permission set: the narrative search is in user mode.
 * @author Charles EID
 * @covers DisclaimerBuilderController   100%   [07-11-26]
 * @covers DisclaimerLogicalRules   100%   [07-11-26]
 * @lastModifiedBy Charles EID   [06-11-26]
 ────────────────────────────────────── */
@IsTest
private with sharing class DisclaimerBuilderControllerTest {

    private static final String PERMISSION_SET = 'DisclaimerBuilderPermissions';
    private static final String SICAV_PRODUCT = 'TSTSICAV';
    private static final String FCP_PRODUCT = 'TSTFCP';
    private static final String INVALID_PRODUCT = 'TSTINVALID';
    private static final String COUNTRY = 'BE';
    private static final String LANGUAGE = 'French';
    private static final String OTHER_LANGUAGE = 'English';
    private static final String MEDIA = 'Website';
    private static final String CONTENT_TYPE = 'Content';
    private static final String SOURCE_TYPE = 'Source';
    private static final String SICAV_RULE = 'TestSicavRule';
    private static final String MULTIPLE_RULE = 'TestMultipleRule';
    private static final String SICAV_CONDITION = 'ISPICKVAL(Product__c.LegalForm__c, "SICAV")';

    @TestSetup
    static void makeData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET];
            List<PermissionSetAssignment> assignments = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = :PERMISSION_SET];
            if (assignments.isEmpty()) insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = permissionSets[0].Id);
        }

        insert new List<Product__c>{
            new Product__c(Name = SICAV_PRODUCT, InternalShortName__c = SICAV_PRODUCT, ProductName__c = 'Test SICAV', LegalForm__c = 'SICAV', Validity__c = true),
            new Product__c(Name = FCP_PRODUCT, InternalShortName__c = FCP_PRODUCT, ProductName__c = 'Test FCP', LegalForm__c = 'FCP', Validity__c = true),
            new Product__c(Name = INVALID_PRODUCT, InternalShortName__c = INVALID_PRODUCT, ProductName__c = 'Test Invalid', Validity__c = false)
        };

        String footnote = DisclaimerBuilderController.FOOTNOTE_RECORD_TYPE;
        String endDisclaimer = DisclaimerBuilderController.END_DISCLAIMER_RECORD_TYPE;
        String logicalRule = DisclaimerBuilderController.LOGICAL_RULE_TYPE;
        insert new List<Narrative__c>{
            narrative('Footnote Performance', footnote, CONTENT_TYPE, 'Performance', null, LANGUAGE),
            narrative('Footnote Risk Scale', footnote, CONTENT_TYPE, 'Risk Scale', null, LANGUAGE),
            narrative('Footnote Performance English', footnote, CONTENT_TYPE, 'Performance', null, OTHER_LANGUAGE),
            narrative('End MSCI', endDisclaimer, SOURCE_TYPE, 'MSCI', null, LANGUAGE),
            narrative('Footnote SICAV rule', footnote, logicalRule, null, SICAV_RULE, LANGUAGE),
            narrative('Footnote multiple rule', footnote, logicalRule, null, MULTIPLE_RULE, LANGUAGE)
        };
    }

    @IsTest
    static void testGetBuilderOptions() {
        Test.startTest();

        DisclaimerBuilderController.BuilderOptions options = DisclaimerBuilderController.getBuilderOptions();

        Test.stopTest();

        Map<String, Schema.RecordTypeInfo> recordTypeByName = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName();
        Assert.areEqual(recordTypeByName.get(DisclaimerBuilderController.FOOTNOTE_RECORD_TYPE).getRecordTypeId(), options.footnoteRecordTypeId);
        Assert.areEqual(recordTypeByName.get(DisclaimerBuilderController.END_DISCLAIMER_RECORD_TYPE).getRecordTypeId(), options.endDisclaimerRecordTypeId);
        Assert.areEqual(DisclaimerBuilderController.LOGICAL_RULE_TYPE, options.logicalRuleType);
        Map<String, String> labelByValue = new Map<String, String>();
        for (DisclaimerBuilderController.Option option : options.products) labelByValue.put(option.value, option.label);
        Assert.areEqual(SICAV_PRODUCT + ' - Test SICAV', labelByValue.get(SICAV_PRODUCT), 'Valid product labelled "Internal Short Name - Product Name"');
        Assert.isFalse(labelByValue.containsKey(INVALID_PRODUCT), 'Products with Validity__c unticked are not offered');
    }

    @IsTest
    static void testSearchNarratives() {
        DisclaimerLogicalRules.rules = new List<DisclaimerLogicalRule__mdt>{
            rule(SICAV_RULE, null, null, SICAV_CONDITION, DisclaimerLogicalRules.AT_LEAST_ONE_PRODUCT),
            rule(MULTIPLE_RULE, DisclaimerLogicalRules.MULTIPLE_PRODUCTS, null, null, null)
        };
        Map<String, List<String>> subTypesByType = new Map<String, List<String>>{
            CONTENT_TYPE => new List<String>{ 'Performance' },
            SOURCE_TYPE => new List<String>{ 'MSCI' },
            DisclaimerBuilderController.LOGICAL_RULE_TYPE => new List<String>{ MULTIPLE_RULE }
        };
        String criteriaJson = JSON.serialize(criteria(new List<String>{ SICAV_PRODUCT }, subTypesByType));
        String emptyCriteriaJson = JSON.serialize(criteria(new List<String>(), new Map<String, List<String>>()));
        DisclaimerBuilderController.NarrativeSearchResult result;
        DisclaimerBuilderController.NarrativeSearchResult emptyResult;
        String error;

        Test.startTest();

        System.runAs(builderUser()) {
            result = DisclaimerBuilderController.searchNarratives(criteriaJson);
            emptyResult = DisclaimerBuilderController.searchNarratives(emptyCriteriaJson);
            DisclaimerLogicalRules.rules.add(rule('TestInvalidRule', null, null, 'ISPICKVAL(Product__c.LegalForm__c', null));
            try {
                DisclaimerBuilderController.searchNarratives(criteriaJson);
            }
            catch (AuraHandledException e) {
                error = e.getMessage();
            }
        }

        Test.stopTest();

        Assert.areEqual(2, result.footnote.matchCount, 'Footnote Performance (selected Sub Type, French) + Footnote SICAV rule (passing rule), the Logical Rule key sent by the client is ignored');
        Assert.areEqual(1, result.endDisclaimer.matchCount, 'End MSCI (Sub Type selected under Source)');
        Assert.isTrue(result.footnote.content.contains('Footnote SICAV rule'));
        Assert.areEqual(0, emptyResult.footnote.matchCount + emptyResult.endDisclaimer.matchCount, 'Nothing selected and no passing rule: no narrative');
        Assert.isTrue(error != null && error.contains('TestInvalidRule'), 'An invalid rule stops the search with its name');
    }

    @IsTest
    static void testLogicalRules() {
        DisclaimerLogicalRules.rules = new List<DisclaimerLogicalRule__mdt>{
            rule('NoProduct', DisclaimerLogicalRules.NO_PRODUCT, null, null, null),
            rule('OneProduct', DisclaimerLogicalRules.ONE_PRODUCT, null, null, null),
            rule('MultipleProducts', DisclaimerLogicalRules.MULTIPLE_PRODUCTS, null, null, null),
            rule('ListedFcp', null, 'OTHER; ' + FCP_PRODUCT, null, null),
            rule('AnySicav', null, null, SICAV_CONDITION, DisclaimerLogicalRules.AT_LEAST_ONE_PRODUCT),
            rule('AllSicav', null, null, SICAV_CONDITION, null)
        };
        Map<String, List<String>> noType = new Map<String, List<String>>();

        Test.startTest();

        Set<String> noProductRules = DisclaimerLogicalRules.getMatchingRules(criteria(new List<String>(), noType));
        Set<String> sicavRules = DisclaimerLogicalRules.getMatchingRules(criteria(new List<String>{ SICAV_PRODUCT }, noType));
        Set<String> sicavAndFcpRules = DisclaimerLogicalRules.getMatchingRules(criteria(new List<String>{ SICAV_PRODUCT, FCP_PRODUCT }, noType));
        String syntaxError = getRuleError('ISPICKVAL(Product__c.LegalForm__c');
        String prefixError = getRuleError('ISPICKVAL(Country__c, "BE")');

        Test.stopTest();

        Assert.areEqual(new Set<String>{ 'NoProduct' }, noProductRules, 'No product: only the 0 rule, a condition never passes');
        Assert.areEqual(new Set<String>{ 'OneProduct', 'AnySicav', 'AllSicav' }, sicavRules);
        Assert.areEqual(new Set<String>{ 'MultipleProducts', 'ListedFcp', 'AnySicav' }, sicavAndFcpRules, 'AllSicav fails on the FCP, an empty scope meaning All products');
        Assert.isTrue(syntaxError != null && syntaxError.contains('TestErrorRule'), 'Invalid formula reported with the rule name');
        Assert.isTrue(prefixError != null && prefixError.contains('Product__c'), 'A field without a supported object prefix is rejected');
    }

    @IsTest
    static void testBuildDisclaimer() {
        DisclaimerLogicalRules.rules = new List<DisclaimerLogicalRule__mdt>();
        Map<String, List<String>> subTypesByType = new Map<String, List<String>>{ CONTENT_TYPE => new List<String>{ 'Performance' } };
        String criteriaJson = JSON.serialize(criteria(new List<String>{ SICAV_PRODUCT }, subTypesByType));
        Id disclaimerId;

        Test.startTest();

        System.runAs(builderUser()) {
            DisclaimerBuilderController.NarrativeSearchResult preview = DisclaimerBuilderController.searchNarratives(criteriaJson);
            disclaimerId = DisclaimerBuilderController.buildDisclaimer(criteriaJson, JSON.serialize(preview));
        }

        Test.stopTest();

        Disclaimer__c disclaimer = [SELECT SelectedProducts__c, SelectedTypesAndSubtypes__c, SelectedCountry__c, (SELECT Type__c, Content__c FROM DisclaimerDetails__r) FROM Disclaimer__c WHERE Id = :disclaimerId];
        Assert.areEqual(SICAV_PRODUCT, disclaimer.SelectedProducts__c);
        Assert.areEqual(COUNTRY, disclaimer.SelectedCountry__c);
        Assert.areEqual(JSON.serialize(subTypesByType), JSON.serialize(JSON.deserialize(disclaimer.SelectedTypesAndSubtypes__c, Map<String, List<String>>.class)), 'Types and Sub Types stored as JSON');
        Assert.areEqual(2, disclaimer.DisclaimerDetails__r.size(), 'One Footnote and one End Disclaimer detail');
    }

    // Running user reloaded in a runAs block, so the permission set assigned in makeData applies to the user-mode search.
    private static User builderUser() {
        return new User(Id = UserInfo.getUserId());
    }

    // Error message of a search with a single rule holding the given condition.
    private static String getRuleError(String condition) {
        DisclaimerLogicalRules.rules = new List<DisclaimerLogicalRule__mdt>{ rule('TestErrorRule', null, null, condition, null) };
        try {
            DisclaimerLogicalRules.getMatchingRules(criteria(new List<String>{ SICAV_PRODUCT }, new Map<String, List<String>>()));
        }
        catch (DisclaimerLogicalRules.LogicalRuleException e) {
            return e.getMessage();
        }
        return null;
    }

    private static DisclaimerBuilderController.DisclaimerCriteria criteria(List<String> products, Map<String, List<String>> subTypesByType) {
        DisclaimerBuilderController.DisclaimerCriteria criteria = new DisclaimerBuilderController.DisclaimerCriteria();
        criteria.products = products;
        criteria.subTypesByType = subTypesByType;
        criteria.media = new List<String>{ MEDIA };
        criteria.country = COUNTRY;
        criteria.language = LANGUAGE;
        return criteria;
    }

    private static DisclaimerLogicalRule__mdt rule(String developerName, String numberOfProducts, String products, String condition, String scope) {
        return new DisclaimerLogicalRule__mdt(DeveloperName = developerName, NumberOfProducts__c = numberOfProducts, Products__c = products, Condition__c = condition, ConditionScope__c = scope);
    }

    private static Narrative__c narrative(String name, String recordType, String type, String subType, String logicalRule, String language) {
        return new Narrative__c(
            Name           = name,
            RecordTypeId   = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get(recordType).getRecordTypeId(),
            Type__c        = type,
            SubType__c     = subType,
            LogicalRule__c = logicalRule,
            Content__c     = name,
            Country__c     = COUNTRY,
            Language__c    = language,
            Media__c       = MEDIA
        );
    }
}
