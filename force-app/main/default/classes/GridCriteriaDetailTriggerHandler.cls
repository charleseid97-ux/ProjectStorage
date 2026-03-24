/** ──────────────────────────────────────
 * @description Trigger handler for GridCriteriaDetail__c.
 *              BeforeInsert / BeforeUpdate: computes TECHPythonFilter__c as a Pandas-syntax
 *              expression from Field__c, Logic__c, and Value__c.
 *              AfterInsert / AfterUpdate / AfterDelete / AfterUndelete: delegates to
 *              GridCriteriaUtility to recompute TECHPythonExpression__c on the parent
 *              GridCriteria__c record.
 * @author Charles EID
 * @testClass GridCriteriaDetailTriggerHandlerTest
 * @coverage 78%   [26-03-24]
────────────────────────────────────── */
public with sharing class GridCriteriaDetailTriggerHandler implements ITriggerHandler {

    public void BeforeInsert(List<SObject> newItems) {
        setPythonFilters((List<GridCriteriaDetail__c>) newItems);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        setPythonFilters((List<GridCriteriaDetail__c>) newItems.values());
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) {
        GridCriteriaUtility.updatePythonExpressions(collectCriteriaIds(newItems));
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        GridCriteriaUtility.updatePythonExpressions(collectCriteriaIds(newItems));
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
        GridCriteriaUtility.updatePythonExpressions(collectCriteriaIds(oldItems));
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) {
        GridCriteriaUtility.updatePythonExpressions(collectCriteriaIds(oldItems));
    }

    public Boolean IsDisabled() {
        return false;
    }

    // ─── Private helpers ─────────────────────────────────────────────────────
    private static void setPythonFilters(List<GridCriteriaDetail__c> details) {
        for (GridCriteriaDetail__c d : details) {
            d.TECHPythonFilter__c = buildPythonFilter(d);
        }
    }

    private static String buildPythonFilter(GridCriteriaDetail__c d) {
        if (String.isBlank(d.Field__c) || String.isBlank(d.Logic__c)) return null;

        String field  = d.Field__c.trim();
        String logic  = d.Logic__c.trim();
        String rawVal = d.Value__c != null ? d.Value__c : '';

        String expr;

        if (logic == 'IN' || logic == 'NOT IN') {
            List<String> quoted = new List<String>();
            for (String v : rawVal.split(';')) {
                quoted.add('\'' + v.trim() + '\'');
            }
            String listStr = '[' + String.join(quoted, ',') + ']';
            expr = (logic == 'NOT IN' ? '~' : '') + field + '.isin(' + listStr + ')';
        } 
        else if (logic == '=') {
            expr = field + '.eq(\'' + rawVal + '\')';
        } 
        else if (logic == '!=') {
            expr = field + '.ne(\'' + rawVal + '\')';
        } 
        else if (logic == 'LIKE') {
            expr = field + '.str.contains(\'' + rawVal + '\')';
        } 
        else if (logic == 'NOT LIKE') {
            expr = '~' + field + '.str.contains(\'' + rawVal + '\')';
        } 
        else {
            return null;
        }
        return '(' + expr + ')';
    }

    private static List<Id> collectCriteriaIds(Map<Id, SObject> items) {
        Set<Id> ids = new Set<Id>();
        for (GridCriteriaDetail__c d : (List<GridCriteriaDetail__c>) items.values()) {
            if (d.GridCriteria__c != null) ids.add(d.GridCriteria__c);
        }
        return new List<Id>(ids);
    }
}