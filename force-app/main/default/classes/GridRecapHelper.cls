/** ──────────────────────────────────────
 * @description Shared helper for building Standard Grid group data from GridDetail__c records.
 *              Used by AgreementGridRecapController (products only) and
 *              StandardGridProductAndRulesController (products + hover data).
 * @author Charles EID
 *  Test Class: StdGridProductAndRulesControllerTest
 * Coverage: 100%   [10-03-26]
────────────────────────────────────── */
public with sharing class GridRecapHelper {

    /**
     * @description Builds a list of StandardGridGroup objects from GridDetail__c records for a given Grid.
     * @param gridId           The Id of the Grid__c record.
     * @param includeHoverData When true, populates hoverData on each group (legal forms + rules).
     */
    public static List<StandardGridGroup> buildStandardGridGroups(Id gridId, Boolean includeHoverData) {
        List<StandardGridGroup> result                  = new List<StandardGridGroup>();
        Map<Id, StandardGridGroup> groupById            = new Map<Id, StandardGridGroup>();
        Map<Id, Map<String, ProductEntry>> productById  = new Map<Id, Map<String, ProductEntry>>();
        Map<Id, Map<Id, RuleEntry>> ruleMap             = new Map<Id, Map<Id, RuleEntry>>();
        Set<Id> standardGridIds                         = new Set<Id>();

        for (GridDetail__c gd : [SELECT StandardGridDetail__c, StandardGridDetail__r.Grid__c, StandardGridDetail__r.Grid__r.Name,
                                        StandardGridDetail__r.ShareClass__r.Fund__c, StandardGridDetail__r.ShareClass__r.Fund__r.InternalShortName__c,
                                        StandardGridDetail__r.ShareClass__r.Name__c, StandardGridDetail__r.RebateRate__c
                                 FROM GridDetail__c
                                 WHERE Grid__c = :gridId
                                 AND StandardGridDetail__c != null
                                 AND StandardGridDetail__r.ShareClass__r.Fund__c != null
                                 ORDER BY StandardGridDetail__r.Grid__r.Name, StandardGridDetail__r.ShareClass__r.Fund__r.InternalShortName__c, StandardGridDetail__r.ShareClass__r.Name__c]) {
            Id sgId          = gd.StandardGridDetail__r.Grid__c;
            String sgName    = gd.StandardGridDetail__r.Grid__r.Name;
            String shortName = gd.StandardGridDetail__r.ShareClass__r.Fund__r.InternalShortName__c;
            String prodRef   = String.isNotBlank(shortName) ? shortName : gd.StandardGridDetail__r.ShareClass__r.Fund__c;
            String scName    = gd.StandardGridDetail__r.ShareClass__r.Name__c;

            // ── Group ──
            if (!groupById.containsKey(sgId)) {
                groupById.put(sgId, new StandardGridGroup(sgName, sgId));
                productById.put(sgId, new Map<String, ProductEntry>());
                result.add(groupById.get(sgId));
            }
            // ── Product entry ──
            Map<String, ProductEntry> productsForGroup = productById.get(sgId);
            if (!productsForGroup.containsKey(prodRef)) {
                ProductEntry entry = new ProductEntry(prodRef);
                productsForGroup.put(prodRef, entry);
                groupById.get(sgId).products.add(entry);
            }
            productsForGroup.get(prodRef).shareClassRates.put(scName, gd.StandardGridDetail__r.RebateRate__c);
            standardGridIds.add(sgId);
        }

        if (includeHoverData) {
            processHoverData(standardGridIds, ruleMap);
            assembleHoverData(result, ruleMap);
        }
        return result;
    }

    // ── Phase 1: query GridRule__c directly and build RuleEntries with IN/NOT IN criteria and per-rule legal forms ──
    private static void processHoverData(Set<Id> standardGridIds, Map<Id, Map<Id, RuleEntry>> ruleMap) {
        List<GridRule__c> gridRules = [SELECT Id, Name, Grid__c, ShareType__c, RuleToApply__c, GridRate__c, OtherShareType__c, OtherGridRule__c, GridCriteria__c
                                       FROM GridRule__c
                                       WHERE Grid__c IN :standardGridIds
                                       ORDER BY ShareType__c, RuleToApply__c];
        Set<Id> criteriaIds = new Set<Id>();
        for (GridRule__c gr : gridRules) {
            if (gr.GridCriteria__c != null) criteriaIds.add(gr.GridCriteria__c);
        }
        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteria  = new Map<Id, List<GridCriteriaDetail__c>>();
        Map<Id, Set<String>>                 legalFormsByCriteria = new Map<Id, Set<String>>();
        Set<String> targetFields = new Set<String>{'InternalShortName__c', 'Legal_Status__c'};
        for (GridCriteriaDetail__c cd : [SELECT GridCriteria__c, Logic__c, Field__c, Value__c
                                          FROM GridCriteriaDetail__c
                                          WHERE GridCriteria__c IN :criteriaIds
                                          AND Field__c IN :targetFields]) {
            if (cd.Field__c == 'InternalShortName__c') {
                if (!detailsByCriteria.containsKey(cd.GridCriteria__c)) {
                    detailsByCriteria.put(cd.GridCriteria__c, new List<GridCriteriaDetail__c>());
                }
                detailsByCriteria.get(cd.GridCriteria__c).add(cd);
            }
            if (cd.Field__c == 'Legal_Status__c' && String.isNotBlank(cd.Value__c)) {
                if (!legalFormsByCriteria.containsKey(cd.GridCriteria__c)) {
                    legalFormsByCriteria.put(cd.GridCriteria__c, new Set<String>());
                }
                for (String val : cd.Value__c.split(';')) {
                    String trimmed = val.trim();
                    if (String.isNotBlank(trimmed)) legalFormsByCriteria.get(cd.GridCriteria__c).add(trimmed);
                }
            }
        }
        for (GridRule__c gr : gridRules) {
            if (!ruleMap.containsKey(gr.Grid__c)) {
                ruleMap.put(gr.Grid__c, new Map<Id, RuleEntry>());
            }
            RuleEntry re = new RuleEntry(gr.ShareType__c, gr.RuleToApply__c, gr.GridRate__c, gr.OtherShareType__c, gr.OtherGridRule__c);
            if (gr.GridCriteria__c != null && legalFormsByCriteria.containsKey(gr.GridCriteria__c)) {
                re.legalForms.addAll(legalFormsByCriteria.get(gr.GridCriteria__c));
            }
            List<GridCriteriaDetail__c> details = detailsByCriteria.get(gr.GridCriteria__c);
            if (details != null) {
                for (GridCriteriaDetail__c cd : details) {
                    if (String.isNotBlank(cd.Value__c)) {
                        if (cd.Logic__c == 'NOT IN' || cd.Logic__c == '!=') {
                            re.notInCriteria.add(cd.Value__c);
                        } else if (cd.Logic__c == 'IN' || cd.Logic__c == '=') {
                            re.inCriteria.add(cd.Value__c);
                        }
                    }
                }
            }
            ruleMap.get(gr.Grid__c).put(gr.Id, re);
        }
    }

    // ── Attach rules onto each group's hoverData ──
    private static void assembleHoverData(List<StandardGridGroup> result, Map<Id, Map<Id, RuleEntry>> ruleMap) {
        for (StandardGridGroup g : result) {
            StandardGridHoverData hd = new StandardGridHoverData();
            if (ruleMap.containsKey(g.gridId)) {
                hd.rules.addAll(ruleMap.get(g.gridId).values());
            }
            g.hoverData = hd;
        }
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class StandardGridGroup {
        @AuraEnabled public String gridName                 { get; set; }
        @AuraEnabled public Id gridId                       { get; set; }
        @AuraEnabled public List<ProductEntry> products     { get; set; }
        @AuraEnabled public StandardGridHoverData hoverData { get; set; }
        public StandardGridGroup(String name, Id id) {
            this.gridName  = name;
            this.gridId    = id;
            this.products  = new List<ProductEntry>();
            this.hoverData = null;
        }
    }

    public class ProductEntry {
        @AuraEnabled public String shortName                     { get; set; }
        @AuraEnabled public Map<String, Decimal> shareClassRates { get; set; }
        public ProductEntry(String shortName) {
            this.shortName       = shortName;
            this.shareClassRates = new Map<String, Decimal>();
        }
    }

    public class StandardGridHoverData {
        @AuraEnabled public List<RuleEntry> rules { get; set; }
        public StandardGridHoverData() {
            this.rules = new List<RuleEntry>();
        }
    }

    public class RuleEntry {
        @AuraEnabled public String shareType                { get; set; }
        @AuraEnabled public List<String> legalForms         { get; set; }
        @AuraEnabled public List<String> inCriteria         { get; set; }
        @AuraEnabled public List<String> notInCriteria      { get; set; }
        @AuraEnabled public String ruleToApply              { get; set; }
        @AuraEnabled public Decimal gridRate                { get; set; }
        @AuraEnabled public String otherShareType           { get; set; }
        @AuraEnabled public String otherGridRule            { get; set; }
        public RuleEntry(String shareType, String ruleToApply, Decimal gridRate, String otherShareType, String otherGridRule) {
            this.shareType      = String.isNotBlank(shareType) ? shareType : 'All Types';
            this.ruleToApply    = ruleToApply;
            this.gridRate       = gridRate;
            this.otherShareType = otherShareType;
            this.otherGridRule  = otherGridRule;
            this.legalForms     = new List<String>();
            this.inCriteria     = new List<String>();
            this.notInCriteria  = new List<String>();
        }
    }
}