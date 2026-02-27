/** ──────────────────────────────────────
 * @description Shared helper for building Standard Grid group data from GridDetail__c records.
 *              Used by AgreementGridRecapController (products only) and
 *              StandardGridProductAndRulesController (products + hover data).
 * @author Charles EID
 *  Test Class: StdGridProductAndRulesControllerTest
 * Coverage: 100%   [27-02-26]
────────────────────────────────────── */
public with sharing class GridRecapHelper {
    private static final String RULE_OGR = 'Take Rebates Rate - Other Grid Rule';

    /**
     * @description Builds a list of StandardGridGroup objects from GridDetail__c records for a given Grid.
     * @param gridId           The Id of the Grid__c record.
     * @param includeHoverData When true, populates hoverData on each group (legal forms + rules).
     */
    public static List<StandardGridGroup> buildStandardGridGroups(Id gridId, Boolean includeHoverData) {
        List<StandardGridGroup> result                         = new List<StandardGridGroup>();
        Map<Id, StandardGridGroup> groupById                   = new Map<Id, StandardGridGroup>();
        Map<Id, Map<String, ProductEntry>> productById         = new Map<Id, Map<String, ProductEntry>>();
        Map<Id, Set<String>> legalForms                        = new Map<Id, Set<String>>();
        Map<Id, Map<Id, RuleEntry>> ruleMap                    = new Map<Id, Map<Id, RuleEntry>>();
        Map<String, Set<Id>> scIdsByCompKey                    = new Map<String, Set<Id>>();
        Map<String, Map<Id, Id>> placeholderBySgIdByScOtherKey = new Map<String, Map<Id, Id>>();

        for (GridDetail__c gd : [SELECT StandardGridDetail__c, StandardGridDetail__r.Grid__c, StandardGridDetail__r.Grid__r.Name, StandardGridDetail__r.ShareClass__c, StandardGridDetail__r.ShareClass__r.Fund__c,
                                        StandardGridDetail__r.ShareClass__r.Fund__r.InternalShortName__c, StandardGridDetail__r.ShareClass__r.Fund__r.LegalForm__c, StandardGridDetail__r.ShareClass__r.Name__c,
                                        StandardGridDetail__r.ShareClass__r.Type__c, StandardGridDetail__r.RebateRate__c, StandardGridDetail__r.GridRule__c, StandardGridDetail__r.GridRule__r.RuleToApply__c,
                                        StandardGridDetail__r.GridRule__r.GridRate__c, StandardGridDetail__r.GridRule__r.OtherShareType__c, StandardGridDetail__r.GridRule__r.OtherGridRule__c
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

            if (includeHoverData) {
                processHoverDataRow(gd, sgId, shortName, legalForms, ruleMap, scIdsByCompKey, placeholderBySgIdByScOtherKey);
            }
        }

        if (includeHoverData && !scIdsByCompKey.isEmpty()) {
            resolveOtherGridRules(scIdsByCompKey, placeholderBySgIdByScOtherKey, ruleMap);
        }
        if (includeHoverData) {
            assembleHoverData(result, legalForms, ruleMap);
        }
        return result;
    }

    // ── Hover data for one GridDetail row: legal form + rule dispatch ──
    private static void processHoverDataRow(GridDetail__c gd, Id sgId, String shortName, Map<Id, Set<String>> legalForms, Map<Id, Map<Id, RuleEntry>> ruleMap, Map<String, Set<Id>> scIdsByCompKey, Map<String, Map<Id, Id>> placeholderBySgIdByScOtherKey) {
        if (!legalForms.containsKey(sgId)) {
            legalForms.put(sgId, new Set<String>());
        }
        String fundLegalForm = gd.StandardGridDetail__r.ShareClass__r.Fund__r.LegalForm__c;
        if (String.isNotBlank(fundLegalForm)) {
            legalForms.get(sgId).add(fundLegalForm);
        }
        Id ruleId = gd.StandardGridDetail__r.GridRule__c;
        if (ruleId == null) return;
        if (!ruleMap.containsKey(sgId)) {
            ruleMap.put(sgId, new Map<Id, RuleEntry>());
        }
        String ruleToApply = gd.StandardGridDetail__r.GridRule__r.RuleToApply__c;
        String otherGR     = gd.StandardGridDetail__r.GridRule__r.OtherGridRule__c;
        processGridRuleDetails(ruleMap.get(sgId), ruleId, gd.StandardGridDetail__r.ShareClass__r.Type__c, ruleToApply, gd.StandardGridDetail__r.GridRule__r.GridRate__c, gd.StandardGridDetail__r.GridRule__r.OtherShareType__c, otherGR, shortName);
        trackOgrEntry(gd.StandardGridDetail__r.ShareClass__c, sgId, ruleId, ruleToApply, otherGR, scIdsByCompKey, placeholderBySgIdByScOtherKey);
    }

    // ── Phase-2 tracking: record share classes that need OtherGridRule resolution ──
    private static void trackOgrEntry(Id scId, Id sgId, Id ruleId, String ruleToApply, String otherGR, Map<String, Set<Id>> scIdsByCompKey, Map<String, Map<Id, Id>> placeholderBySgIdByScOtherKey) {
        if (ruleToApply != RULE_OGR || String.isBlank(otherGR) || scId == null) return;
        String compKey    = sgId + '|' + otherGR;
        String scOtherKey = scId + '|' + otherGR;
        if (!scIdsByCompKey.containsKey(compKey)) {
            scIdsByCompKey.put(compKey, new Set<Id>());
        }
        scIdsByCompKey.get(compKey).add(scId);
        if (!placeholderBySgIdByScOtherKey.containsKey(scOtherKey)) {
            placeholderBySgIdByScOtherKey.put(scOtherKey, new Map<Id, Id>());
        }
        placeholderBySgIdByScOtherKey.get(scOtherKey).put(sgId, ruleId);
    }

    // ── Phase 2: query the referenced grids and resolve placeholder RuleEntries ──
    private static void resolveOtherGridRules(Map<String, Set<Id>> scIdsByCompKey, Map<String, Map<Id, Id>> placeholderBySgIdByScOtherKey, Map<Id, Map<Id, RuleEntry>> ruleMap) {
        Set<String> otherGridNames = new Set<String>();
        for (String ck : scIdsByCompKey.keySet()) {
            otherGridNames.add(ck.substringAfter('|'));
        }
        Map<String, Id> gridIdByName = new Map<String, Id>();
        for (Grid__c g : [SELECT Id, Name FROM Grid__c WHERE Name IN :otherGridNames]) {
            gridIdByName.put(g.Name, g.Id);
        }
        Set<Id> allScIds = new Set<Id>();
        for (Set<Id> scs : scIdsByCompKey.values()) {
            allScIds.addAll(scs);
        }
        for (GridDetail__c rgd : [SELECT ShareClass__c, Grid__r.Name, GridRule__c,
                                         GridRule__r.RuleToApply__c, GridRule__r.GridRate__c, GridRule__r.OtherShareType__c
                                  FROM GridDetail__c
                                  WHERE RecordType.DeveloperName = :GridBuilderHelper.RT_STANDARD_GRID_DETAIL
                                  AND Grid__c IN :new Set<Id>(gridIdByName.values())
                                  AND ShareClass__c IN :allScIds
                                  AND GridRule__c != null]) {
            Map<Id, Id> sgToPlaceholder = placeholderBySgIdByScOtherKey.get(rgd.ShareClass__c + '|' + rgd.Grid__r.Name);
            if (sgToPlaceholder == null) continue;
            applyResolutionToPlaceholder(sgToPlaceholder, ruleMap, rgd);
        }
    }

    // ── Apply resolved rule data onto each matching placeholder RuleEntry ──
    private static void applyResolutionToPlaceholder(Map<Id, Id> sgToPlaceholder, Map<Id, Map<Id, RuleEntry>> ruleMap, GridDetail__c rgd) {
        for (Id sgId : sgToPlaceholder.keySet()) {
            Map<Id, RuleEntry> rulesForGrid = ruleMap.get(sgId);
            if (rulesForGrid == null) continue;
            RuleEntry placeholder = rulesForGrid.get(sgToPlaceholder.get(sgId));
            if (placeholder == null || placeholder.resolvedRuleToApply != null) continue;
            placeholder.resolvedRuleToApply    = rgd.GridRule__r.RuleToApply__c;
            placeholder.resolvedGridRate       = rgd.GridRule__r.GridRate__c;
            placeholder.resolvedOtherShareType = rgd.GridRule__r.OtherShareType__c;
        }
    }

    // ── Attach accumulated legal forms and rules onto each group's hoverData ──
    private static void assembleHoverData(List<StandardGridGroup> result, Map<Id, Set<String>> legalForms, Map<Id, Map<Id, RuleEntry>> ruleMap) {
        for (StandardGridGroup g : result) {
            StandardGridHoverData hd = new StandardGridHoverData();
            if (legalForms.containsKey(g.gridId)) {
                hd.legalForms.addAll(legalForms.get(g.gridId));
            }
            if (ruleMap.containsKey(g.gridId)) {
                hd.rules.addAll(ruleMap.get(g.gridId).values());
            }
            g.hoverData = hd;
        }
    }

    private static void processGridRuleDetails(Map<Id, RuleEntry> rulesForGrid, Id ruleId, String shareType, String ruleToApply, Decimal gridRate, String otherShareType, String otherGridRule, String shortName) {
        if (!rulesForGrid.containsKey(ruleId)) {
            rulesForGrid.put(ruleId, new RuleEntry(shareType, ruleToApply, gridRate, otherShareType, otherGridRule));
        }
        RuleEntry re = rulesForGrid.get(ruleId);
        if (String.isNotBlank(shortName) && !re.internalShortNames.contains(shortName)) {
            re.internalShortNames.add(shortName);
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
        @AuraEnabled public List<String> legalForms { get; set; }
        @AuraEnabled public List<RuleEntry> rules   { get; set; }
        public StandardGridHoverData() {
            this.legalForms = new List<String>();
            this.rules      = new List<RuleEntry>();
        }
    }

    public class RuleEntry {
        @AuraEnabled public String shareType                { get; set; }
        @AuraEnabled public List<String> internalShortNames { get; set; }
        @AuraEnabled public String ruleToApply              { get; set; }
        @AuraEnabled public Decimal gridRate                { get; set; }
        @AuraEnabled public String otherShareType           { get; set; }
        @AuraEnabled public String otherGridRule            { get; set; }
        @AuraEnabled public String resolvedRuleToApply      { get; set; }
        @AuraEnabled public Decimal resolvedGridRate        { get; set; }
        @AuraEnabled public String resolvedOtherShareType   { get; set; }
        public RuleEntry(String shareType, String ruleToApply, Decimal gridRate, String otherShareType, String otherGridRule) {
            this.shareType          = shareType;
            this.ruleToApply        = ruleToApply;
            this.gridRate           = gridRate;
            this.otherShareType     = otherShareType;
            this.otherGridRule      = otherGridRule;
            this.internalShortNames = new List<String>();
        }
    }
}