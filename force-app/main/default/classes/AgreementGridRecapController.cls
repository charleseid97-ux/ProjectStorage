/** ──────────────────────────────────────
 * @description Controller for the agreementGridRecap LWC.
 *             Returns: 1- the active Grid recap for a given Agreement (Convention__c), including Grid Name, Automatic Grid Update flag,
 *                          and the list of products grouped by their source Standard Grid (from GridDetail__c).
 *                      2- the agreement grid history records (past grid records)
 * @author Charles EID
 * Test Class: AgreementGridRecapControllerTest 
 * Coverage: 100%   [27-02-26]
────────────────────────────────────── */
public with sharing class AgreementGridRecapController {

    @AuraEnabled(cacheable=true)
    public static RecapWrapper getRecap(Id agreementId) {
        // Get the agreement and its active grid
        Convention__c agreement = [SELECT Id, Grid__c, Grid__r.Name, Grid__r.AutomaticGridUpdate__c
                                   FROM Convention__c
                                   WHERE Id = :agreementId LIMIT 1];

        RecapWrapper result = new RecapWrapper();

        // Grid history (always loaded, regardless of active grid)
        for (Agreement_Grid_History__c h : [SELECT Id, Name, Grid__c, Grid__r.Name, Grid_Start_Date__c, Grid_End_Date__c
                                            FROM Agreement_Grid_History__c
                                            WHERE Agreement__c = :agreementId
                                            ORDER BY Grid_Start_Date__c DESC NULLS FIRST]) {
            result.historyRows.add(new HistoryRow(h));
        }

        if (agreement.Grid__c == null)  return result; // no active grid — history still returned

        result.hasGrid = true;
        result.gridId = agreement.Grid__c;
        result.gridName = agreement.Grid__r.Name;
        result.automaticGridUpdate = agreement.Grid__r.AutomaticGridUpdate__c;
        result.standardGridGroups = GridRecapHelper.buildStandardGridGroups(agreement.Grid__c, true);

        return result;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class RecapWrapper {
        @AuraEnabled public Boolean hasGrid { get; set; }
        @AuraEnabled public Id gridId { get; set; }
        @AuraEnabled public String gridName { get; set; }
        @AuraEnabled public Boolean automaticGridUpdate { get; set; }
        @AuraEnabled public List<GridRecapHelper.StandardGridGroup> standardGridGroups { get; set; }
        @AuraEnabled public List<HistoryRow> historyRows { get; set; }
        public RecapWrapper() {
            this.hasGrid = false;
            this.standardGridGroups = new List<GridRecapHelper.StandardGridGroup>();
            this.historyRows = new List<HistoryRow>();
        }
    }

    public class HistoryRow {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String historyName { get; set; }
        @AuraEnabled public Id gridId { get; set; }
        @AuraEnabled public String gridName { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        public HistoryRow(Agreement_Grid_History__c h) {
            this.recordId = h.Id;
            this.historyName = h.Name;
            this.gridId = h.Grid__c;
            this.gridName = h.Grid__r?.Name;
            this.startDate = h.Grid_Start_Date__c;
            this.endDate = h.Grid_End_Date__c;
        }
    }
}