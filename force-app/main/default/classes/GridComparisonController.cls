/** ──────────────────────────────────────
 * @description Controller for the GridComparison LWC.
 *              Provides search methods for grids and agreements, and fetches
 *              comparison data by delegating to GridDetailTableController.getGridDetails().
 * @author Charles EID
 * @testClass GridComparisonControllerTest
 * @coverage 100%   [20-03-26]
────────────────────────────────────── */
public with sharing class GridComparisonController {

    @AuraEnabled(cacheable=true)
    public static List<LookupResult> searchGrids(String searchTerm, Id currentGridId) {
        String term = '%' + (String.isBlank(searchTerm) ? '' : String.escapeSingleQuotes(searchTerm.trim())) + '%';
        List<LookupResult> results = new List<LookupResult>();
        for (Grid__c g : [SELECT Id, Name, RecordType.Name
                          FROM Grid__c
                          WHERE Name LIKE :term
                          AND Id != :currentGridId
                          AND ((RecordType.DeveloperName = 'StandardGrid' AND ActiveGrid__c = true)
                            OR (RecordType.DeveloperName = 'CustomGrid' AND ApprovalStatus__c = 'Approved'))
                          ORDER BY Name LIMIT 500]) {
            results.add(new LookupResult(g.Id, g.Name, g.RecordType.Name));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupResult> searchAgreements(String searchTerm) {
        String term = '%' + (String.isBlank(searchTerm) ? '' : String.escapeSingleQuotes(searchTerm.trim())) + '%';
        List<LookupResult> results = new List<LookupResult>();
        for (Convention__c agr : [SELECT Id, Name, Grid__r.Name
                                  FROM Convention__c
                                  WHERE Name LIKE :term
                                  AND Grid__c != null
                                  AND Grid__r.ApprovalStatus__c = 'Approved'
                                  ORDER BY Name LIMIT 500]) {
            results.add(new LookupResult(agr.Id, agr.Name, agr.Grid__r.Name));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Id getGridFromAgreement(Id agreementId) {
        if (agreementId == null) return null;
        Convention__c agr = [SELECT Grid__c FROM Convention__c WHERE Id = :agreementId LIMIT 1];
        return agr.Grid__c;
    }

    @AuraEnabled(cacheable=true)
    public static ComparisonData getComparisonData(Id currentGridId, Id selectedGridId) {
        ComparisonData data = new ComparisonData();
        data.current  = GridDetailTableController.getGridDetails(currentGridId);
        data.selected = GridDetailTableController.getGridDetails(selectedGridId);
        return data;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class LookupResult {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String subtitle;
        public LookupResult(Id id, String name, String subtitle) {
            this.id       = id;
            this.name     = name;
            this.subtitle = subtitle;
        }
    }

    public class ComparisonData {
        @AuraEnabled public GridDetailTableController.GridDetailResult current;
        @AuraEnabled public GridDetailTableController.GridDetailResult selected;
    }
}