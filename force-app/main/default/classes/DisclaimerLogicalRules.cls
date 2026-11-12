/** ──────────────────────────────────────
 * @description Logical Rules of the Disclaimer Builder: DisclaimerLogicalRule__mdt records deciding which "Logical Rule" narratives (Narrative__c.LogicalRule__c = rule DeveloperName) join a disclaimer.
 *              A rule passes when every filled criterion passes, an empty one does not constrain:
 *                  NumberOfProducts__c: 0, 1 or Multiple, compared with the number of products the user selected.
 *                  Products__c: InternalShortName__c values separated by ';', at least one of them is selected.
 *                  Condition__c: Salesforce formula returning true or false, evaluated on each selected product; ConditionScope__c says whether at least one or all of them must pass. Never passes without products.
 *              A condition prefixes every field with its object (Product__c.LegalForm__c). The prefixes become relationships of a Narrative__c, the host the formula is compiled on (Formula.builder()):
 *                  Narrative__c only carries the objects through its lookups. Its referenced fields tell what to query on the selected products (one query for all rules).
 *              Objects a condition can read are listed in RELATIONSHIP_BY_OBJECT: Product__c only today. Another object = a new entry and its record put on the host before evaluating.
 *                  The mandatory prefix keeps the rules written today unambiguous when objects are added.
 *              An invalid condition throws a LogicalRuleException naming the rule: a disclaimer must never silently miss a narrative.
 * @author Charles EID
 * @testClass DisclaimerBuilderControllerTest
 * @coverage 100%   [07-11-26]
 ────────────────────────────────────── */
