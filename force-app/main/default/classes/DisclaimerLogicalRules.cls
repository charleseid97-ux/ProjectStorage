/** ──────────────────────────────────────
 * @description Logical Rules of the Disclaimer Builder: decides which "Logical Rule" narratives (Narrative__c.Type__c = Logical Rule, SubType__c = DeveloperName of a
 *                  DisclaimerLogicalRule__mdt) join a disclaimer, once the builder found them with the user's filters (record type, country, language, media).
 *              Only works when the search found Logical Rule narratives: no query otherwise. A Logical Rule narrative is kept when:
 *                  its SubType__c names an existing rule;
 *                  its Product__c, when filled, is one of the selected products;
 *                  every filled criterion of its rule passes (an empty one does not constrain):
 *                      NumberOfProducts__c: 0, 1 or Multiple, compared with the number of selected products;
 *                      Products__c: InternalShortName__c values separated by ';', at least one of them selected;
 *                      Condition__c: Salesforce formula returning true or false, evaluated by FormulaEvaluatorService on the object of its ConditionScope__c:
 *                          Narrative: the narrative;
 *                          At least one product / All products (default): the selected products;
 *                          At least one share class / All share classes: the valid share classes (Validity__c) of the selected products, all of them together.
 *              A condition is written like a formula field of its scope's object, fields directly (LegalForm__c), lookups followed, 4 at most per path
 *                  (ParentProduct__r.LegalForm__c, Fund__r.LegalForm__c from a share class). A product or share class condition never passes without records.
 *              Cost, only for the rules whose number of products and products criteria pass: 1 query for the rules, 1 for the selected products (only when a condition
 *                  reads them or a narrative has a product), 1 for their share classes, 1 for the narrative fields (each only when a condition needs it).
 *                  A product or share class condition is evaluated once per rule, not once per narrative.
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
    private static final String NARRATIVE_SCOPE = 'Narrative';
    @TestVisible
    private static final String AT_LEAST_ONE_PRODUCT = 'At least one product';
    @TestVisible
    private static final String ALL_PRODUCTS = 'All products';
    @TestVisible
    private static final String AT_LEAST_ONE_SHARE_CLASS = 'At least one share class';
    @TestVisible
    private static final String ALL_SHARE_CLASSES = 'All share classes';
    private static final String PRODUCTS_SEPARATOR = ';';

    // Object each Condition Scope evaluates the condition on, its fields written directly (blank scope = All products, the picklist default)
    private static final Map<String, Schema.SObjectType> TYPE_BY_SCOPE = new Map<String, Schema.SObjectType>{
        NARRATIVE_SCOPE                => Narrative__c.SObjectType,
        AT_LEAST_ONE_PRODUCT     => Product__c.SObjectType,
        ALL_PRODUCTS             => Product__c.SObjectType,
        AT_LEAST_ONE_SHARE_CLASS => Share_Class__c.SObjectType,
        ALL_SHARE_CLASSES        => Share_Class__c.SObjectType
    };
    private static final Set<String> AT_LEAST_ONE_SCOPES = new Set<String>{ AT_LEAST_ONE_PRODUCT, AT_LEAST_ONE_SHARE_CLASS };

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

        // Rules whose number of products and products criteria pass (lower-case DeveloperName keys), their conditions grouped by the object they read
        String numberOfProducts = productNames.isEmpty() ? NO_PRODUCT : productNames.size() == 1 ? ONE_PRODUCT : MULTIPLE_PRODUCTS;
        Map<String, DisclaimerLogicalRule__mdt> ruleByName = new Map<String, DisclaimerLogicalRule__mdt>();
        Map<String, FormulaEvaluatorService> conditionByName = new Map<String, FormulaEvaluatorService>();
        Map<Schema.SObjectType, List<FormulaEvaluatorService>> conditionsByType = new Map<Schema.SObjectType, List<FormulaEvaluatorService>>{
            Narrative__c.SObjectType   => new List<FormulaEvaluatorService>(),
            Product__c.SObjectType     => new List<FormulaEvaluatorService>(),
            Share_Class__c.SObjectType => new List<FormulaEvaluatorService>()
        };
        for (DisclaimerLogicalRule__mdt rule : getRules(names)) {
            if (String.isNotBlank(rule.NumberOfProducts__c) && rule.NumberOfProducts__c != numberOfProducts) continue;
            if (String.isNotBlank(rule.Products__c) && !containsAny(productNames, rule.Products__c.split(PRODUCTS_SEPARATOR))) continue;
            String name = rule.DeveloperName.toLowerCase();
            ruleByName.put(name, rule);
            if (String.isBlank(rule.Condition__c)) continue;

            Schema.SObjectType objectType = TYPE_BY_SCOPE.get(getScope(rule));
            if (objectType == null) throw new LogicalRuleException(rule.DeveloperName + ': unknown Condition Scope ' + rule.ConditionScope__c + ', one of ' + String.join(new List<String>(TYPE_BY_SCOPE.keySet()), ', ') + '.');
            FormulaEvaluatorService condition = compile(rule, objectType);
            conditionByName.put(name, condition);
            conditionsByType.get(objectType).add(condition);
        }

        Boolean hasProductNarrative = false;
        Set<Id> narrativeIds = new Set<Id>();
        for (Narrative__c narrative : ruleNarratives) {
            if (!ruleByName.containsKey(narrative.SubType__c?.toLowerCase())) continue;
            if (narrative.Product__c != null) hasProductNarrative = true;
            if (narrative.Id != null) narrativeIds.add(narrative.Id);
        }

        // Records the conditions read, in system mode: rules are configuration and must not depend on the user's field access
        Map<Schema.SObjectType, List<SObject>> recordsByType = new Map<Schema.SObjectType, List<SObject>>{
            Product__c.SObjectType     => new List<SObject>(),
            Share_Class__c.SObjectType => new List<SObject>()
        };
        if (!productNames.isEmpty() && (hasProductNarrative || !conditionsByType.get(Product__c.SObjectType).isEmpty())) {
            recordsByType.put(Product__c.SObjectType, queryRecords(Product__c.SObjectType, conditionsByType, 'InternalShortName__c IN :names', productNames));
        }
        if (!productNames.isEmpty() && !conditionsByType.get(Share_Class__c.SObjectType).isEmpty()) {
            recordsByType.put(Share_Class__c.SObjectType, queryRecords(Share_Class__c.SObjectType, conditionsByType, 'Fund__r.InternalShortName__c IN :names AND Validity__c = true', productNames));
        }
        Map<Id, Narrative__c> narrativeById = new Map<Id, Narrative__c>();
        List<FormulaEvaluatorService> narrativeConditions = conditionsByType.get(Narrative__c.SObjectType);
        if (!narrativeConditions.isEmpty() && !narrativeIds.isEmpty()) {
            narrativeById = new Map<Id, Narrative__c>((List<Narrative__c>) FormulaEvaluatorService.queryRecords(Narrative__c.SObjectType, narrativeIds,
                FormulaEvaluatorService.getQueryFields(narrativeConditions, null), AccessLevel.SYSTEM_MODE));
        }

        Set<Id> productIds = new Map<Id, SObject>(recordsByType.get(Product__c.SObjectType)).keySet();
        Map<String, Boolean> resultByName = new Map<String, Boolean>();
        List<Boolean> results = new List<Boolean>();
        for (Narrative__c narrative : ruleNarratives) {
            String name = narrative.SubType__c?.toLowerCase();
            Boolean passes = ruleByName.containsKey(name) && (narrative.Product__c == null || productIds.contains(narrative.Product__c));
            FormulaEvaluatorService condition = passes ? conditionByName.get(name) : null;
            if (condition != null) {
                String scope = getScope(ruleByName.get(name));
                if (scope == NARRATIVE_SCOPE) {
                    passes = condition.evaluateBoolean(narrativeById.get(narrative.Id) ?? narrative);
                }
                else {
                    if (!resultByName.containsKey(name)) {
                        List<SObject> records = recordsByType.get(TYPE_BY_SCOPE.get(scope));
                        resultByName.put(name, AT_LEAST_ONE_SCOPES.contains(scope) ? condition.evaluateAny(records) : condition.evaluateEvery(records));
                    }
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

    private static String getScope(DisclaimerLogicalRule__mdt rule) {
        return String.isBlank(rule.ConditionScope__c) ? ALL_PRODUCTS : rule.ConditionScope__c;
    }

    // Condition compiled on its scope's object, its fields written directly
    private static FormulaEvaluatorService compile(DisclaimerLogicalRule__mdt rule, Schema.SObjectType objectType) {
        try {
            return FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(objectType), rule.Condition__c);
        }
        catch (FormulaEvaluatorService.FormulaEvaluatorException e) {
            throw new LogicalRuleException(rule.DeveloperName + ': ' + e.getMessage());
        }
    }

    // Products or share classes of the selection (bound as :names) with every field their conditions read
    private static List<SObject> queryRecords(Schema.SObjectType objectType, Map<Schema.SObjectType, List<FormulaEvaluatorService>> conditionsByType, String whereClause, List<String> productNames) {
        return FormulaEvaluatorService.queryRecords(objectType, FormulaEvaluatorService.getQueryFields(conditionsByType.get(objectType), null), whereClause,
            new Map<String, Object>{ 'names' => productNames }, AccessLevel.SYSTEM_MODE);
    }

    private static Boolean containsAny(List<String> selectedNames, List<String> ruleNames) {
        Set<String> selected = new Set<String>(selectedNames);
        for (String ruleName : ruleNames) {
            if (selected.contains(ruleName.trim())) return true;
        }
        return false;
    }
}
