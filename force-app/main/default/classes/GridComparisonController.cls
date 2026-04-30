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

        // Single-record lookup to resolve the current grid's agreement
        Id currentAgreementId       = null;
        String currentAgreementName = null;
        if (currentGridId != null) {
            List<Grid__c> cur = [SELECT Agreement__c, Agreement__r.Name FROM Grid__c WHERE Id = :currentGridId LIMIT 1];
            if (!cur.isEmpty() && cur[0].Agreement__c != null) {
                currentAgreementId   = cur[0].Agreement__c;
                currentAgreementName = cur[0].Agreement__r.Name;
            }
        }

        // Single query — classify into priority groups in-memory
        List<LookupResult> group1 = new List<LookupResult>(); // general standard grids
        List<LookupResult> group2 = new List<LookupResult>(); // same-agreement grids
        List<LookupResult> group3 = new List<LookupResult>(); // other custom grids

        for (Grid__c g : [SELECT Id, Name, RecordType.DeveloperName, RecordType.Name, ActiveGrid__c, Tech_SpecificStandardGrid__c, Agreement__c
                          FROM Grid__c
                          WHERE Name LIKE :term
                            AND Id != :currentGridId
                            AND (RecordType.DeveloperName = 'StandardGrid' OR RecordType.DeveloperName = 'CustomGrid')
                          ORDER BY Name LIMIT 600]) {
            if (g.RecordType.DeveloperName == 'StandardGrid') {
                if (g.ActiveGrid__c && !g.Tech_SpecificStandardGrid__c) {
                    group1.add(new LookupResult(g.Id, g.Name, null));
                }
                // Tech_SpecificStandardGrid__c = true → hidden
            } else {
                if (currentAgreementId != null && g.Agreement__c == currentAgreementId) {
                    group2.add(new LookupResult(g.Id, g.Name, currentAgreementName));
                } else {
                    group3.add(new LookupResult(g.Id, g.Name, g.RecordType.Name));
                }
            }
        }

        List<LookupResult> results = new List<LookupResult>();
        results.addAll(group1);
        results.addAll(group2);
        results.addAll(group3);
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
        data.current  = GridDetailTableController.getGridDetails(currentGridId, true);
        data.selected = GridDetailTableController.getGridDetails(selectedGridId, true);
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