/** ──────────────────────────────────────
 * @description Controller for the standardGridProductsAndRules LWC.
 *              Returns Standard Grid groups (with products and hover data) for a given Grid__c record.
 * @author Charles EID
────────────────────────────────────── */
public with sharing class StandardGridProductAndRulesController {

    @AuraEnabled(cacheable=true)
    public static List<GridRecapHelper.StandardGridGroup> getStandardGridData(Id gridId) {
        return GridRecapHelper.buildStandardGridGroups(gridId, true);
    }
}