/** ──────────────────────────────────────
 * @description Utility class for GridCriteria__c computations.
 *              updatePythonExpressions() recomputes TECHPythonExpression__c on a list of
 *              GridCriteria__c records by concatenating the TECHPythonFilter__c of all their
 *              children using the criteria's FilterLogic__c (AND / OR / Custom Logic).
 * @author Charles EID
 * @usedBy GridCriteriaDetailTriggerHandler
 * @coverage 90%   [26-03-24]
────────────────────────────────────── */
public with sharing class GridCriteriaUtility {

    /**
     * Recomputes TECHPythonExpression__c on each GridCriteria__c from its children's
     * TECHPythonFilter__c values, applying the FilterLogic__c / FilterLogicExpression__c.
     */
    public static void updatePythonExpressions(List<Id> criteriaIds) {
        if (criteriaIds == null || criteriaIds.isEmpty()) return;

        Map<Id, GridCriteria__c> criteriaMap = new Map<Id, GridCriteria__c>([SELECT Id, FilterLogic__c, FilterLogicExpression__c
                                                                             FROM GridCriteria__c
                                                                             WHERE Id IN :criteriaIds]);

        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteria = new Map<Id, List<GridCriteriaDetail__c>>();
        for (GridCriteriaDetail__c d : [SELECT Id, GridCriteria__c, FilterNumber__c, TECHPythonFilter__c
                                        FROM GridCriteriaDetail__c
                                        WHERE GridCriteria__c IN :criteriaIds
                                        ORDER BY FilterNumber__c ASC NULLS LAST]) {
            if (!detailsByCriteria.containsKey(d.GridCriteria__c)) {
                detailsByCriteria.put(d.GridCriteria__c, new List<GridCriteriaDetail__c>());
            }
            detailsByCriteria.get(d.GridCriteria__c).add(d);
        }

        List<GridCriteria__c> toUpdate = new List<GridCriteria__c>();
        for (Id cId : criteriaIds) {
            GridCriteria__c criteria = criteriaMap.get(cId);
            if (criteria == null) continue;

            List<GridCriteriaDetail__c> details = detailsByCriteria.containsKey(cId) ? detailsByCriteria.get(cId) : new List<GridCriteriaDetail__c>();

            criteria.TECHPythonExpression__c = buildPythonExpression(criteria, details);
            toUpdate.add(criteria);
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ─── Private ─────────────────────────────────────────────────────────────
    private static String buildPythonExpression(GridCriteria__c criteria, List<GridCriteriaDetail__c> details) {
        if (details.isEmpty()) return null;

        String logic = criteria.FilterLogic__c;

        // Collect non-null filters in order
        List<String> filters = new List<String>();
        Map<Integer, String> filterByNumber = new Map<Integer, String>();
        for (GridCriteriaDetail__c d : details) {
            if (String.isBlank(d.TECHPythonFilter__c)) continue;
            filters.add(d.TECHPythonFilter__c);
            if (d.FilterNumber__c != null) {
                filterByNumber.put(d.FilterNumber__c.intValue(), d.TECHPythonFilter__c);
            }
        }

        if (filters.isEmpty()) return null;

        if (logic == 'AND') {
            return String.join(filters, '&');
        }
        else if (logic == 'OR') {
            return String.join(filters, '|');
        }
        else if (logic == 'Custom Logic') {
            String expr = criteria.FilterLogicExpression__c;
            if (String.isBlank(expr)) return null;
            for (Integer num : filterByNumber.keySet()) {
                expr = expr.replace(String.valueOf(num), '~F' + num + '~');
            }
            for (Integer num : filterByNumber.keySet()) {
                expr = expr.replace('~F' + num + '~', filterByNumber.get(num));
            }
            return expr.replace(' AND ', '&').replace(' OR ', '|');
        }
        return null;
    }
}