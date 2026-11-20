/** ──────────────────────────────────────
 * @description Logical Rules of the Disclaimer Builder: decides which "Logical Rule" narratives (Narrative__c.Type__c = Logical Rule, SubType__c = DeveloperName of a
 *                  DisclaimerLogicalRule__mdt) join a disclaimer, once the builder found them with the user's filters (record type, country, language, media).
 *              Only works when the search found Logical Rule narratives: no query otherwise. A Logical Rule narrative is kept when:
 *                  its SubType__c names an existing rule;
 *                  its Product__c, when filled, is one of the selected products;
 *                  every filled criterion of its rule passes (an empty one does not constrain):
 *                      NumberOfProducts__c: 0, 1 or Multiple, compared with the number of selected products;
 *                      Products__c: InternalShortName__c values separated by ';', at least one of them selected;
 *                      Condition__c: Salesforce formula returning true or false, evaluated by FormulaEvaluatorService.
 *              A condition is written like a formula field of the narrative: its fields directly or prefixed (Narrative__c.Country__c), and the selected product
 *                  through Product__c. or Product__r. (Product__r.ParentProduct__r.LegalForm__c). Lookups are followed, 4 at most per path.
 *                  Without selected product, it is evaluated on the narrative, and a condition reading the product never passes.
 *                  With selected products, it is evaluated on each of them, ConditionScope__c saying whether at least one or all of them (default) must pass.
 *              Cost, only for the rules whose number of products and products criteria pass: 1 query for the rules, 1 for the selected products (only when a condition
 *                  reads them or a narrative has a product), 1 for the narrative fields the conditions read (only when they read some).
 *                  A condition that does not read the narrative is evaluated once per rule, not once per narrative.
 *              An invalid condition throws a LogicalRuleException naming the rule: a disclaimer must never silently miss a narrative.
 * @author Charles EID
 * @testClass DisclaimerBuilderControllerTest
 * @coverage 100%   [20-11-26]
 ────────────────────────────────────── */
