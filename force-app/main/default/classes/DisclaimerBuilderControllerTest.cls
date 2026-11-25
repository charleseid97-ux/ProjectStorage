/** ──────────────────────────────────────
 * @description Test class for the Disclaimer Builder: builder options (record types, valid products), narrative search (one branch per Type with selected Sub Types,
 *              Logical Rule narratives found with the same filters then kept by their rule for 0, 1 and several products, Footnote / End Disclaimer bucketing,
 *              invalid rule error), Logical Rules on in-memory narratives and DisclaimerLogicalRule__mdt (number of products, products, narrative product,
 *              Condition Scopes: narrative, at least one / all products, at least one / all valid share classes, parents through lookups, unknown rule,
 *              queries made, invalid conditions and scope), and the Disclaimer__c + DisclaimerDetail__c creation.
 *              Runs with the DisclaimerBuilderPermissions permission set: the narrative search is in user mode.
 * @author Charles EID
 * @covers DisclaimerBuilderController   100%   [20-11-26]
 * @covers DisclaimerLogicalRules   100%   [20-11-26]
 * @lastModifiedBy Charles EID   [20-11-26]
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
    // Logical Rule Sub Types = DeveloperNames of the rules: active values of the restricted picklist (CMD_* first), so the test runs in every org
    private static final List<String> RULE_SUB_TYPES = getRuleSubTypes();
    private static final String SICAV_RULE = RULE_SUB_TYPES[0];
    private static final String MULTIPLE_RULE = RULE_SUB_TYPES[1];
    private static final String NO_PRODUCT_RULE = RULE_SUB_TYPES[2];
    private static final String PARENT_RULE = RULE_SUB_TYPES[3];
    private static final String UNKNOWN_RULE = RULE_SUB_TYPES[4];
    // Conditions written on their scope's object: product, share class (its product through Fund__r), narrative
    private static final String SICAV_CONDITION = 'ISPICKVAL(LegalForm__c, "SICAV")';
    private static final String SHARE_CLASS_A_CONDITION = 'ISPICKVAL(Type__c, "A")';
    private static final String SHARE_CLASS_A_OF_SICAV_CHILD_CONDITION = 'ISPICKVAL(Type__c, "A") && ISPICKVAL(Fund__r.ParentProduct__r.LegalForm__c, "SICAV")';
    private static final String NARRATIVE_CONDITION = 'ISPICKVAL(Country__c, "BE") && RecordType.DeveloperName = "FootnoteDisclaimer"';

    @TestSetup
    static void makeData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET];
            List<PermissionSetAssignment> assignments = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = :PERMISSION_SET];
            if (assignments.isEmpty()) insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = permissionSets[0].Id);
        }

        Product__c sicav = new Product__c(Name = SICAV_PRODUCT, InternalShortName__c = SICAV_PRODUCT, ProductName__c = 'Test SICAV', LegalForm__c = 'SICAV', Validity__c = true);
        insert sicav;
        Product__c fcp = new Product__c(Name = FCP_PRODUCT, InternalShortName__c = FCP_PRODUCT, ProductName__c = 'Test FCP', LegalForm__c = 'FCP', Validity__c = true, ParentProduct__c = sicav.Id);
        insert new List<Product__c>{
            fcp,
            new Product__c(Name = INVALID_PRODUCT, InternalShortName__c = INVALID_PRODUCT, ProductName__c = 'Test Invalid', Validity__c = false)
        };
        // The SICAV's only A share class is not valid: share class rules ignore it
        insert new List<Share_Class__c>{
            new Share_Class__c(Name = 'TST SICAV AW', Fund__c = sicav.Id, Type__c = 'AW', Validity__c = true),
            new Share_Class__c(Name = 'TST SICAV A closed', Fund__c = sicav.Id, Type__c = 'A', Validity__c = false),
            new Share_Class__c(Name = 'TST FCP A', Fund__c = fcp.Id, Type__c = 'A', Validity__c = true)
        };

        String footnote = DisclaimerBuilderController.FOOTNOTE_RECORD_TYPE;
        String endDisclaimer = DisclaimerBuilderController.END_DISCLAIMER_RECORD_TYPE;
        String logicalRule = DisclaimerBuilderController.LOGICAL_RULE_TYPE;
        Narrative__c fcpNarrative = narrative('Footnote FCP parent rule', footnote, logicalRule, PARENT_RULE, LANGUAGE);
        fcpNarrative.Product__c = fcp.Id;
        insert new List<Narrative__c>{
            narrative('Footnote Performance', footnote, CONTENT_TYPE, 'Performance', LANGUAGE),
            narrative('Footnote Risk Scale', footnote, CONTENT_TYPE, 'Risk Scale', LANGUAGE),
            narrative('Footnote Performance English', footnote, CONTENT_TYPE, 'Performance', OTHER_LANGUAGE),
            narrative('End MSCI', endDisclaimer, SOURCE_TYPE, 'MSCI', LANGUAGE),
            narrative('Footnote SICAV rule', footnote, logicalRule, SICAV_RULE, LANGUAGE),
            narrative('Footnote SICAV rule English', footnote, logicalRule, SICAV_RULE, OTHER_LANGUAGE),
            narrative('Footnote multiple rule', footnote, logicalRule, MULTIPLE_RULE, LANGUAGE),
            narrative('Footnote no product rule', footnote, logicalRule, NO_PRODUCT_RULE, LANGUAGE),
            narrative('Footnote unknown rule', footnote, logicalRule, UNKNOWN_RULE, LANGUAGE),
            fcpNarrative
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
            rule(MULTIPLE_RULE, DisclaimerLogicalRules.MULTIPLE_PRODUCTS, null, null, null),
            rule(NO_PRODUCT_RULE, DisclaimerLogicalRules.NO_PRODUCT, null, NARRATIVE_CONDITION, DisclaimerLogicalRules.NARRATIVE_SCOPE),
            rule(PARENT_RULE, null, null, SHARE_CLASS_A_OF_SICAV_CHILD_CONDITION, DisclaimerLogicalRules.AT_LEAST_ONE_SHARE_CLASS)
        };
        Map<String, List<String>> subTypesByType = new Map<String, List<String>>{
            CONTENT_TYPE => new List<String>{ 'Performance' },
            SOURCE_TYPE => new List<String>{ 'MSCI' },
            DisclaimerBuilderController.LOGICAL_RULE_TYPE => new List<String>{ MULTIPLE_RULE }
        };
        Map<String, List<String>> noType = new Map<String, List<String>>();
        DisclaimerBuilderController.NarrativeSearchResult oneProduct;
        DisclaimerBuilderController.NarrativeSearchResult noProduct;
        DisclaimerBuilderController.NarrativeSearchResult twoProducts;
        String error;

        Test.startTest();

        System.runAs(builderUser()) {
            oneProduct = DisclaimerBuilderController.searchNarratives(JSON.serialize(criteria(new List<String>{ SICAV_PRODUCT }, subTypesByType)));
            noProduct = DisclaimerBuilderController.searchNarratives(JSON.serialize(criteria(new List<String>(), noType)));
            twoProducts = DisclaimerBuilderController.searchNarratives(JSON.serialize(criteria(new List<String>{ SICAV_PRODUCT, FCP_PRODUCT }, noType)));
            DisclaimerLogicalRules.rules.add(rule(UNKNOWN_RULE, null, null, 'ISPICKVAL(LegalForm__c', null));
            try {
                DisclaimerBuilderController.searchNarratives(JSON.serialize(criteria(new List<String>{ SICAV_PRODUCT }, noType)));
            }
            catch (AuraHandledException e) {
                error = e.getMessage();
            }
        }

        Test.stopTest();

        Assert.areEqual('Footnote Performance\n\nFootnote SICAV rule', oneProduct.footnote.content,
            'Selected Sub Type + SICAV rule; the multiple rule (1 product), the FCP narrative (FCP not selected), the unknown rule and the Logical Rule key sent by the client are left out');
        Assert.areEqual('End MSCI', oneProduct.endDisclaimer.content, 'The no product rule fails with 1 product');
        Assert.areEqual('Footnote no product rule', noProduct.footnote.content,
            'No product: the 0 rule passes, its condition read on the narrative; product and share class conditions never pass, the FCP narrative needs its product');
        Assert.areEqual(0, noProduct.endDisclaimer.matchCount);
        Assert.areEqual(3, twoProducts.footnote.matchCount, 'SICAV rule (one SICAV), multiple rule, FCP narrative (FCP selected, its valid A share class belongs to a SICAV child)');
        Assert.isTrue(twoProducts.footnote.content.contains('Footnote FCP parent rule'));
        Assert.areEqual(0, twoProducts.endDisclaimer.matchCount);
        Assert.isTrue(error != null && error.contains(UNKNOWN_RULE), 'An invalid rule stops the search with its name');
    }

    @IsTest
    static void testLogicalRules() {
        DisclaimerLogicalRules.rules = new List<DisclaimerLogicalRule__mdt>{
            rule('NoProduct', DisclaimerLogicalRules.NO_PRODUCT, null, null, null),
            rule('OneProduct', DisclaimerLogicalRules.ONE_PRODUCT, null, null, null),
            rule('MultipleProducts', DisclaimerLogicalRules.MULTIPLE_PRODUCTS, null, null, null),
            rule('ListedFcp', null, 'OTHER; ' + FCP_PRODUCT, null, null),
            rule('AnySicav', null, null, SICAV_CONDITION, DisclaimerLogicalRules.AT_LEAST_ONE_PRODUCT),
            rule('AllSicav', null, null, SICAV_CONDITION, null),
            rule('ParentSicav', null, null, 'ISPICKVAL(ParentProduct__r.LegalForm__c, "SICAV")', DisclaimerLogicalRules.AT_LEAST_ONE_PRODUCT),
            rule('BelgianNarrative', null, null, 'ISPICKVAL(Country__c, "BE")', DisclaimerLogicalRules.NARRATIVE_SCOPE),
            rule('AnyShareClassA', null, null, SHARE_CLASS_A_CONDITION, DisclaimerLogicalRules.AT_LEAST_ONE_SHARE_CLASS),
            rule('AllSicavShareClasses', null, null, 'ISPICKVAL(Fund__r.LegalForm__c, "SICAV")', DisclaimerLogicalRules.ALL_SHARE_CLASSES)
        };
        Id fcpId = [SELECT Id FROM Product__c WHERE InternalShortName__c = :FCP_PRODUCT].Id;
        List<Narrative__c> narratives = new List<Narrative__c>{ new Narrative__c(Name = 'Not a rule', Type__c = CONTENT_TYPE, SubType__c = 'Performance') };
        for (DisclaimerLogicalRule__mdt rule : DisclaimerLogicalRules.rules) {
            narratives.add(new Narrative__c(Name = rule.DeveloperName, Type__c = DisclaimerLogicalRules.LOGICAL_RULE_TYPE, SubType__c = rule.DeveloperName, Country__c = COUNTRY));
        }
        narratives.add(new Narrative__c(Name = 'FcpNarrative', Type__c = DisclaimerLogicalRules.LOGICAL_RULE_TYPE, SubType__c = 'belgiannarrative', Country__c = COUNTRY, Product__c = fcpId));
        narratives.add(new Narrative__c(Name = 'Unknown', Type__c = DisclaimerLogicalRules.LOGICAL_RULE_TYPE, SubType__c = 'Unknown'));
        narratives.add(new Narrative__c(Name = 'Blank', Type__c = DisclaimerLogicalRules.LOGICAL_RULE_TYPE));
        List<Narrative__c> withoutRules = new List<Narrative__c>{ narratives[0] };

        Test.startTest();

        Integer queries = Limits.getQueries();
        List<String> noProduct = names(DisclaimerLogicalRules.filter(narratives, null));
        Integer noProductQueries = Limits.getQueries() - queries;
        List<String> sicav = names(DisclaimerLogicalRules.filter(narratives, new List<String>{ SICAV_PRODUCT }));
        queries = Limits.getQueries();
        List<String> sicavAndFcp = names(DisclaimerLogicalRules.filter(narratives, new List<String>{ SICAV_PRODUCT, FCP_PRODUCT }));
        Integer sicavAndFcpQueries = Limits.getQueries() - queries;
        List<Narrative__c> unchanged = DisclaimerLogicalRules.filter(withoutRules, new List<String>{ SICAV_PRODUCT });
        String syntaxError = getRuleError('ISPICKVAL(LegalForm__c', null);
        String hopsError = getRuleError('ParentProduct__r.ParentProduct__r.ParentProduct__r.ParentProduct__r.ParentProduct__r.Name = "x"', DisclaimerLogicalRules.ALL_PRODUCTS);
        String narrativeFieldError = getRuleError('ISPICKVAL(LegalForm__c, "SICAV")', DisclaimerLogicalRules.NARRATIVE_SCOPE);
        String scopeError = getRuleError('TRUE', 'Unknown scope');

        Test.stopTest();

        Assert.areEqual(new List<String>{ 'Not a rule', 'NoProduct', 'BelgianNarrative' }, noProduct,
            'No product: the 0 rule and the narrative condition; product and share class conditions fail, the FCP narrative needs its product');
        Assert.areEqual(0, noProductQueries, 'Rules given, no product and no narrative Id: nothing to query');
        Assert.areEqual(new List<String>{ 'Not a rule', 'OneProduct', 'AnySicav', 'AllSicav', 'BelgianNarrative', 'AllSicavShareClasses' }, sicav,
            'The SICAV has no SICAV parent; its A share class is not valid, so only its AW share class is read');
        Assert.areEqual(new List<String>{ 'Not a rule', 'MultipleProducts', 'ListedFcp', 'AnySicav', 'ParentSicav', 'BelgianNarrative', 'AnyShareClassA', 'FcpNarrative' }, sicavAndFcp,
            'AllSicav fails on the FCP (blank scope = all products), AllSicavShareClasses on the FCP share class; the narrative of the FCP passes once the FCP is selected');
        Assert.areEqual(2, sicavAndFcpQueries, 'One query for the selected products and one for their share classes, whatever the number of rules');
        Assert.areEqual(withoutRules, unchanged, 'Without Logical Rule narrative the list is returned as is');
        Assert.isTrue(syntaxError != null && syntaxError.startsWith('TestErrorRule: '), 'Invalid formula reported with the rule name: ' + syntaxError);
        Assert.isTrue(hopsError != null && hopsError.contains('more than the 4 allowed'), 'Paths limited to 4 lookups: ' + hopsError);
        Assert.isTrue(narrativeFieldError != null && narrativeFieldError.contains('LegalForm__c'), 'A Narrative condition is read on the narrative, which has no LegalForm__c: ' + narrativeFieldError);
        Assert.isTrue(scopeError != null && scopeError.contains('unknown Condition Scope Unknown scope'), 'A scope without object is reported: ' + scopeError);
    }

    @IsTest
    static void testBuildDisclaimer() {
        // Rules queried from the custom metadata (none expected for the test Sub Types outside tests)
        DisclaimerLogicalRules.rules = null;
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

    // Error message of a Logical Rule narrative whose single rule holds the given condition and scope.
    private static String getRuleError(String condition, String scope) {
        DisclaimerLogicalRules.rules = new List<DisclaimerLogicalRule__mdt>{ rule('TestErrorRule', null, null, condition, scope) };
        try {
            DisclaimerLogicalRules.filter(new List<Narrative__c>{ new Narrative__c(Type__c = DisclaimerLogicalRules.LOGICAL_RULE_TYPE, SubType__c = 'TestErrorRule') }, new List<String>{ SICAV_PRODUCT });
        }
        catch (DisclaimerLogicalRules.LogicalRuleException e) {
            return e.getMessage();
        }
        return null;
    }

    // 5 active Sub Types usable as DeveloperNames, not used by the other test narratives, CMD_* (the Logical Rule values) first
    private static List<String> getRuleSubTypes() {
        List<String> cmdValues = new List<String>();
        List<String> otherValues = new List<String>();
        Set<String> usedValues = new Set<String>{ 'Performance', 'Risk Scale', 'MSCI' };
        for (Schema.PicklistEntry entry : Narrative__c.SubType__c.getDescribe().getPicklistValues()) {
            String value = entry.getValue();
            if (!entry.isActive() || usedValues.contains(value) || !Pattern.matches('[A-Za-z][A-Za-z0-9_]*', value)) continue;
            if (value.startsWith('CMD_')) cmdValues.add(value);
            else otherValues.add(value);
        }
        cmdValues.addAll(otherValues);
        return cmdValues;
    }

    private static List<String> names(List<Narrative__c> narratives) {
        List<String> result = new List<String>();
        for (Narrative__c narrative : narratives) result.add(narrative.Name);
        return result;
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

    private static Narrative__c narrative(String name, String recordType, String type, String subType, String language) {
        return new Narrative__c(
            Name           = name,
            RecordTypeId   = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get(recordType).getRecordTypeId(),
            Type__c        = type,
            SubType__c     = subType,
            Content__c     = name,
            Country__c     = COUNTRY,
            Language__c    = language,
            Media__c       = MEDIA
        );
    }
}
