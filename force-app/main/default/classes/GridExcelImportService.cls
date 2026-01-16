public with sharing class GridExcelImportService {
    private static final Date START_DATE = Date.newInstance(2023, 1, 1);
    private static final Date END_DATE = Date.newInstance(2099, 12, 31);

    private static final Map<String, String> RULE_TO_APPLY_MAP = new Map<String, String>{
        'percentage of fees' => 'Percentage of Fees',
        'take rebates rate - other share type' => 'Take Rebates Rate - Other Share Type',
        'take rebates rate - other share type + fees' => 'Take Rebates Rate - Other Share Type + Fees',
        'take rebates rate - other grid rule' => 'Take Rebates Rate - Other Grid Rule'
    };

    private static final Map<String, String> FEES_TYPE_MAP = new Map<String, String>{
        'effectivemanagementfees' => 'EffectiveManagementFees__c',
        'effectivemanagementfees__c' => 'EffectiveManagementFees__c'
    };

    @AuraEnabled
    public static ImportResult importFromJson(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            throw new AuraHandledException('payloadJson is required.');
        }

        Payload payload;
        try {
            payload = (Payload) JSON.deserialize(payloadJson, Payload.class);
        } catch (Exception ex) {
            throw new AuraHandledException('Invalid JSON payload: ' + ex.getMessage());
        }

        ImportResult result = new ImportResult();
        result.errors = new List<ImportError>();

        List<ScopeRow> scopeRows = payload != null && payload.scopes != null ? payload.scopes : new List<ScopeRow>();
        List<RuleRow> ruleRows = payload != null && payload.rules != null ? payload.rules : new List<RuleRow>();

        Map<String, GridScope__c> scopesByName = new Map<String, GridScope__c>();
        Map<String, Integer> scopeRowByName = new Map<String, Integer>();
        Map<String, Integer> scopeRuleRowByName = new Map<String, Integer>();
        Set<String> gridNames = new Set<String>();

        for (ScopeRow row : scopeRows) {
            Integer rowNumber = row != null && row.rowNumber != null ? row.rowNumber : -1;
            String gridName = normalize(row != null ? row.Grid : null);
            if (String.isBlank(gridName)) {
                addError(result, 'GridScopes', rowNumber, 'Grid is required.');
                continue;
            }

            GridScope__c scope = scopesByName.get(gridName);
            if (scope == null) {
                scope = new GridScope__c();
                scope.GridName__c = gridName;
                scopesByName.put(gridName, scope);
            }
            scope.Agreement__c = normalize(row.Agreement);
            scope.Country__c = normalize(row.Country);
            scope.ProductCode__c = normalize(row.PtfCode);
            scopeRowByName.put(gridName, rowNumber);
        }

        for (RuleRow row : ruleRows) {
            Integer rowNumber = row != null && row.rowNumber != null ? row.rowNumber : -1;
            String gridName = normalize(row != null ? row.Grid : null);
            if (String.isBlank(gridName)) {
                addError(result, 'GridRules', rowNumber, 'Grid is required.');
                continue;
            }
            gridNames.add(gridName);

            if (!scopesByName.containsKey(gridName)) {
                GridScope__c scope = new GridScope__c();
                scope.GridName__c = gridName;
                scopesByName.put(gridName, scope);
                scopeRuleRowByName.put(gridName, rowNumber);
            }
        }

        Map<String, Id> scopeIdByName = upsertScopes(scopesByName, scopeRowByName, scopeRuleRowByName, result);

        Map<String, Id> gridIdByName = new Map<String, Id>();
        if (!gridNames.isEmpty()) {
            for (Grid__c grid : [SELECT Id, Name FROM Grid__c WHERE Name IN :gridNames]) {
                gridIdByName.put(grid.Name, grid.Id);
            }
        }

        List<RuleContext> ruleContexts = new List<RuleContext>();
        for (RuleRow row : ruleRows) {
            Integer rowNumber = row != null && row.rowNumber != null ? row.rowNumber : -1;
            String gridName = normalize(row != null ? row.Grid : null);
            if (String.isBlank(gridName)) {
                continue;
            }

            Id gridId = gridIdByName.get(gridName);
            if (gridId == null) {
                addError(result, 'GridRules', rowNumber, 'Grid__c not found for Grid "' + gridName + '".');
                continue;
            }

            Id scopeId = scopeIdByName.get(gridName);
            if (scopeId == null) {
                addError(result, 'GridRules', rowNumber, 'GridScope__c not found or failed to create for Grid "' + gridName + '".');
                continue;
            }

            String ruleToApply = mapRuleToApply(row.RuleToApply);
            if (ruleToApply == null) {
                addError(result, 'GridRules', rowNumber, 'Unsupported RuleToApply "' + normalize(row.RuleToApply) + '".');
                continue;
            }

            String feesType = mapFeesType(row.FeesType);
            if (String.isNotBlank(normalize(row.FeesType)) && feesType == null) {
                addError(result, 'GridRules', rowNumber, 'FeesType must be "EffectiveManagementFees" when provided.');
                continue;
            }

            GridCriteriaExpressionParser.ParseResult parseResult = GridCriteriaExpressionParser.parse(row.Include, row.Exclude);
            if (parseResult.hasErrors()) {
                for (String err : parseResult.errors) {
                    addError(result, 'GridRules', rowNumber, err);
                }
                continue;
            }

            RuleContext ctx = new RuleContext();
            ctx.rowNumber = rowNumber;
            ctx.gridName = gridName;
            ctx.gridId = gridId;
            ctx.scopeId = scopeId;
            ctx.ruleToApply = ruleToApply;
            ctx.feesType = feesType;
            ctx.conditions = parseResult.conditions;

            String valueError = applyRuleValue(ctx, row);
            if (valueError != null) {
                addError(result, 'GridRules', rowNumber, valueError);
                continue;
            }

            GridCriteria__c criteria = new GridCriteria__c();
            criteria.Name = buildCriteriaName(gridName, rowNumber);
            criteria.Grid__c = gridId;
            criteria.Comment__c = normalize(row.Comment);
            criteria.StartDate__c = START_DATE;
            criteria.EndDate__c = END_DATE;
            criteria.FilterLogic__c = 'Custom Logic';
            criteria.FilterLogicExpression__c = parseResult.filterLogicExpression;
            ctx.criteria = criteria;

            ruleContexts.add(ctx);
        }

        if (ruleContexts.isEmpty()) {
            return result;
        }

        List<GridCriteria__c> criteriaToInsert = new List<GridCriteria__c>();
        for (RuleContext ctx : ruleContexts) {
            criteriaToInsert.add(ctx.criteria);
        }

        Database.SaveResult[] criteriaResults = Database.insert(criteriaToInsert, false);
        for (Integer i = 0; i < criteriaResults.size(); i++) {
            RuleContext ctx = ruleContexts[i];
            if (criteriaResults[i].isSuccess()) {
                result.criteriaCreated++;
                ctx.criteriaId = criteriaToInsert[i].Id;
            } else {
                ctx.hasErrors = true;
                addError(result, 'GridRules', ctx.rowNumber, 'Failed to create GridCriteria__c: ' + criteriaResults[i].getErrors()[0].getMessage());
            }
        }

        List<GridCriteriaDetail__c> detailsToInsert = new List<GridCriteriaDetail__c>();
        List<DetailContext> detailContexts = new List<DetailContext>();
        for (RuleContext ctx : ruleContexts) {
            if (ctx.hasErrors) {
                continue;
            }
            for (GridCriteriaExpressionParser.ParsedCondition cond : ctx.conditions) {
                GridCriteriaDetail__c detail = new GridCriteriaDetail__c();
                detail.GridCriteria__c = ctx.criteriaId;
                detail.FilterNumber__c = cond.filterNumber;
                detail.Logic__c = cond.logic;
                detail.Value__c = cond.value;
                detail.Object__c = cond.objectApiName;
                detail.Field__c = cond.fieldApiName;
                detail.TECHOrigin__c = 'System';
                detailsToInsert.add(detail);
                detailContexts.add(new DetailContext(detail, ctx));
            }
        }

        if (!detailsToInsert.isEmpty()) {
            Database.SaveResult[] detailResults = Database.insert(detailsToInsert, false);
            for (Integer i = 0; i < detailResults.size(); i++) {
                DetailContext detailContext = detailContexts[i];
                if (detailResults[i].isSuccess()) {
                    result.criteriaDetailsCreated++;
                } else {
                    detailContext.context.detailError = true;
                    addError(result, 'GridRules', detailContext.context.rowNumber, 'Failed to create GridCriteriaDetail__c: ' + detailResults[i].getErrors()[0].getMessage());
                }
            }
        }

        List<GridRuleLine__c> ruleLines = new List<GridRuleLine__c>();
        List<RuleContext> ruleLineContexts = new List<RuleContext>();
        for (RuleContext ctx : ruleContexts) {
            if (ctx.hasErrors || ctx.detailError) {
                continue;
            }
            GridRuleLine__c line = new GridRuleLine__c();
            line.GridScope__c = ctx.scopeId;
            line.GridCriteria__c = ctx.criteriaId;
            line.RuleToApply__c = ctx.ruleToApply;
            line.FeesType__c = ctx.feesType;
            line.PercentageOfFees__c = ctx.percentageOfFees;
            line.OtherShareType__c = ctx.otherShareType;
            line.OtherGridRule__c = ctx.otherGridRule;
            ruleLines.add(line);
            ruleLineContexts.add(ctx);
        }

        if (!ruleLines.isEmpty()) {
            Database.SaveResult[] ruleLineResults = Database.insert(ruleLines, false);
            for (Integer i = 0; i < ruleLineResults.size(); i++) {
                RuleContext ctx = ruleLineContexts[i];
                if (ruleLineResults[i].isSuccess()) {
                    result.ruleLinesCreated++;
                } else {
                    addError(result, 'GridRules', ctx.rowNumber, 'Failed to create GridRuleLine__c: ' + ruleLineResults[i].getErrors()[0].getMessage());
                }
            }
        }

        return result;
    }

    private static Map<String, Id> upsertScopes(
        Map<String, GridScope__c> scopesByName,
        Map<String, Integer> scopeRowByName,
        Map<String, Integer> scopeRuleRowByName,
        ImportResult result
    ) {
        Map<String, Id> scopeIdByName = new Map<String, Id>();
        if (scopesByName.isEmpty()) {
            return scopeIdByName;
        }

        Map<String, GridScope__c> existingByName = new Map<String, GridScope__c>();
        for (GridScope__c scope : [SELECT Id, GridName__c FROM GridScope__c WHERE GridName__c IN :scopesByName.keySet()]) {
            existingByName.put(scope.GridName__c, scope);
        }

        List<GridScope__c> toUpsert = new List<GridScope__c>();
        for (GridScope__c scope : scopesByName.values()) {
            GridScope__c existing = existingByName.get(scope.GridName__c);
            if (existing != null) {
                scope.Id = existing.Id;
            }
            toUpsert.add(scope);
        }

        Database.UpsertResult[] results = Database.upsert(toUpsert, false);
        for (Integer i = 0; i < results.size(); i++) {
            GridScope__c scope = toUpsert[i];
            if (results[i].isSuccess()) {
                result.scopesUpserted++;
                scopeIdByName.put(scope.GridName__c, scope.Id);
            } else {
                Integer rowNumber = scopeRowByName.containsKey(scope.GridName__c)
                    ? scopeRowByName.get(scope.GridName__c)
                    : scopeRuleRowByName.get(scope.GridName__c);
                String sheetName = scopeRowByName.containsKey(scope.GridName__c) ? 'GridScopes' : 'GridRules';
                addError(result, sheetName, rowNumber, 'Failed to upsert GridScope__c for Grid "' + scope.GridName__c + '": ' + results[i].getErrors()[0].getMessage());
            }
        }

        return scopeIdByName;
    }

    private static String normalize(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return String.isBlank(trimmed) ? null : trimmed;
    }

    private static String mapRuleToApply(String value) {
        String key = normalize(value);
        if (key == null) {
            return null;
        }
        return RULE_TO_APPLY_MAP.get(key.toLowerCase());
    }

    private static String mapFeesType(String value) {
        String key = normalize(value);
        if (key == null) {
            return null;
        }
        return FEES_TYPE_MAP.get(key.toLowerCase());
    }

    private static String applyRuleValue(RuleContext ctx, RuleRow row) {
        String ruleValue = normalize(row.RuleValue);
        String otherShareType = normalize(row.OtherShareType);

        if (ctx.ruleToApply == 'Percentage of Fees') {
            if (String.isBlank(ruleValue)) {
                return 'RuleValue is required for Percentage of Fees.';
            }
            Decimal pct = parsePercent(ruleValue);
            if (pct == null) {
                return 'RuleValue "' + ruleValue + '" is not a valid percentage.';
            }
            ctx.percentageOfFees = pct;
            ctx.otherShareType = null;
            ctx.otherGridRule = null;
            return null;
        }
        if (ctx.ruleToApply == 'Take Rebates Rate - Other Share Type') {
            if (String.isBlank(otherShareType)) {
                return 'OtherShareType is required for Other Share Type.';
            }
            ctx.otherShareType = otherShareType;
            ctx.percentageOfFees = null;
            ctx.otherGridRule = null;
            return null;
        }
        if (ctx.ruleToApply == 'Take Rebates Rate - Other Share Type + Fees') {
            if (String.isBlank(otherShareType)) {
                return 'OtherShareType is required for Other Share Type + Fees.';
            }
            if (String.isBlank(ruleValue)) {
                return 'RuleValue is required for Other Share Type + Fees.';
            }
            Decimal pct = parsePercent(ruleValue);
            if (pct == null) {
                return 'RuleValue "' + ruleValue + '" is not a valid percentage.';
            }
            ctx.otherShareType = otherShareType;
            ctx.percentageOfFees = pct;
            ctx.otherGridRule = null;
            return null;
        }
        if (ctx.ruleToApply == 'Take Rebates Rate - Other Grid Rule') {
            if (String.isBlank(ruleValue)) {
                return 'RuleValue is required for Other Grid Rule.';
            }
            ctx.otherGridRule = ruleValue;
            ctx.percentageOfFees = null;
            ctx.otherShareType = null;
            return null;
        }
        return 'Unsupported RuleToApply "' + ctx.ruleToApply + '".';
    }

    private static Decimal parsePercent(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String cleaned = raw.replace('%', '').trim();
        cleaned = cleaned.replace(',', '.');
        try {
            return Decimal.valueOf(cleaned);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String buildCriteriaName(String gridName, Integer rowNumber) {
        if (rowNumber == null) {
            rowNumber = -1;
        }
        return 'CRIT-' + gridName + '-' + String.valueOf(rowNumber);
    }

    private static void addError(ImportResult result, String sheetName, Integer rowNumber, String message) {
        result.errors.add(new ImportError(sheetName, rowNumber, message));
    }

    public class ImportResult {
        @AuraEnabled public Integer scopesUpserted = 0;
        @AuraEnabled public Integer criteriaCreated = 0;
        @AuraEnabled public Integer criteriaDetailsCreated = 0;
        @AuraEnabled public Integer ruleLinesCreated = 0;
        @AuraEnabled public List<ImportError> errors;
    }

    public class ImportError {
        @AuraEnabled public String sheetName;
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String message;
        public ImportError(String sheetName, Integer rowNumber, String message) {
            this.sheetName = sheetName;
            this.rowNumber = rowNumber;
            this.message = message;
        }
    }

    public class Payload {
        public List<ScopeRow> scopes;
        public List<RuleRow> rules;
    }

    public class ScopeRow {
        public Integer rowNumber;
        public String Grid;
        public String Agreement;
        public String Country;
        public String PtfCode;
    }

    public class RuleRow {
        public Integer rowNumber;
        public String Grid;
        public String Include;
        public String Exclude;
        public String Comment;
        public String RuleToApply;
        public String FeesType;
        public String RuleValue;
        public String OtherShareType;
    }

    private class RuleContext {
        public Integer rowNumber;
        public String gridName;
        public Id gridId;
        public Id scopeId;
        public String ruleToApply;
        public String feesType;
        public Decimal percentageOfFees;
        public String otherShareType;
        public String otherGridRule;
        public GridCriteria__c criteria;
        public Id criteriaId;
        public List<GridCriteriaExpressionParser.ParsedCondition> conditions;
        public Boolean hasErrors = false;
        public Boolean detailError = false;
    }

    private class DetailContext {
        public GridCriteriaDetail__c detail;
        public RuleContext context;
        public DetailContext(GridCriteriaDetail__c detail, RuleContext context) {
            this.detail = detail;
            this.context = context;
        }
    }
}