public with sharing class DisclaimerLogicalRules {

    @TestVisible
    private static final String NO_PRODUCT = '0';
    @TestVisible
    private static final String ONE_PRODUCT = '1';
    @TestVisible
    private static final String MULTIPLE_PRODUCTS = 'Multiple';
    @TestVisible
    private static final String AT_LEAST_ONE_PRODUCT = 'At least one product';
    private static final String PRODUCT_OBJECT = 'Product__c';
    private static final String PRODUCTS_SEPARATOR = ';';
    // Object prefix written in a condition => relationship carrying that object on the Narrative__c host
    private static final Map<String, String> RELATIONSHIP_BY_OBJECT = new Map<String, String>{ PRODUCT_OBJECT => 'Product__r' };

    @TestVisible
    private static List<DisclaimerLogicalRule__mdt> rules = DisclaimerLogicalRule__mdt.getAll().values();

    public class LogicalRuleException extends Exception {}

    // DeveloperNames of the rules passing for the user's selection (the builder criteria are the rule context).
    public static Set<String> getMatchingRules(DisclaimerBuilderController.DisclaimerCriteria criteria) {
        List<String> productNames = criteria.products != null ? criteria.products : new List<String>();
        String numberOfProducts = productNames.isEmpty() ? NO_PRODUCT : productNames.size() == 1 ? ONE_PRODUCT : MULTIPLE_PRODUCTS;

        Map<String, FormulaEval.FormulaInstance> conditionByRule = new Map<String, FormulaEval.FormulaInstance>();
        for (DisclaimerLogicalRule__mdt rule : rules) {
            if (String.isNotBlank(rule.Condition__c)) conditionByRule.put(rule.DeveloperName, compile(rule));
        }
        List<Product__c> products = queryProducts(productNames, conditionByRule.values());

        Set<String> matchingRules = new Set<String>();
        for (DisclaimerLogicalRule__mdt rule : rules) {
            if (String.isNotBlank(rule.NumberOfProducts__c) && rule.NumberOfProducts__c != numberOfProducts) continue;
            if (String.isNotBlank(rule.Products__c) && !containsAny(productNames, rule.Products__c.split(PRODUCTS_SEPARATOR))) continue;
            if (conditionByRule.containsKey(rule.DeveloperName) && !conditionPasses(conditionByRule.get(rule.DeveloperName), rule.ConditionScope__c, products)) continue;
            matchingRules.add(rule.DeveloperName);
        }
        return matchingRules;
    }

    // Condition compiled on the Narrative__c host: every field must be reached through a supported object prefix.
    private static FormulaEval.FormulaInstance compile(DisclaimerLogicalRule__mdt rule) {
        String rewritten = rule.Condition__c;
        for (String objectName : RELATIONSHIP_BY_OBJECT.keySet()) {
            rewritten = rewritten.replaceAll('(?i)\\b' + objectName + '\\.', RELATIONSHIP_BY_OBJECT.get(objectName) + '.');
        }
        FormulaEval.FormulaInstance condition;
        try {
            condition = Formula.builder()
                .withType(Schema.Narrative__c.SObjectType)
                .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
                .withFormula(rewritten)
                .build();
        }
        catch (Exception e) {
            throw new LogicalRuleException(rule.DeveloperName + ': ' + e.getMessage());
        }

        for (String reference : condition.getReferencedFields()) {
            if (String.isBlank(objectOf(reference))) throw new LogicalRuleException(rule.DeveloperName + ': prefix ' + reference + ' with its object, one of ' + String.join(new List<String>(RELATIONSHIP_BY_OBJECT.keySet()), ', ') + ' (e.g. Product__c.LegalForm__c)');
        }
        return condition;
    }

    // Selected products with every Product__c field the conditions read, in system mode: rules are configuration and must not depend on the user's field access.
    private static List<Product__c> queryProducts(List<String> productNames, List<FormulaEval.FormulaInstance> conditions) {
        if (productNames.isEmpty()) return new List<Product__c>();
        String productRelationship = RELATIONSHIP_BY_OBJECT.get(PRODUCT_OBJECT);
        Map<String, String> fieldByLowerName = new Map<String, String>{ 'id' => 'Id' };
        for (FormulaEval.FormulaInstance condition : conditions) {
            for (String reference : condition.getReferencedFields()) {
                if (objectOf(reference) != PRODUCT_OBJECT) continue;
                String field = reference.substring(productRelationship.length() + 1);
                fieldByLowerName.put(field.toLowerCase(), field);
            }
        }
        String query = 'SELECT ' + String.join(fieldByLowerName.values(), ', ') + ' FROM ' + PRODUCT_OBJECT + ' WHERE InternalShortName__c IN :productNames';
        return Database.queryWithBinds(query, new Map<String, Object>{ 'productNames' => productNames }, AccessLevel.SYSTEM_MODE);
    }

    // Object whose relationship starts the referenced field (Product__r.LegalForm__c => Product__c), null when the field has no supported prefix.
    private static String objectOf(String reference) {
        for (String objectName : RELATIONSHIP_BY_OBJECT.keySet()) {
            if (reference.startsWithIgnoreCase(RELATIONSHIP_BY_OBJECT.get(objectName) + '.')) return objectName;
        }
        return null;
    }

    private static Boolean containsAny(List<String> selectedNames, List<String> ruleNames) {
        Set<String> selected = new Set<String>(selectedNames);
        for (String ruleName : ruleNames) {
            if (selected.contains(ruleName.trim())) return true;
        }
        return false;
    }

    // At least one product: one selected product passing is enough. All products (default): every selected product must pass.
    private static Boolean conditionPasses(FormulaEval.FormulaInstance condition, String scope, List<Product__c> products) {
        if (products.isEmpty()) return false;
        Boolean requiresAll = scope != AT_LEAST_ONE_PRODUCT;
        for (Product__c product : products) {
            Narrative__c host = new Narrative__c();
            host.putSObject(RELATIONSHIP_BY_OBJECT.get(PRODUCT_OBJECT), product);
            Boolean passes = condition.evaluate(host) == true;
            if (passes && !requiresAll) return true;
            if (!passes && requiresAll) return false;
        }
        return requiresAll;
    }
}