public with sharing class DisclaimerLogicalRules {

    public static final String LOGICAL_RULE_TYPE = 'Logical Rule';
    @TestVisible
    private static final String NO_PRODUCT = '0';
    @TestVisible
    private static final String ONE_PRODUCT = '1';
    @TestVisible
    private static final String MULTIPLE_PRODUCTS = 'Multiple';
    @TestVisible
    private static final String AT_LEAST_ONE_PRODUCT = 'At least one product';
    private static final String NARRATIVE_PREFIX = 'Narrative__c';
    private static final String PRODUCT_PREFIX = 'Product__c';
    private static final String PRODUCTS_SEPARATOR = ';';

    // Conditions compiled on the narrative (its fields with or without prefix), the selected product put on its Product__r relationship
    private static final FormulaEvaluatorService.Context CONDITION_CONTEXT = new FormulaEvaluatorService.Context(Narrative__c.SObjectType)
        .withPrefix(NARRATIVE_PREFIX, null)
        .withPrefix(PRODUCT_PREFIX, 'Product__r');

    // Rules given by the tests (custom metadata records cannot be inserted); otherwise queried: getAll() cuts Condition__c at 255 characters
    @TestVisible
    private static List<DisclaimerLogicalRule__mdt> rules;

    public class LogicalRuleException extends Exception {}

    /** Narratives found by the builder, in their order, without the Logical Rule narratives whose rule does not pass for the selected products
     *      (InternalShortName__c values). The narratives must carry Type__c, SubType__c and Product__c. */
    public static List<Narrative__c> filter(List<Narrative__c> narratives, List<String> productNames) {
        List<Narrative__c> ruleNarratives = new List<Narrative__c>();
        for (Narrative__c narrative : narratives) {
            if (narrative.Type__c == LOGICAL_RULE_TYPE) ruleNarratives.add(narrative);
        }
        if (ruleNarratives.isEmpty()) return narratives;

        List<Boolean> results = evaluate(ruleNarratives, productNames ?? new List<String>());
        List<Narrative__c> kept = new List<Narrative__c>();
        Integer index = 0;
        for (Narrative__c narrative : narratives) {
            if (narrative.Type__c != LOGICAL_RULE_TYPE || results[index++]) kept.add(narrative);
        }
        return kept;
    }

    // Result of each Logical Rule narrative, in their order
    private static List<Boolean> evaluate(List<Narrative__c> ruleNarratives, List<String> productNames) {
        Set<String> names = new Set<String>();
        for (Narrative__c narrative : ruleNarratives) {
            if (String.isNotBlank(narrative.SubType__c)) names.add(narrative.SubType__c);
        }

        // Rules whose number of products and products criteria pass, with their condition (lower-case DeveloperName keys)
        String numberOfProducts = productNames.isEmpty() ? NO_PRODUCT : productNames.size() == 1 ? ONE_PRODUCT : MULTIPLE_PRODUCTS;
        Map<String, DisclaimerLogicalRule__mdt> ruleByName = new Map<String, DisclaimerLogicalRule__mdt>();
        Map<String, FormulaEvaluatorService> conditionByName = new Map<String, FormulaEvaluatorService>();
        for (DisclaimerLogicalRule__mdt rule : getRules(names)) {
            if (String.isNotBlank(rule.NumberOfProducts__c) && rule.NumberOfProducts__c != numberOfProducts) continue;
            if (String.isNotBlank(rule.Products__c) && !containsAny(productNames, rule.Products__c.split(PRODUCTS_SEPARATOR))) continue;
            String name = rule.DeveloperName.toLowerCase();
            ruleByName.put(name, rule);
            if (String.isNotBlank(rule.Condition__c)) conditionByName.put(name, compile(rule));
        }

        Boolean hasProductNarrative = false;
        Set<Id> narrativeIds = new Set<Id>();
        for (Narrative__c narrative : ruleNarratives) {
            if (!ruleByName.containsKey(narrative.SubType__c?.toLowerCase())) continue;
            if (narrative.Product__c != null) hasProductNarrative = true;
            if (narrative.Id != null) narrativeIds.add(narrative.Id);
        }

        // Selected products, when a condition reads them or a narrative has a product to compare
        List<FormulaEvaluatorService> conditions = conditionByName.values();
        List<Product__c> products = new List<Product__c>();
        Set<Id> productIds = new Set<Id>();
        Set<String> productFields = FormulaEvaluatorService.getQueryFields(conditions, PRODUCT_PREFIX);
        if (!productNames.isEmpty() && (!productFields.isEmpty() || hasProductNarrative)) {
            productFields.add('InternalShortName__c');
            products = (List<Product__c>) FormulaEvaluatorService.queryRecords(Product__c.SObjectType, productFields, 'InternalShortName__c IN :names',
                new Map<String, Object>{ 'names' => productNames }, AccessLevel.SYSTEM_MODE);
            for (Product__c product : products) productIds.add(product.Id);
        }

        // Narrative fields the conditions read, in system mode: rules are configuration and must not depend on the user's field access
        Map<Id, Narrative__c> narrativeById = new Map<Id, Narrative__c>();
        Set<String> narrativeFields = FormulaEvaluatorService.getQueryFields(conditions, NARRATIVE_PREFIX);
        if (!narrativeFields.isEmpty() && !narrativeIds.isEmpty()) {
            narrativeById = new Map<Id, Narrative__c>((List<Narrative__c>) FormulaEvaluatorService.queryRecords(Narrative__c.SObjectType, narrativeIds, narrativeFields, AccessLevel.SYSTEM_MODE));
        }

        Map<String, Boolean> resultByName = new Map<String, Boolean>();
        List<Boolean> results = new List<Boolean>();
        for (Narrative__c narrative : ruleNarratives) {
            String name = narrative.SubType__c?.toLowerCase();
            Boolean passes = ruleByName.containsKey(name) && (narrative.Product__c == null || productIds.contains(narrative.Product__c));
            FormulaEvaluatorService condition = passes ? conditionByName.get(name) : null;
            if (condition != null) {
                String scope = ruleByName.get(name).ConditionScope__c;
                if (condition.reads(NARRATIVE_PREFIX)) {
                    passes = conditionPasses(condition, scope, narrativeById.get(narrative.Id) ?? narrative, products);
                }
                else {
                    if (!resultByName.containsKey(name)) resultByName.put(name, conditionPasses(condition, scope, null, products));
                    passes = resultByName.get(name);
                }
            }
            results.add(passes);
        }
        return results;
    }

    private static List<DisclaimerLogicalRule__mdt> getRules(Set<String> names) {
        if (names.isEmpty()) return new List<DisclaimerLogicalRule__mdt>();
        if (rules == null) return [SELECT DeveloperName, NumberOfProducts__c, Products__c, Condition__c, ConditionScope__c FROM DisclaimerLogicalRule__mdt WHERE DeveloperName IN :names];

        Set<String> lowerNames = new Set<String>();
        for (String name : names) lowerNames.add(name.toLowerCase());
        List<DisclaimerLogicalRule__mdt> found = new List<DisclaimerLogicalRule__mdt>();
        for (DisclaimerLogicalRule__mdt rule : rules) {
            if (lowerNames.contains(rule.DeveloperName.toLowerCase())) found.add(rule);
        }
        return found;
    }

    private static FormulaEvaluatorService compile(DisclaimerLogicalRule__mdt rule) {
        try {
            return FormulaEvaluatorService.compile(CONDITION_CONTEXT, rule.Condition__c);
        }
        catch (FormulaEvaluatorService.FormulaEvaluatorException e) {
            throw new LogicalRuleException(rule.DeveloperName + ': ' + e.getMessage());
        }
    }

    // Without selected product: evaluated on the narrative, never passes when it reads the product. Otherwise on each product: at least one, or all of them (default).
    private static Boolean conditionPasses(FormulaEvaluatorService condition, String scope, Narrative__c narrative, List<Product__c> products) {
        if (!condition.reads(PRODUCT_PREFIX)) return condition.evaluateBoolean(new Map<String, SObject>{ NARRATIVE_PREFIX => narrative });
        if (products.isEmpty()) return false;

        Boolean requiresAll = scope != AT_LEAST_ONE_PRODUCT;
        for (Product__c product : products) {
            Boolean passes = condition.evaluateBoolean(new Map<String, SObject>{ NARRATIVE_PREFIX => narrative, PRODUCT_PREFIX => product });
            if (passes != requiresAll) return passes;
        }
        return requiresAll;
    }

    private static Boolean containsAny(List<String> selectedNames, List<String> ruleNames) {
        Set<String> selected = new Set<String>(selectedNames);
        for (String ruleName : ruleNames) {
            if (selected.contains(ruleName.trim())) return true;
        }
        return false;
    }
}