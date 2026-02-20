/**
 * @description Controller for the agreementGridRecap LWC.
 *             Returns: 1- the active Grid recap for a given Agreement (Convention__c), including Grid Name, Automatic Grid Update flag, 
 *                          and the list of products grouped by their source Standard Grid (from GridDetail__c).
 *                      2- the agreement grid history records (past grid records)
 * @author Charles EID
 */
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

        // Group products (with their share classes) by their source standard grid // Outer key = standardGridName, inner key = prodReference → ProductEntry
        Map<String, StandardGridGroup> groupMap = new Map<String, StandardGridGroup>();
        Map<String, Map<String, ProductEntry>> productMap = new Map<String, Map<String, ProductEntry>>();
        String standardGridName, prodReference, shareClassName;
        for (GridDetail__c gd : [SELECT StandardGrid__c, StandardGrid__r.Name,
                                        ShareClass__r.Fund__c, ShareClass__r.Fund__r.InternalShortName__c,
                                        ShareClass__r.Name__c
                                 FROM GridDetail__c
                                 WHERE Grid__c = :agreement.Grid__c
                                 AND StandardGrid__c != null
                                 AND ShareClass__r.Fund__c != null
                                 ORDER BY StandardGrid__r.Name, ShareClass__r.Fund__r.InternalShortName__c, ShareClass__r.Name__c]) {
            standardGridName = gd.StandardGrid__r.Name;
            prodReference    = String.isNotBlank(gd.ShareClass__r.Fund__r.InternalShortName__c) ? gd.ShareClass__r.Fund__r.InternalShortName__c : gd.ShareClass__r.Fund__c;
            shareClassName   = gd.ShareClass__r.Name__c;

            if (!groupMap.containsKey(standardGridName)) {
                StandardGridGroup sgGroup = new StandardGridGroup(standardGridName);
                groupMap.put(standardGridName, sgGroup);
                productMap.put(standardGridName, new Map<String, ProductEntry>());
                result.standardGridGroups.add(sgGroup);
            }
            Map<String, ProductEntry> productsForGroup = productMap.get(standardGridName);
            if (!productsForGroup.containsKey(prodReference)) {
                ProductEntry entry = new ProductEntry(prodReference);
                productsForGroup.put(prodReference, entry);
                groupMap.get(standardGridName).products.add(entry);
            }
            ProductEntry entry = productsForGroup.get(prodReference);
            if (!entry.shareClassNames.contains(shareClassName)) entry.shareClassNames.add(shareClassName);
        }

        return result;
    }

    // ------------------------------------ WRAPPERS ------------------------------------
    public class RecapWrapper {
        @AuraEnabled public Boolean hasGrid { get; set; }
        @AuraEnabled public Id gridId { get; set; }
        @AuraEnabled public String gridName { get; set; }
        @AuraEnabled public Boolean automaticGridUpdate { get; set; }
        @AuraEnabled public List<StandardGridGroup> standardGridGroups { get; set; }
        @AuraEnabled public List<HistoryRow> historyRows { get; set; }
        public RecapWrapper() {
            this.hasGrid = false;
            this.standardGridGroups = new List<StandardGridGroup>();
            this.historyRows = new List<HistoryRow>();
        }
    }

    public class StandardGridGroup {
        @AuraEnabled public String gridName { get; set; }
        @AuraEnabled public List<ProductEntry> products { get; set; }
        public StandardGridGroup(String gridName) {
            this.gridName = gridName;
            this.products = new List<ProductEntry>();
        }
    }

    public class ProductEntry {
        @AuraEnabled public String shortName { get; set; }
        @AuraEnabled public List<String> shareClassNames { get; set; }
        public ProductEntry(String shortName) {
            this.shortName = shortName;
            this.shareClassNames = new List<String>();
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