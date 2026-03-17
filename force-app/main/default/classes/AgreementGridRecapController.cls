/** ──────────────────────────────────────
 * @description Controller for the agreementGridRecap LWC.
 *             Returns: 1- the active Grid recap for a given Agreement (Convention__c), including Grid Name, Automatic Grid Update flag,
 *                          and the list of products grouped by their source Standard Grid (from GridDetail__c).
 *                      2- the agreement grid timeline records (past grid records)
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

        // Grid timeline (always loaded, regardless of active grid)
        for (AgreementGridTimeline__c agt : [SELECT Id, Name, Grid__c, Grid__r.Name, GridStartDate__c, GridEndDate__c
                                            FROM AgreementGridTimeline__c
                                            WHERE Agreement__c = :agreementId
                                            ORDER BY GridStartDate__c DESC NULLS FIRST]) {
            result.timelineRows.add(new TimelineRow(agt));
        }

        if (agreement.Grid__c == null)  return result; // no active grid — timeline still returned

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
        @AuraEnabled public List<TimelineRow> timelineRows { get; set; }
        public RecapWrapper() {
            this.hasGrid = false;
            this.standardGridGroups = new List<GridRecapHelper.StandardGridGroup>();
            this.timelineRows = new List<TimelineRow>();
        }
    }

    public class TimelineRow {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String timelineName { get; set; }
        @AuraEnabled public Id gridId { get; set; }
        @AuraEnabled public String gridName { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        public TimelineRow(AgreementGridTimeline__c agt) {
            this.recordId = agt.Id;
            this.timelineName = agt.Name;
            this.gridId = agt.Grid__c;
            this.gridName = agt.Grid__r?.Name;
            this.startDate = agt.GridStartDate__c;
            this.endDate = agt.GridEndDate__c;
        }
    }
}