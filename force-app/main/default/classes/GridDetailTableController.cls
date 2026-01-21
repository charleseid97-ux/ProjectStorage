public with sharing class GridDetailTableController {
    private static final String RULE_PERCENTAGE = 'Percentage of Fees';
    private static final String RULE_OTHER_SHARE = 'Take Rebates Rate - Other Share Type';
    private static final String RULE_OTHER_SHARE_FEES = 'Take Rebates Rate - Other Share Type + Fees';
    private static final String RULE_OTHER_GRID = 'Take Rebates Rate - Other Grid Rule';
    private static final String ALL_TOKEN = 'ALL';

    @AuraEnabled(cacheable=true)
    public static GridDetailResult getGridDetails(Id gridId) {
        GridDetailResult result = new GridDetailResult();
        result.rows = new List<GridDetailRow>();
        result.errors = new List<String>();

        if (gridId == null) {
            result.errors.add('Grid Id is required.');
            return result;
        }

        Grid__c grid = [
            SELECT Id, GridScope__c, GridScope__r.Agreement__c
            FROM Grid__c
            WHERE Id = :gridId
            LIMIT 1
        ];

        AgreementSelection agreementSelection;
        if (grid.GridScope__c == null) {
            agreementSelection = new AgreementSelection();
            agreementSelection.all = false;
            agreementSelection.agreementIds = new Set<Id>();
            result.errors.add('GridScope__c is missing on this Grid. AUM will be blank.');
        } else {
            agreementSelection = parseAgreementSelection(grid.GridScope__r != null ? grid.GridScope__r.Agreement__c : null, result);
        }

        List<GridDetail__c> details = [
            SELECT Id, ShareClass__c, ShareClass__r.Name__c, ShareClass__r.Type__c, ShareClass__r.Currency__c,
                   ShareClass__r.ISIN__c, ShareClass__r.EffectiveManagementFees__c,
                   ShareClass__r.Fund__r.Strategy__r.AssetClass__c, ShareClass__r.Fund__r.Strategy__r.Name,
                   ShareClass__r.Fund__r.Legal_Status__c, ShareClass__r.Fund__r.InternalShortName__c,
                   ShareClass__r.Fund__r.ProductName__c,
                   GridRuleLine__r.RuleToApply__c, GridRuleLine__r.PercentageOfFees__c,
                   GridRuleLine__r.OtherGridRule__c, GridRuleLine__r.OtherShareType__c,
                   StartDate__c, Rebate__c
            FROM GridDetail__c
            WHERE Grid__c = :gridId
            ORDER BY ShareClass__r.Fund__r.ProductName__c, ShareClass__r.Name__c
        ];

        Set<Id> shareClassIds = new Set<Id>();
        for (GridDetail__c detail : details) {
            if (detail.ShareClass__c != null) {
                shareClassIds.add(detail.ShareClass__c);
            }
        }

        Map<Id, String> aumByShareClass = buildAumByShareClass(shareClassIds, agreementSelection, result);

        for (GridDetail__c detail : details) {
            Share_Class__c share = detail.ShareClass__r;
            GridRuleLine__c ruleLine = detail.GridRuleLine__r;

            GridDetailRow row = new GridDetailRow();
            row.id = detail.Id;
            row.assetType = getShareValue(share, 'Fund__r.Strategy__r.AssetClass__c');
            row.strategy = getShareValue(share, 'Fund__r.Strategy__r.Name');
            row.legalStatus = getShareValue(share, 'Fund__r.Legal_Status__c');
            row.internalShortName = getShareValue(share, 'Fund__r.InternalShortName__c');
            row.portfolio = getShareValue(share, 'Fund__r.ProductName__c');
            row.shareClass = getShareValue(share, 'Name__c');
            row.shareType = getShareValue(share, 'Type__c');
            row.scCurrency = getShareValue(share, 'Currency__c');
            row.isin = getShareValue(share, 'ISIN__c');
            row.aum = aumByShareClass.containsKey(detail.ShareClass__c) ? aumByShareClass.get(detail.ShareClass__c) : '0';
            row.effMgtFeeDate = detail.StartDate__c;

            Decimal effFee = share != null ? share.EffectiveManagementFees__c : null;
            row.effMgtFee = formatPercent(effFee);
            row.rebateRate = formatPercent(detail.Rebate__c);
            row.netMargin = formatPercent(calculateNetMargin(effFee, detail.Rebate__c));
            row.profitability = formatPercent(ruleLine != null ? ruleLine.PercentageOfFees__c : null);
            row.gridRule = ruleLine != null ? ruleLine.RuleToApply__c : null;
            row.ruleValue = buildRuleValue(ruleLine);
            result.rows.add(row);
        }

        return result;
    }

    private static AgreementSelection parseAgreementSelection(String rawValue, GridDetailResult result) {
        AgreementSelection selection = new AgreementSelection();
        selection.all = String.isBlank(rawValue) || rawValue.trim().equalsIgnoreCase(ALL_TOKEN);
        selection.agreementIds = new Set<Id>();
        if (selection.all) {
            return selection;
        }

        Set<String> tokens = splitTokens(rawValue);
        Set<Id> idTokens = new Set<Id>();
        Set<String> nameTokens = new Set<String>();
        for (String token : tokens) {
            if (isSalesforceId(token)) {
                idTokens.add((Id)token);
            } else {
                nameTokens.add(token);
            }
        }

        selection.agreementIds.addAll(idTokens);

        if (!nameTokens.isEmpty()) {
            Map<String, Convention__c> foundByToken = new Map<String, Convention__c>();
            for (Convention__c agreement : [
                SELECT Id, Name, ConventionName__c, Agreement_Code__c
                FROM Convention__c
                WHERE Name IN :nameTokens OR ConventionName__c IN :nameTokens OR Agreement_Code__c IN :nameTokens
            ]) {
                selection.agreementIds.add(agreement.Id);
                if (String.isNotBlank(agreement.Name)) {
                    foundByToken.put(agreement.Name, agreement);
                }
                if (String.isNotBlank(agreement.ConventionName__c)) {
                    foundByToken.put(agreement.ConventionName__c, agreement);
                }
                if (String.isNotBlank(agreement.Agreement_Code__c)) {
                    foundByToken.put(agreement.Agreement_Code__c, agreement);
                }
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
            result.errors.add('No agreements resolved for this GridScope. AUM will be blank.');
            return aumByShareClass;
        }

        List<AggregateResult> aumResults;
        if (selection.all) {
            aumResults = [
                SELECT ShareClass__c scId, SUM(AmountEUR__c) totalAmount
                FROM AUM__c
                WHERE ShareClass__c IN :shareClassIds
                GROUP BY ShareClass__c
            ];
        } else {
            aumResults = [
                SELECT ShareClass__c scId, SUM(AmountEUR__c) totalAmount
                FROM AUM__c
                WHERE ShareClass__c IN :shareClassIds
                AND Convention__c IN :selection.agreementIds
                GROUP BY ShareClass__c
            ];
        }

        for (AggregateResult ar : aumResults) {
            Decimal totalAum = (Decimal)ar.get('totalAmount');
            aumByShareClass.put((Id)ar.get('scId'), formatAum(totalAum));
        }

        return aumByShareClass;
    }

    private static Decimal calculateNetMargin(Decimal effMgtFee, Decimal rebateRate) {
        if (effMgtFee == null) {
            return null;
        }
        if (rebateRate == null) {
            return effMgtFee;
        }
        return effMgtFee - rebateRate;
    }

    private static String buildRuleValue(GridRuleLine__c ruleLine) {
        if (ruleLine == null) {
            return null;
        }
        if (ruleLine.RuleToApply__c == RULE_OTHER_GRID) {
            return ruleLine.OtherGridRule__c;
        }
        if (ruleLine.RuleToApply__c == RULE_OTHER_SHARE) {
            return ruleLine.OtherShareType__c;
        }
        if (ruleLine.RuleToApply__c == RULE_OTHER_SHARE_FEES) {
            String pct = formatPercent(ruleLine.PercentageOfFees__c);
            if (String.isNotBlank(ruleLine.OtherShareType__c) && String.isNotBlank(pct)) {
                return ruleLine.OtherShareType__c + ' + ' + pct;
            }
            return String.isNotBlank(pct) ? pct : ruleLine.OtherShareType__c;
        }
        return formatPercent(ruleLine.PercentageOfFees__c);
    }

    private static String getShareValue(Share_Class__c share, String fieldPath) {
        if (share == null || String.isBlank(fieldPath)) {
            return null;
        }
        Object rawValue = GridBuilderHelper.getFieldValue(share, fieldPath.split('\\.'), 0);
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    private static String formatAum(Decimal totalAum) {
        if (totalAum == null) {
            return '0';
        }
        Decimal scaled = totalAum >= 100000 ? totalAum.setScale(0) : totalAum.setScale(2, RoundingMode.HALF_UP);
        return scaled.format();
    }

    private static String formatPercent(Decimal value) {
        if (value == null) {
            return null;
        }
        Decimal scaled = value.setScale(2, RoundingMode.HALF_UP);
        return scaled.format() + '%';
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

    private class AgreementSelection {
        public Boolean all = false;
        public Set<Id> agreementIds = new Set<Id>();
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
        @AuraEnabled public String shareType;
        @AuraEnabled public String scCurrency;
        @AuraEnabled public String isin;
        @AuraEnabled public String aum;
        @AuraEnabled public Date effMgtFeeDate;
        @AuraEnabled public String effMgtFee;
        @AuraEnabled public String rebateRate;
        @AuraEnabled public String netMargin;
        @AuraEnabled public String profitability;
        @AuraEnabled public String gridRule;
        @AuraEnabled public String ruleValue;
    }
}