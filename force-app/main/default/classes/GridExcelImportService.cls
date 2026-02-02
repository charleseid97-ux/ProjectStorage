/**
 * @description Service class for importing grid configurations from Excel/JSON payloads. 
 *              Parses scope and rule definitions, creates/updates GridScope__c, GridCriteria__c, GridCriteriaDetail__c, and
 *              GridRuleLine__c records. 
 *              Integrates with GridCriteriaExpressionParser for Include/Exclude expression parsing. 
 *              Provides comprehensive error tracking and validation.
 * @author Charles EID
 * @testClass GridExcelImportServiceTest
 * @coverage 81%
 */
public with sharing class GridExcelImportService {
    private static final Date START_DATE = Date.newInstance(2023, 1, 1);
    private static final Date END_DATE = Date.newInstance(2099, 12, 31);

    private static final String PERCENTAGE_OF_FEES = 'Percentage of Fees';
    private static final String TAKE_REBATES_RATE_OTHER_SHARE_TYPE = 'Take Rebates Rate - Other Share Type';
    private static final String TAKE_REBATES_RATE_OTHER_SHARE_TYPE_FEES = 'Take Rebates Rate - Other Share Type + Fees';
    private static final String TAKE_REBATES_RATE_OTHER_GRID_RULE = 'Take Rebates Rate - Other Grid Rule';

    private static final Map<String, String> RULE_TO_APPLY_MAP = new Map<String, String>{
        'percentage of fees' => PERCENTAGE_OF_FEES,
        '%offees' => PERCENTAGE_OF_FEES,
        'take rebates rate - other share type' => TAKE_REBATES_RATE_OTHER_SHARE_TYPE,
        'takerebatesrate' => TAKE_REBATES_RATE_OTHER_SHARE_TYPE,
        'take rebates rate - other share type + fees' => TAKE_REBATES_RATE_OTHER_SHARE_TYPE_FEES,
        'rebatesa + fees(e-a)' => TAKE_REBATES_RATE_OTHER_SHARE_TYPE_FEES,
        'rebatesaw + fees(e-aw)' => TAKE_REBATES_RATE_OTHER_SHARE_TYPE_FEES,
        'take rebates rate - other grid rule' => TAKE_REBATES_RATE_OTHER_GRID_RULE,
        'gridrule' => TAKE_REBATES_RATE_OTHER_GRID_RULE
    };

    private static final Map<String, String> FEES_TYPE_MAP = new Map<String, String>{
        'effectivemanagementfees' => 'EffectiveManagementFees__c',
        'effectivemanagementfees__c' => 'EffectiveManagementFees__c'
    };

    @AuraEnabled
    public static ImportResult importFromJson(String payloadJson) {
        Payload payload = deserializePayload(payloadJson);
        ImportResult result = new ImportResult();
        result.errors = new List<ImportError>();

        List<ScopeRow> scopeRows = payload != null && payload.scopes != null ? payload.scopes : new List<ScopeRow>();
        List<RuleRow> ruleRows = payload != null && payload.rules != null ? payload.rules : new List<RuleRow>();

        ScopeCollection scopeCollection = collectScopesAndGrids(scopeRows, ruleRows, result);
        Map<String, Id> scopeIdByName = upsertScopes(scopeCollection.scopesByName, scopeCollection.scopeRowByName, scopeCollection.scopeRuleRowByName, result);
        Map<String, Id> gridIdByName = upsertGrids(scopeCollection.gridNames, scopeIdByName, scopeCollection.scopeRowByName, scopeCollection.scopeRuleRowByName, result);

        List<RuleContext> ruleContexts = buildRuleContexts(ruleRows, gridIdByName, scopeIdByName, result);
        if (ruleContexts.isEmpty()) {
            return result;
        }

        insertCriteria(ruleContexts, result);
        DetailBuildResult detailBuildResult = buildDetailContexts(ruleContexts);
        insertDetails(detailBuildResult, result);
        Set<Id> successfulRuleLineIds = insertRuleLines(ruleContexts, result);
        buildGridDetails(successfulRuleLineIds, result);
        return result;
    }

    private static Payload deserializePayload(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            throw new AuraHandledException('payloadJson is required.');
        }
        try {
            return (Payload) JSON.deserialize(payloadJson, Payload.class);
        }
        catch (Exception ex) {
            throw new AuraHandledException('Invalid JSON payload: ' + ex.getMessage());
        }
    }

    private static ScopeCollection collectScopesAndGrids(List<ScopeRow> scopeRows, List<RuleRow> ruleRows, ImportResult result) {
        ScopeCollection collection = new ScopeCollection();
        collectScopeRows(scopeRows, collection, result);
        collectRuleRows(ruleRows, collection, result);
        return collection;
    }

    private static void collectScopeRows(List<ScopeRow> scopeRows, ScopeCollection collection, ImportResult result) {
        for (ScopeRow row : scopeRows) {
            Integer rowNumber = getRowNumber(row);
            String gridName = normalize(row != null ? row.Grid : null);
            if (String.isBlank(gridName)) {
                addError(result, 'GridScopes', rowNumber, 'Grid is required.');
                continue;
            }
            collection.gridNames.add(gridName);

            GridScope__c scope = collection.scopesByName.get(gridName);
            if (scope == null) {
                scope = new GridScope__c();
                scope.Name = buildGridScopeName(gridName);
                scope.GridName__c = gridName;
                collection.scopesByName.put(gridName, scope);
            }
            scope.Agreement__c = normalize(row.Agreement);
            scope.Country__c = normalize(row.Country);
            scope.ProductCode__c = normalize(row.PtfCode);
            collection.scopeRowByName.put(gridName, rowNumber);
        }
    }

    private static void collectRuleRows(List<RuleRow> ruleRows, ScopeCollection collection, ImportResult result) {
        for (RuleRow row : ruleRows) {
            Integer rowNumber = getRowNumber(row);
            String gridName = normalize(row != null ? row.Grid : null);
            if (String.isBlank(gridName)) {
                addError(result, 'GridRules', rowNumber, 'Grid is required.');
                continue;
            }
            collection.gridNames.add(gridName);

            if (!collection.scopesByName.containsKey(gridName)) {
                GridScope__c scope = new GridScope__c();
                scope.Name = buildGridScopeName(gridName);
                scope.GridName__c = gridName;
                collection.scopesByName.put(gridName, scope);
                collection.scopeRuleRowByName.put(gridName, rowNumber);
            }
        }
    }

    private static List<RuleContext> buildRuleContexts(List<RuleRow> ruleRows, Map<String, Id> gridIdByName, Map<String, Id> scopeIdByName, ImportResult result) {
        List<RuleContext> contexts = new List<RuleContext>();
        for (RuleRow row : ruleRows) {
            RuleContext ctx = buildRuleContext(row, gridIdByName, scopeIdByName, result);
            if (ctx != null) {
                contexts.add(ctx);
            }
        }
        return contexts;
    }

    private static RuleContext buildRuleContext(RuleRow row, Map<String, Id> gridIdByName, Map<String, Id> scopeIdByName, ImportResult result) {
        Integer rowNumber = getRowNumber(row);
        String gridName = normalize(row != null ? row.Grid : null);
        if (String.isBlank(gridName)) {
            return null;
        }

        Id gridId = gridIdByName.get(gridName);
        if (gridId == null) {
            addError(result, 'GridRules', rowNumber, 'Grid__c not found or failed to create for Grid "' + gridName + '".');
            return null;
        }

        Id scopeId = scopeIdByName.get(gridName);
        if (scopeId == null) {
            addError(result, 'GridRules', rowNumber, 'GridScope__c not found or failed to create for Grid "' + gridName + '".');
            return null;
        }

        String ruleToApply = getValueFromMap(row.RuleToApply, RULE_TO_APPLY_MAP);
        if (ruleToApply == null) {
            addError(result, 'GridRules', rowNumber, 'Unsupported RuleToApply "' + normalize(row.RuleToApply) + '".');
            return null;
        }

        String feesType = getValueFromMap(row.FeesType, FEES_TYPE_MAP);
        if (String.isNotBlank(row.FeesType) && feesType == null) {
            addError(result, 'GridRules', rowNumber, 'FeesType must be "EffectiveManagementFees" when provided.');
            return null;
        }

        GridCriteriaExpressionParser.ParseResult parseResult = GridCriteriaExpressionParser.parse(row.Include, row.Exclude);
        if (parseResult.hasErrors()) {
            for (String err : parseResult.errors) {
                addError(result, 'GridRules', rowNumber, err);
            }
            return null;
        }

        RuleContext ctx = new RuleContext(rowNumber, gridName, gridId, scopeId, ruleToApply, feesType, normalize(row.ShareType), parseResult.conditions);
        String valueError = applyRuleValue(ctx, row);
        if (valueError != null) {
            addError(result, 'GridRules', rowNumber, valueError);
            return null;
        }

        ctx.criteria = buildCriteria(gridName, rowNumber, row, parseResult.filterLogicExpression);
        return ctx;
    }

    private static GridCriteria__c buildCriteria(String gridName, Integer rowNumber, RuleRow row, String logicExpression) {
        GridCriteria__c criteria = new GridCriteria__c();
        criteria.Name = buildCriteriaName(gridName, rowNumber);
        criteria.Comment__c = normalize(row.Comment);
        criteria.StartDate__c = START_DATE;
        criteria.EndDate__c = END_DATE;
        criteria.FilterLogic__c = 'Custom Logic';
        criteria.FilterLogicExpression__c = logicExpression;
        return criteria;
    }

    private static void insertCriteria(List<RuleContext> ruleContexts, ImportResult result) {
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
            } 
            else {
                ctx.hasErrors = true;
                addError(result, 'GridRules', ctx.rowNumber, 'Failed to create GridCriteria__c: ' + criteriaResults[i].getErrors()[0].getMessage());
            }
        }
    }

    private static DetailBuildResult buildDetailContexts(List<RuleContext> ruleContexts) {
        DetailBuildResult buildResult = new DetailBuildResult();
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
                detail.TECHOrigin__c = 'Excel Import';
                buildResult.details.add(detail);
                buildResult.contexts.add(new DetailContext(detail, ctx));
            }
        }
        return buildResult;
    }

    private static void insertDetails(DetailBuildResult buildResult, ImportResult result) {
        if (buildResult.details.isEmpty()) {
            return;
        }
        Database.SaveResult[] detailResults = Database.insert(buildResult.details, false);
        for (Integer i = 0; i < detailResults.size(); i++) {
            DetailContext detailContext = buildResult.contexts[i];
            if (detailResults[i].isSuccess()) {
                result.criteriaDetailsCreated++;
            } 
            else {
                detailContext.context.detailError = true;
                addError(result, 'GridRules', detailContext.context.rowNumber, 'Failed to create GridCriteriaDetail__c: ' + detailResults[i].getErrors()[0].getMessage());
            }
        }
    }

    private static Set<Id> insertRuleLines(List<RuleContext> ruleContexts, ImportResult result) {
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
            line.ShareType__c = ctx.shareType;
            line.OtherShareType__c = ctx.otherShareType;
            line.OtherGridRule__c = ctx.otherGridRule;
            ruleLines.add(line);
            ruleLineContexts.add(ctx);
        }

        if (ruleLines.isEmpty()) {
            return new Set<Id>();
        }

        Database.SaveResult[] ruleLineResults = Database.insert(ruleLines, false);
        Set<Id> successfulRuleLineIds = new Set<Id>();
        for (Integer i = 0; i < ruleLineResults.size(); i++) {
            RuleContext ctx = ruleLineContexts[i];
            if (ruleLineResults[i].isSuccess()) {
                result.ruleLinesCreated++;
                successfulRuleLineIds.add(ruleLines[i].Id);
            } 
            else {
                addError(result, 'GridRules', ctx.rowNumber, 'Failed to create GridRuleLine__c: ' + ruleLineResults[i].getErrors()[0].getMessage());
            }
        }
        return successfulRuleLineIds;
    }

    private static void buildGridDetails(Set<Id> successfulRuleLineIds, ImportResult result) {
        if (successfulRuleLineIds.isEmpty()) {
            return;
        }
        GridDetailBuilder.BuildResult detailResult = GridDetailBuilder.buildForRuleLines(successfulRuleLineIds);
        result.gridDetailsCreated += detailResult.gridDetailsCreated;
        if (detailResult.errors != null) {
            for (GridDetailBuilder.BuildError detailError : detailResult.errors) {
                String suffix = detailError.ruleLineId != null ? ' (RuleLine ' + detailError.ruleLineId + ')' : '';
                addError(result, 'GridDetails', null, detailError.message + suffix);
            }
        }
    }

    private static Integer getRowNumber(ScopeRow row) {
        return row != null && row.rowNumber != null ? row.rowNumber : -1;
    }

    private static Integer getRowNumber(RuleRow row) {
        return row != null && row.rowNumber != null ? row.rowNumber : -1;
    }

    private static Map<String, Id> upsertScopes(Map<String, GridScope__c> scopesByName, Map<String, Integer> scopeRowByName, Map<String, Integer> scopeRuleRowByName, ImportResult result) {
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
            } 
            else {
                Integer rowNumber = scopeRowByName.containsKey(scope.GridName__c)? scopeRowByName.get(scope.GridName__c) : scopeRuleRowByName.get(scope.GridName__c);
                String sheetName = scopeRowByName.containsKey(scope.GridName__c) ? 'GridScopes' : 'GridRules';
                addError(result, sheetName, rowNumber, 'Failed to upsert GridScope__c for Grid "' + scope.GridName__c + '": ' + results[i].getErrors()[0].getMessage());
            }
        }

        return scopeIdByName;
    }

    private static Map<String, Id> upsertGrids(Set<String> gridNames, Map<String, Id> scopeIdByName, Map<String, Integer> scopeRowByName, Map<String, Integer> scopeRuleRowByName, ImportResult result) {
        Map<String, Id> gridIdByName = new Map<String, Id>();
        if (gridNames.isEmpty()) {
            return gridIdByName;
        }

        Map<String, Id> existingGridIdsByName = new Map<String, Id>();
        for (Grid__c grid : [SELECT Id, Name FROM Grid__c WHERE Name IN :gridNames]) {
            existingGridIdsByName.put(grid.Name, grid.Id);
        }

        List<Grid__c> toUpsert = new List<Grid__c>();
        List<String> namesForUpsert = new List<String>();
        for (String gridName : gridNames) {
            Id scopeId = scopeIdByName.get(gridName);
            if (scopeId == null) {
                Integer rowNumber = getRowNumber(gridName, scopeRowByName, scopeRuleRowByName);
                String sheetName = getSheetName(gridName, scopeRowByName, scopeRuleRowByName);
                addError(result, sheetName, rowNumber, 'GridScope__c not found or failed to create for Grid "' + gridName + '".');
                continue;
            }

            Grid__c grid = new Grid__c();
            grid.Name = gridName;
            grid.GridScope__c = scopeId;
            Id existingId = existingGridIdsByName.get(gridName);
            if (existingId != null) {
                grid.Id = existingId;
            }
            toUpsert.add(grid);
            namesForUpsert.add(gridName);
        }

        if (toUpsert.isEmpty()) {
            return gridIdByName;
        }

        Database.UpsertResult[] results = Database.upsert(toUpsert, false);
        for (Integer i = 0; i < results.size(); i++) {
            String gridName = namesForUpsert[i];
            if (results[i].isSuccess()) {
                gridIdByName.put(gridName, toUpsert[i].Id);
            } 
            else {
                Integer rowNumber = getRowNumber(gridName, scopeRowByName, scopeRuleRowByName);
                String sheetName = getSheetName(gridName, scopeRowByName, scopeRuleRowByName);
                addError(result, sheetName, rowNumber, 'Failed to upsert Grid__c for Grid "' + gridName + '": ' + results[i].getErrors()[0].getMessage());
            }
        }

        return gridIdByName;
    }

    private static Integer getRowNumber(String gridName, Map<String, Integer> scopeRowByName, Map<String, Integer> scopeRuleRowByName) {
        return scopeRowByName.containsKey(gridName) ? scopeRowByName.get(gridName) : scopeRuleRowByName.get(gridName);
    }

    private static String getSheetName(String gridName, Map<String, Integer> scopeRowByName, Map<String, Integer> scopeRuleRowByName) {
        return scopeRowByName.containsKey(gridName) ? 'GridScopes' : 'GridRules';
    }

    private static String getValueFromMap(String value, Map<String, String> referenceMap) {
        String key = String.isNotBlank(value)? normalize(value).toLowerCase() : null;
        return referenceMap.containsKey(key)? referenceMap.get(key) : null;
    }

    private static String normalize(String value) {
        return String.isNotBlank(value)? value.trim() : null;
    }

    private static String applyRuleValue(RuleContext ctx, RuleRow row) {
        String ruleValue = normalize(row.RuleValue);
        String shareType = normalize(row.ShareType);
        String otherShareType = normalize(row.OtherShareType);

        String pctError = validatePercentage(ruleValue);
        switch on ctx.ruleToApply {
            when 'Percentage of Fees' {
                if (pctError != null) {
                    return pctError;
                }
                ctx.percentageOfFees = parsePercent(ruleValue);
                ctx.otherShareType = null;
                ctx.otherGridRule = null;
                return null;
            }
            when 'Take Rebates Rate - Other Share Type' {
                String otherTypeError = requireValue(otherShareType, 'OtherShareType is required for Other Share Type.');
                if (otherTypeError != null) {
                    return otherTypeError;
                }
                ctx.otherShareType = otherShareType;
                ctx.percentageOfFees = null;
                ctx.otherGridRule = null;
                return null;
            }
            when 'Take Rebates Rate - Other Share Type + Fees' {
                String otherTypeError = requireValue(otherShareType, 'OtherShareType is required for Other Share Type + Fees.');
                if (otherTypeError != null) {
                    return otherTypeError;
                }
                String shareTypeError = requireValue(shareType, 'ShareType is required for Other Share Type + Fees.');
                if (shareTypeError != null) {
                    return shareTypeError;
                }
                if (pctError != null) {
                    return pctError;
                }
                ctx.otherShareType = otherShareType;
                ctx.percentageOfFees = parsePercent(ruleValue);
                ctx.otherGridRule = null;
                return null;
            }
            when 'Take Rebates Rate - Other Grid Rule' {
                String gridRuleError = requireValue(ruleValue, 'RuleValue is required for Other Grid Rule.');
                if (gridRuleError != null) {
                    return gridRuleError;
                }
                ctx.otherGridRule = ruleValue;
                ctx.percentageOfFees = null;
                ctx.otherShareType = null;
                return null;
            }
            when else {
                return 'Unsupported RuleToApply "' + ctx.ruleToApply + '".';
            }
        }
    }

    private static String requireValue(String value, String message) {
        return String.isBlank(value) ? message : null;
    }

    private static String validatePercentage(String value) {
        if (String.isBlank(value)) {
            return 'RuleValue is required for Percentage of Fees.';
        }
        if (parsePercent(value) == null) {
            return 'RuleValue "' + value + '" is not a valid percentage.';
        }
        return null;
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

    private static String buildGridScopeName(String gridName) {
        String creationDate = Date.today().format();
        return 'Grid Scope for ' + gridName + ' - ' + creationDate;
    }

    private static void addError(ImportResult result, String sheetName, Integer rowNumber, String message) {
        result.errors.add(new ImportError(sheetName, rowNumber, message));
    }

    // ------------------------------------ WRAPPERS ------------------------------------
    public class ImportResult {
        @AuraEnabled public Integer scopesUpserted = 0;
        @AuraEnabled public Integer criteriaCreated = 0;
        @AuraEnabled public Integer criteriaDetailsCreated = 0;
        @AuraEnabled public Integer ruleLinesCreated = 0;
        @AuraEnabled public Integer gridDetailsCreated = 0;
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
        public String ShareType;
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
        public String shareType;
        public String otherShareType;
        public String otherGridRule;
        public GridCriteria__c criteria;
        public Id criteriaId;
        public List<GridCriteriaExpressionParser.ParsedCondition> conditions;
        public Boolean hasErrors = false;
        public Boolean detailError = false;
        public RuleContext(Integer rowNumber, String gridName, Id gridId, Id scopeId, String ruleToApply, String feesType, String shareType, List<GridCriteriaExpressionParser.ParsedCondition> conditions) {
            this.rowNumber = rowNumber;
            this.gridName = gridName;
            this.gridId = gridId;
            this.scopeId = scopeId;
            this.ruleToApply = ruleToApply;
            this.feesType = feesType;
            this.shareType = shareType;
            this.conditions = conditions;
        }
    }

    private class DetailContext {
        public GridCriteriaDetail__c detail;
        public RuleContext context;
        public DetailContext(GridCriteriaDetail__c detail, RuleContext context) {
            this.detail = detail;
            this.context = context;
        }
    }

    private class DetailBuildResult {
        public List<GridCriteriaDetail__c> details = new List<GridCriteriaDetail__c>();
        public List<DetailContext> contexts = new List<DetailContext>();
    }

    private class ScopeCollection {
        public Map<String, GridScope__c> scopesByName = new Map<String, GridScope__c>();
        public Map<String, Integer> scopeRowByName = new Map<String, Integer>();
        public Map<String, Integer> scopeRuleRowByName = new Map<String, Integer>();
        public Set<String> gridNames = new Set<String>();
    }
}