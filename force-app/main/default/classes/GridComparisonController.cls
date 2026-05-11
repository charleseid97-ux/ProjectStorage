/** ──────────────────────────────────────
 * @description Controller for the GridComparison LWC.
 *              Provides search methods for grids and agreements, and fetches
 *              comparison data by delegating to GridDetailTableController.getGridDetails().
 * @author Charles EID
 * @testClass GridComparisonControllerTest
 * @coverage 100%   [20-03-26]
────────────────────────────────────── */
public with sharing class GridComparisonController {

    private static final String ACTIVE_GRID_STATUS_IS_CURRENT = 'IS_CURRENT';
    private static final String ACTIVE_GRID_STATUS_NONE       = 'NONE';
    private static final String ACTIVE_GRID_STATUS_HAS_ACTIVE = 'HAS_ACTIVE';

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

        String rtStandard = GridBuilderHelper.RT_STANDARD_GRID;
        String rtCustom   = GridBuilderHelper.RT_CUSTOM_GRID;

        for (Grid__c g : [SELECT Id, Name, RecordType.DeveloperName, RecordType.Name, ActiveGrid__c, Tech_SpecificStandardGrid__c, Agreement__c
                          FROM Grid__c
                          WHERE Name LIKE :term
                            AND Id != :currentGridId
                            AND (RecordType.DeveloperName = :rtStandard OR RecordType.DeveloperName = :rtCustom)
                          ORDER BY Name LIMIT 600]) {
            if (g.RecordType.DeveloperName == rtStandard) {
                if (g.ActiveGrid__c && !g.Tech_SpecificStandardGrid__c) {
                    group1.add(new LookupResult(g.Id, g.Name, null, null));
                }
                // Tech_SpecificStandardGrid__c = true → hidden
            } else {
                if (currentAgreementId != null && g.Agreement__c == currentAgreementId) {
                    group2.add(new LookupResult(g.Id, g.Name, currentAgreementName, null));
                } else {
                    group3.add(new LookupResult(g.Id, g.Name, g.RecordType.Name, null));
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
        for (Convention__c agr : [SELECT Id, Name, Grid__c, Grid__r.Name
                                  FROM Convention__c
                                  WHERE Name LIKE :term
                                  AND Grid__c != null
                                  AND Grid__r.RecordType.DeveloperName = :GridBuilderHelper.RT_CUSTOM_GRID
                                  ORDER BY Name LIMIT 500]) {
            results.add(new LookupResult(agr.Id, agr.Name, agr.Grid__r.Name, agr.Grid__c));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static ActiveGridInfo getActiveGridForCurrentGrid(Id currentGridId) {
        if (currentGridId == null) return new ActiveGridInfo(ACTIVE_GRID_STATUS_NONE, null, null);

        List<Grid__c> cur = [SELECT Agreement__c FROM Grid__c WHERE Id = :currentGridId LIMIT 1];
        if (cur.isEmpty() || cur[0].Agreement__c == null) return new ActiveGridInfo(ACTIVE_GRID_STATUS_NONE, null, null);

        Id agreementId = cur[0].Agreement__c;
        List<Convention__c> agr = [SELECT Grid__c, Grid__r.Name FROM Convention__c WHERE Id = :agreementId LIMIT 1];
        if (agr.isEmpty() || agr[0].Grid__c == null) return new ActiveGridInfo(ACTIVE_GRID_STATUS_NONE, null, null);

        Id activeGridId = agr[0].Grid__c;
        if (activeGridId == currentGridId) return new ActiveGridInfo(ACTIVE_GRID_STATUS_IS_CURRENT, null, null);

        return new ActiveGridInfo(ACTIVE_GRID_STATUS_HAS_ACTIVE, activeGridId, agr[0].Grid__r.Name);
    }

    @AuraEnabled(cacheable=true)
    public static ComparisonData getComparisonData(Id currentGridId, Id selectedGridId) {
        ComparisonData data = new ComparisonData();

        Id currentAgreementId = null;
        String countriesOfDistribution = null;

        if (currentGridId != null) {
            List<Grid__c> cur = [SELECT Agreement__c, Agreement__r.Countries_of_Distribution__c
                                  FROM Grid__c WHERE Id = :currentGridId LIMIT 1];
            if (!cur.isEmpty() && cur[0].Agreement__c != null) {
                currentAgreementId = cur[0].Agreement__c;
                countriesOfDistribution = cur[0].Agreement__r.Countries_of_Distribution__c;
            }
        }

        Set<Id> validShareClassIds = new Set<Id>();
        if (String.isNotBlank(countriesOfDistribution)) {
            GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings('CustomGridBuilderSetting', countriesOfDistribution, false, new List<String>());
            if (gridSettings != null) {
                List<String> conditions = GridBuilderHelper.buildDefaultConditions(true, true, countriesOfDistribution, gridSettings.shareTypeWrp, false, new List<String>());
                String whereClause = String.join(conditions, ' AND ');
                for (Share_Class__c sc : Database.query('SELECT Id FROM Share_Class__c WHERE ' + whereClause)) {
                    validShareClassIds.add(sc.Id);
                }
            }
        }

        data.current  = GridDetailTableController.getGridDetails(currentGridId, true);
        data.selected = GridDetailTableController.getGridDetails(selectedGridId, true, validShareClassIds, currentAgreementId);
        return data;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class ActiveGridInfo {
        @AuraEnabled public String status;       // IS_CURRENT | NONE | HAS_ACTIVE
        @AuraEnabled public Id     activeGridId;
        @AuraEnabled public String activeGridName;
        public ActiveGridInfo(String status, Id activeGridId, String activeGridName) {
            this.status         = status;
            this.activeGridId   = activeGridId;
            this.activeGridName = activeGridName;
        }
    }

    public class LookupResult {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String subtitle;
        @AuraEnabled public Id     gridId;
        public LookupResult(Id id, String name, String subtitle, Id gridId) {
            this.id       = id;
            this.name     = name;
            this.subtitle = subtitle;
            this.gridId   = gridId;
        }
    }

    public class ComparisonData {
        @AuraEnabled public GridDetailTableController.GridDetailResult current;
        @AuraEnabled public GridDetailTableController.GridDetailResult selected;
    }
}