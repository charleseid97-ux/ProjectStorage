/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Grid Detail Table display. 
 *              Retrieves and formats GridDetail__c records with associated criteria, rule lines, share class, and AUM data.
 *              Handles agreement selection parsing (ALL, specific IDs, name tokens), calculates net margins,
 *              and formats rule values for display based on rule type.
 * @author Charles EID
 * @testClass GridDetailTableControllerTest
 * @coverage 92%   [19-03-26]
────────────────────────────────────── */
public with sharing class GridDetailTableController {
    private static final String RULE_PERCENTAGE = 'Percentage of Fees';
    private static final String RULE_OTHER_SHARE = 'Take Rebates Rate - Other Share Type';
    private static final String RULE_OTHER_SHARE_FEES = 'Take Rebates Rate - Other Share Type + Fees';
    private static final String RULE_OTHER_GRID = 'Take Rebates Rate - Other Grid Rule';

    @AuraEnabled(cacheable=true)
    public static GridDetailResult getGridDetails(Id gridId) {
        GridDetailResult result = new GridDetailResult();
        result.rows = new List<GridDetailRow>();
        result.errors = new List<String>();

        if (gridId == null) {
            result.errors.add('Grid Id is required.');
            return result;
        }

        Grid__c grid = [SELECT Id, RecordType.DeveloperName FROM Grid__c WHERE Id = :gridId LIMIT 1];
        AgreementSelection agreementSelection = new AgreementSelection();

        // Custom Grid: agreements are those where this grid is set as Grid_Request__c or Grid__c
        if (grid.RecordType.DeveloperName == GridBuilderHelper.RT_CUSTOM_GRID) { 
            for (Convention__c agr : [SELECT Id FROM Convention__c WHERE Grid_Request__c = :gridId OR Grid__c = :gridId]) {
                agreementSelection.agreementIds.add(agr.Id);
            }
        }
        // Standard Grid: use GridScope__c
        else { 
            List<GridScope__c> scopes = [SELECT Agreement__c FROM GridScope__c WHERE Grid__c = :gridId];
            if (scopes.isEmpty()) {
                result.errors.add('No Grid Scope found for this Grid. AUM will be blank.');
            }
            else {
                agreementSelection = parseAgreementSelection(scopes, result);
            }
        }

        List<GridDetail__c> details = [SELECT Id, ShareClass__c, ShareClass__r.Name__c, ShareClass__r.ISIN__c,
                                        ShareClass__r.EffectiveManagementFees__c, ShareClass__r.Fund__r.FundStrategy__r.AssetClass__c, ShareClass__r.Fund__r.FundStrategy__r.Name,
                                        ShareClass__r.Fund__r.LegalForm__c, ShareClass__r.Fund__r.InternalShortName__c, ShareClass__r.Fund__r.ProductName__c,
                                        StandardGridDetail__c, StandardGridDetail__r.ShareClass__c, StandardGridDetail__r.ShareClass__r.Name__c, StandardGridDetail__r.ShareClass__r.ISIN__c, StandardGridDetail__r.ShareClass__r.EffectiveManagementFees__c,
                                        StandardGridDetail__r.ShareClass__r.Fund__r.FundStrategy__r.AssetClass__c, StandardGridDetail__r.ShareClass__r.Fund__r.FundStrategy__r.Name,
                                        StandardGridDetail__r.ShareClass__r.Fund__r.LegalForm__c, StandardGridDetail__r.ShareClass__r.Fund__r.InternalShortName__c,
                                        StandardGridDetail__r.ShareClass__r.Fund__r.ProductName__c, StandardGridDetail__r.RebateRate__c, StandardGridDetail__r.StartDate__c,
                                        StandardGridDetail__r.GridRule__r.RuleToApply__c, StandardGridDetail__r.GridRule__r.GridRate__c,
                                        StandardGridDetail__r.GridRule__r.OtherGridRule__c, StandardGridDetail__r.GridRule__r.OtherShareType__c, StandardGridDetail__r.GridRule__r.FinalRebateRate__c,
                                        GridRule__r.RuleToApply__c, GridRule__r.GridRate__c, GridRule__r.OtherGridRule__c, GridRule__r.OtherShareType__c, GridRule__r.FinalRebateRate__c,
                                        StartDate__c, RebateRate__c
                                       FROM GridDetail__c
                                       WHERE Grid__c = :gridId
                                       ORDER BY ShareClass__r.Fund__r.ProductName__c, ShareClass__r.Name__c];
        Set<Id> shareClassIds = new Set<Id>();
        for (GridDetail__c detail : details) {
            Id scId = detail.StandardGridDetail__c != null ? detail.StandardGridDetail__r.ShareClass__c : detail.ShareClass__c;
            if (scId != null) shareClassIds.add(scId);
        }

        Map<Id, String> aumByShareClass = buildAumByShareClass(shareClassIds, agreementSelection, result);
        for (GridDetail__c detail : details) {
            result.rows.add(new GridDetailRow(detail, aumByShareClass));
        }

        return result;
    }

    private static AgreementSelection parseAgreementSelection(List<GridScope__c> scopes, GridDetailResult result) {
        AgreementSelection selection = new AgreementSelection();

        List<String> agreementParts = new List<String>();
        for (GridScope__c scope : scopes) {
            if (String.isNotBlank(scope.Agreement__c)) {
                if (scope.Agreement__c.trim().equalsIgnoreCase('ALL')) {
                    selection.all = true;
                    return selection;
                }
                agreementParts.add(scope.Agreement__c);
            }
        }
        String rawValue = String.join(agreementParts, ';');

        Set<String> tokens = splitTokens(rawValue);
        Set<Id> idTokens = new Set<Id>();
        Set<String> nameTokens = new Set<String>();
        for (String token : tokens) {
            if (isSalesforceId(token)) {
                idTokens.add((Id)token);
            } 
            else {
                nameTokens.add(token);
            }
        }

        selection.agreementIds.addAll(idTokens);

        if (!nameTokens.isEmpty()) {
            Map<String, Convention__c> foundByToken = new Map<String, Convention__c>();
            for (Convention__c agreement : [SELECT Id, Name
                                            FROM Convention__c
                                            WHERE Name IN :nameTokens]) {
                selection.agreementIds.add(agreement.Id);
                foundByToken.put(agreement.Name, agreement);
            }

            Set<String> missing = new Set<String>(nameTokens);
            missing.removeAll(foundByToken.keySet());
            if (!missing.isEmpty()) {
                result.errors.add('Agreements not found: ' + String.join(new List<String>(missing), ', '));
            }
        }

        return selection;
    }

    private static Map<Id, String> buildAumByShareClass(Set<Id> shareClassIds, AgreementSelection selection, GridDetailResult result) {
        Map<Id, String> aumByShareClass = new Map<Id, String>();
        if (shareClassIds.isEmpty()) {
            return aumByShareClass;
        }

        if (!selection.all && selection.agreementIds.isEmpty()) {
            result.errors.add('No agreements resolved. AUM will be blank.');
            return aumByShareClass;
        }

        Set<Id> agreementIdsSet = selection.agreementIds;
        String aumQuery = 'SELECT ShareClass__c scId, SUM(AmountEUR__c) totalAmount ' +
                          ' FROM AUM__c ' +
                          ' WHERE ShareClass__c IN :shareClassIds ';
        aumQuery += selection.all ? '' : 'AND Convention__c IN :agreementIdsSet ';
        aumQuery += ' GROUP BY ShareClass__c';

        for (AggregateResult ar : Database.query(aumQuery)) {
            aumByShareClass.put((Id)ar.get('scId'), GridBuilderHelper.formatAum((Decimal)ar.get('totalAmount')));
        }

        return aumByShareClass;
    }

    private static Decimal calculateNetMargin(Decimal effMgtFee, Decimal rebateRate) {
        return (effMgtFee != null && rebateRate != null)? effMgtFee - rebateRate : (rebateRate == null)? effMgtFee : null;
    }

    private static String buildRuleValue(GridRule__c gridRule) {
        if (gridRule == null) {
            return null;
        }
        if (gridRule.RuleToApply__c == RULE_OTHER_GRID) {
            return gridRule.OtherGridRule__c;
        }
        if (gridRule.RuleToApply__c == RULE_OTHER_SHARE) {
            return gridRule.OtherShareType__c;
        }
        if (gridRule.RuleToApply__c == RULE_OTHER_SHARE_FEES) {
            String pct = GridBuilderHelper.formatPercent(gridRule.GridRate__c);
            if (String.isNotBlank(gridRule.OtherShareType__c) && String.isNotBlank(pct)) {
                return gridRule.OtherShareType__c + ' + ' + pct;
            }
            return String.isNotBlank(pct) ? pct : gridRule.OtherShareType__c;
        }
        return GridBuilderHelper.formatPercent(gridRule.GridRate__c);
    }

    private static String getShareValue(Share_Class__c share, String fieldPath) {
        if (share == null || String.isBlank(fieldPath)) {
            return null;
        }
        Object rawValue = GridBuilderHelper.getFieldValue(share, fieldPath.split('\\.'), 0);
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    private static Set<String> splitTokens(String raw) {
        Set<String> tokens = new Set<String>();
        if (String.isBlank(raw)) {
            return tokens;
        }
        for (String part : raw.split('[,;]')) {
            String cleaned = part != null ? part.trim() : null;
            if (String.isNotBlank(cleaned)) {
                tokens.add(cleaned);
            }
        }
        return tokens;
    }

    private static Boolean isSalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        Integer len = value.length();
        if (len != 15 && len != 18) {
            return false;
        }
        return Pattern.matches('[a-zA-Z0-9]{15,18}', value);
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    private class AgreementSelection {
        public Boolean all = false;
        public Set<Id> agreementIds = new Set<Id>();
        public AgreementSelection() {
            this.all = false;
            this.agreementIds = new Set<Id>();
        }
    }

    public class GridDetailResult {
        @AuraEnabled public List<GridDetailRow> rows;
        @AuraEnabled public List<String> errors;
    }

    public class GridDetailRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String assetType;
        @AuraEnabled public String strategy;
        @AuraEnabled public String legalStatus;
        @AuraEnabled public String internalShortName;
        @AuraEnabled public String portfolio;
        @AuraEnabled public String shareClass;
        @AuraEnabled public String isin;
        @AuraEnabled public String aum;
        @AuraEnabled public Date effMgtFeeDate;
        @AuraEnabled public String effMgtFee;
        @AuraEnabled public String rebateRate;
        @AuraEnabled public String netMargin;
        @AuraEnabled public String profitability;
        @AuraEnabled public String gridRule;
        @AuraEnabled public String ruleValue;
        public GridDetailRow(GridDetail__c detail, Map<Id, String> aumByShareClass) {
            Boolean isCustom         =   detail.StandardGridDetail__c != null;
            Share_Class__c share     =   isCustom ? detail.StandardGridDetail__r.ShareClass__r : detail.ShareClass__r;
            Id effectiveScId         =   isCustom ? detail.StandardGridDetail__r.ShareClass__c : detail.ShareClass__c;
            GridRule__c gridRule     =   isCustom ? detail.StandardGridDetail__r.GridRule__r : detail.GridRule__r;
            Decimal effFee           =   share != null ? share.EffectiveManagementFees__c : null;
            Decimal baseRebateRate   =   isCustom ? detail.StandardGridDetail__r.RebateRate__c : detail.RebateRate__c;
            Boolean hasFinalRate     =   gridRule != null && gridRule.FinalRebateRate__c != null;
            Decimal effectiveRate    =   hasFinalRate ? gridRule.FinalRebateRate__c : baseRebateRate;
            Decimal netMarginVal     =   calculateNetMargin(effFee, effectiveRate);
            Decimal profitabilityVal =   (effFee != null && effFee != 0 && netMarginVal != null) ? (netMarginVal / effFee * 100).setScale(2, RoundingMode.HALF_UP) : null;

            this.id                  =   detail.Id;
            this.assetType           =   getShareValue(share, 'Fund__r.FundStrategy__r.AssetClass__c');
            this.strategy            =   getShareValue(share, 'Fund__r.FundStrategy__r.Name');
            this.legalStatus         =   getShareValue(share, 'Fund__r.LegalForm__c');
            this.internalShortName   =   getShareValue(share, 'Fund__r.InternalShortName__c');
            this.portfolio           =   getShareValue(share, 'Fund__r.ProductName__c');
            this.shareClass          =   getShareValue(share, 'Name__c');
            this.isin                =   getShareValue(share, 'ISIN__c');
            this.aum                 =   aumByShareClass.containsKey(effectiveScId) ? aumByShareClass.get(effectiveScId) : '0';
            this.effMgtFeeDate       =   isCustom ? detail.StandardGridDetail__r.StartDate__c : detail.StartDate__c;
            this.effMgtFee           =   GridBuilderHelper.formatPercent(effFee);
            this.rebateRate          =   GridBuilderHelper.formatPercent(effectiveRate);
            this.netMargin           =   GridBuilderHelper.formatPercent(netMarginVal);
            this.profitability       =   GridBuilderHelper.formatPercent(profitabilityVal);
            this.gridRule            =   hasFinalRate ? 'Calculated Rebates' : (gridRule != null ? gridRule.RuleToApply__c : null);
            this.ruleValue           =   hasFinalRate ? GridBuilderHelper.formatPercent(gridRule.FinalRebateRate__c) : buildRuleValue(gridRule);
        }
    }
}