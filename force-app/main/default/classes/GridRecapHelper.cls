/** ──────────────────────────────────────
 * @description Shared helper for building Standard Grid group data from GridDetail__c records.
 *              Used by AgreementGridRecapController (products only) and
 *              StandardGridProductAndRulesController (products + hover data).
 *              Hover data is sourced from StandardGridRecapConfig__mdt / StandardGridRecapRule__mdt
 *              custom metadata types (admin-editable via Setup UI).
 * @author Charles EID
 * @coverage 100%   [19-03-26]
────────────────────────────────────── */
public with sharing class GridRecapHelper {

    /**
     * @description Builds a list of StandardGridGroup objects from GridDetail__c records for a given Grid.
     * @param gridId           The Id of the Grid__c record.
     * @param includeHoverData When true, populates hoverData on each group from StandardGridRecapRule__mdt.
     */
    public static List<StandardGridGroup> buildStandardGridGroups(Id gridId, Boolean includeHoverData) {
        List<StandardGridGroup> result                  = new List<StandardGridGroup>();
        Map<Id, StandardGridGroup> groupById            = new Map<Id, StandardGridGroup>();
        Map<Id, Map<String, ProductEntry>> productById  = new Map<Id, Map<String, ProductEntry>>();
        Map<Id, List<RuleEntry>> ruleMap                = new Map<Id, List<RuleEntry>>();

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
        }

        if (includeHoverData) {
            processHoverData(result, ruleMap);
            assembleHoverData(result, ruleMap);
        }
        return result;
    }

    // ── Phase 1: query StandardGridRecapRule__mdt and build RuleEntries ──
    // Two flat queries are used intentionally — Salesforce CMT parent-child subqueries
    // only return 1 child record per parent when the outer query returns multiple parents.
    private static void processHoverData(List<StandardGridGroup> groups, Map<Id, List<RuleEntry>> ruleMap) {
        Map<String, Id> gridIdByName = new Map<String, Id>();
        for (StandardGridGroup gridGroup : groups) {
            gridIdByName.put(gridGroup.gridName, gridGroup.gridId);
        }

        // Step 1 — resolve config record IDs for the matching grid names
        Map<Id, Id> gridIdByConfigId = new Map<Id, Id>();
        for (StandardGridRecapConfig__mdt gridConfig : [SELECT Id, StandardGridName__c
                                                        FROM StandardGridRecapConfig__mdt
                                                        WHERE StandardGridName__c IN :gridIdByName.keySet()]) {
            Id gridId = gridIdByName.get(gridConfig.StandardGridName__c);
            if (gridId != null) {
                gridIdByConfigId.put(gridConfig.Id, gridId);
            }
        }

        // Step 2 — flat query on all rules, ordered, grouped into ruleMap by standard grid ID
        for (StandardGridRecapRule__mdt rule : [SELECT ShareType__c, InternalShortName__c, Rule__c, Value__c, Style__c, SortOrder__c, StandardGridConfig__c
                                                FROM StandardGridRecapRule__mdt
                                                WHERE StandardGridConfig__c IN :gridIdByConfigId.keySet()
                                                ORDER BY SortOrder__c]) {
            Id gridId = gridIdByConfigId.get(rule.StandardGridConfig__c);
            if (gridId == null) continue;
            if (!ruleMap.containsKey(gridId)) {
                ruleMap.put(gridId, new List<RuleEntry>());
            }
            String formattedValue = rule.Value__c != null ? GridBuilderHelper.formatPercent(rule.Value__c) : '';
            String ruleText       = rule.Rule__c.replace('{_}', formattedValue);
            ruleMap.get(gridId).add(new RuleEntry(rule.ShareType__c, rule.InternalShortName__c, ruleText, rule.Style__c));
        }
    }

    // ── Phase 2: attach rules onto each group's hoverData ──
    private static void assembleHoverData(List<StandardGridGroup> result, Map<Id, List<RuleEntry>> ruleMap) {
        for (StandardGridGroup gridGroup : result) {
            StandardGridHoverData hoverData = new StandardGridHoverData();
            if (ruleMap.containsKey(gridGroup.gridId)) {
                hoverData.rules.addAll(ruleMap.get(gridGroup.gridId));
            }
            gridGroup.hoverData = hoverData;
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
        @AuraEnabled public String shareType         { get; set; }
        @AuraEnabled public String internalShortName { get; set; }
        @AuraEnabled public String ruleText          { get; set; }
        @AuraEnabled public String style             { get; set; }
        public RuleEntry(String shareType, String internalShortName, String ruleText, String style) {
            this.shareType         = shareType;
            this.internalShortName = internalShortName;
            this.ruleText          = ruleText;
            this.style             = style;
        }
    }
}