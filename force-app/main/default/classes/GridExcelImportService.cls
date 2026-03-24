/** ──────────────────────────────────────
 * @description Service class for importing grid configurations from Excel/JSON payloads.
 *              Parses scope and rule definitions, creates/updates GridScope__c, GridCriteria__c, GridCriteriaDetail__c, and
 *              GridRule__c records.
 *              Integrates with GridCriteriaExpressionParser for Include/Exclude expression parsing.
 *              Provides comprehensive error tracking and validation.
 * @author Charles EID
 * @testClass GridExcelImportServiceTest
 * @coverage 86%   [19-03-26]
────────────────────────────────────── */
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
        Map<String, Id> gridIdByName = upsertGrids(scopeCollection.gridNames, scopeCollection.scopeRowByName, scopeCollection.scopeRuleRowByName, result);
        Map<String, Id> scopeIdByName = upsertScopes(scopeCollection.scopesByName, gridIdByName, scopeCollection.scopeRowByName, scopeCollection.scopeRuleRowByName, result);

        List<RuleContext> ruleContexts = buildRuleContexts(ruleRows, gridIdByName, scopeIdByName, result);
        if (ruleContexts.isEmpty()) {
            return result;
        }

        resolveExistingRules(ruleContexts, gridIdByName);
        insertCriteria(ruleContexts, result);
        DetailBuildResult detailBuildResult = buildDetailContexts(ruleContexts);
        insertDetails(detailBuildResult, result);
        Map<Id, Integer> rowByRuleId = upsertGridRules(ruleContexts, result);
        buildGridDetails(rowByRuleId, result);
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

        String rebateRateRaw = normalize(row.RebateRate);
        if (String.isNotBlank(rebateRateRaw)) {
            Decimal parsed = parsePercent(rebateRateRaw);
            if (parsed == null) {
                addError(result, 'GridRules', rowNumber, 'RebateRate "' + rebateRateRaw + '" is not a valid percentage.');
                return null;
            }
            ctx.finalRebateRate = parsed;
        }

        ctx.criteria = buildCriteria(gridName, gridId, rowNumber, row, parseResult.filterLogicExpression);
        ctx.ruleText = buildRuleText(row, ctx.ruleToApply);
        return ctx;
    }

    private static String buildRuleText(RuleRow row, String ruleToApply) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(row.Grid))           parts.add('Grid: '           + row.Grid);
        if (String.isNotBlank(row.Include))        parts.add('Include: '        + row.Include);
        if (String.isNotBlank(row.Exclude))        parts.add('Exclude: '        + row.Exclude);
        if (String.isNotBlank(row.Comment))        parts.add('Comment: '        + row.Comment);
        if (String.isNotBlank(ruleToApply))        parts.add('RuleToApply: '    + ruleToApply);
        if (String.isNotBlank(row.FeesType))       parts.add('FeesType: '       + row.FeesType);
        if (String.isNotBlank(row.RuleValue))      parts.add('RuleValue: '      + row.RuleValue);
        if (String.isNotBlank(row.ShareType))      parts.add('ShareType: '      + row.ShareType);
        if (String.isNotBlank(row.OtherShareType)) parts.add('OtherShareType: ' + row.OtherShareType);
        if (String.isNotBlank(row.RebateRate))     parts.add('RebateRate: '     + row.RebateRate);
        return String.join(parts, '\n');
    }

    private static GridCriteria__c buildCriteria(String gridName, Id gridId, Integer rowNumber, RuleRow row, String logicExpression) {
        GridCriteria__c criteria = new GridCriteria__c();
        criteria.Name = buildCriteriaName(gridName, rowNumber);
        criteria.Grid__c = gridId;
        criteria.Comment__c = normalize(row.Comment);
        criteria.StartDate__c = START_DATE;
        criteria.EndDate__c = END_DATE;
        criteria.FilterLogic__c = 'Custom Logic';
        criteria.FilterLogicExpression__c = logicExpression;
        return criteria;
    }

    // ── Rule deduplication ──
    private static void resolveExistingRules(List<RuleContext> ruleContexts, Map<String, Id> gridIdByName) {
        Set<Id> gridIds = new Set<Id>(gridIdByName.values());

        // Load all existing GridRule__c for these grids
        List<GridRule__c> existingRules = [SELECT Id, Grid__c, GridCriteria__c
                                           FROM GridRule__c
                                           WHERE Grid__c IN :gridIds];
        if (existingRules.isEmpty()) {
            return;
        }

        Set<Id> criteriaIds = new Set<Id>();
        for (GridRule__c gr : existingRules) {
            if (gr.GridCriteria__c != null) {
                criteriaIds.add(gr.GridCriteria__c);
            }
        }

        // Load FilterLogicExpression for each existing criteria
        Map<Id, String> logicByCriteriaId = new Map<Id, String>();
        for (GridCriteria__c gc : [SELECT Id, FilterLogicExpression__c FROM GridCriteria__c WHERE Id IN :criteriaIds]) {
            logicByCriteriaId.put(gc.Id, gc.FilterLogicExpression__c);
        }

        // Load details for each existing criteria
        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId = new Map<Id, List<GridCriteriaDetail__c>>();
        for (GridCriteriaDetail__c d : [SELECT GridCriteria__c, FilterNumber__c, Object__c, Field__c, Logic__c, Value__c
                                        FROM GridCriteriaDetail__c
                                        WHERE GridCriteria__c IN :criteriaIds
                                        ORDER BY FilterNumber__c ASC]) {
            if (!detailsByCriteriaId.containsKey(d.GridCriteria__c)) {
                detailsByCriteriaId.put(d.GridCriteria__c, new List<GridCriteriaDetail__c>());
            }
            detailsByCriteriaId.get(d.GridCriteria__c).add(d);
        }

        // Build fingerprint → GridRule__c map
        Map<String, GridRule__c> existingByFingerprint = new Map<String, GridRule__c>();
        for (GridRule__c gr : existingRules) {
            Id cId = gr.GridCriteria__c;
            String logicExpr = logicByCriteriaId.get(cId);
            List<GridCriteriaDetail__c> details = detailsByCriteriaId.get(cId);
            List<String> condParts = new List<String>();
            if (details != null) {
                for (GridCriteriaDetail__c d : details) {
                    condParts.add(buildConditionPart(String.valueOf(d.FilterNumber__c != null ? d.FilterNumber__c.intValue() : 0), d.Object__c, d.Field__c, d.Logic__c, d.Value__c));
                }
            }
            existingByFingerprint.put(buildCriteriaFingerprint(gr.Grid__c, logicExpr, condParts), gr);
        }

        // Match each incoming context against existing
        for (RuleContext ctx : ruleContexts) {
            List<String> condParts = new List<String>();
            if (ctx.conditions != null) {
                for (GridCriteriaExpressionParser.ParsedCondition c : ctx.conditions) {
                    condParts.add(buildConditionPart(String.valueOf(c.filterNumber), c.objectApiName, c.fieldApiName, c.logic, c.value));
                }
            }
            GridRule__c match = existingByFingerprint.get(buildCriteriaFingerprint(ctx.gridId, ctx.criteria.FilterLogicExpression__c, condParts));
            if (match != null) {
                ctx.existingRuleId     = match.Id;
                ctx.existingCriteriaId = match.GridCriteria__c;
            }
        }
    }

    private static String buildCriteriaFingerprint(Id gridId, String logicExpr, List<String> condParts) {
        condParts.sort();
        return gridId + '_-_' + String.valueOf(logicExpr) + '_-_' + String.join(condParts, '_-_');
    }

    private static String buildConditionPart(String filterNumber, String objectName, String field, String logic, String value) {
        return filterNumber + '_-_' + objectName + '_-_' + field + '_-_' + logic + '_-_' + value;
    }

    // ── Criteria & Details ──
    private static void insertCriteria(List<RuleContext> ruleContexts, ImportResult result) {
        List<GridCriteria__c> criteriaToInsert = new List<GridCriteria__c>();
        List<RuleContext> contextsForInsert = new List<RuleContext>();
        for (RuleContext ctx : ruleContexts) {
            if (ctx.existingRuleId != null) {
                continue;  // reusing existing criteria — nothing to insert
            }
            criteriaToInsert.add(ctx.criteria);
            contextsForInsert.add(ctx);
        }

        if (criteriaToInsert.isEmpty()) {
            return;
        }

        Database.SaveResult[] criteriaResults = Database.insert(criteriaToInsert, false);
        for (Integer i = 0; i < criteriaResults.size(); i++) {
            RuleContext ctx = contextsForInsert[i];
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
            if (ctx.hasErrors || ctx.existingRuleId != null) {
                continue;  // skip errored contexts and contexts reusing an existing rule
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

    // ── Grid Rules ──

    private static Map<Id, Integer> upsertGridRules(List<RuleContext> ruleContexts, ImportResult result) {
        List<GridRule__c> gridRules = new List<GridRule__c>();
        List<RuleContext> gridRuleContexts = new List<RuleContext>();
        for (RuleContext ctx : ruleContexts) {
            if (ctx.hasErrors || ctx.detailError) {
                continue;
            }
            GridRule__c gr = new GridRule__c();
            if (ctx.existingRuleId != null) {
                gr.Id = ctx.existingRuleId;                                    // update existing
            }
            gr.Grid__c          = ctx.gridId;
            gr.GridCriteria__c  = ctx.existingRuleId != null ? ctx.existingCriteriaId : ctx.criteriaId;
            gr.RuleToApply__c   = ctx.ruleToApply;
            gr.FeesType__c      = ctx.feesType;
            gr.GridRate__c      = ctx.percentageOfFees;
            gr.ShareType__c     = ctx.shareType;
            gr.OtherShareType__c = ctx.otherShareType;
            gr.OtherGridRule__c = ctx.otherGridRule;
            gr.FinalRebateRate__c = ctx.finalRebateRate;
            gr.RuleText__c      = ctx.ruleText;
            gridRules.add(gr);
            gridRuleContexts.add(ctx);
        }

        if (gridRules.isEmpty()) {
            return new Map<Id, Integer>();
        }

        Database.UpsertResult[] gridRuleResults = Database.upsert(gridRules, false);
        Map<Id, Integer> rowByRuleId = new Map<Id, Integer>();
        for (Integer i = 0; i < gridRuleResults.size(); i++) {
            RuleContext ctx = gridRuleContexts[i];
            if (gridRuleResults[i].isSuccess()) {
                if (gridRuleResults[i].isCreated()) {
                    result.gridRulesCreated++;
                } else {
                    result.gridRulesUpdated++;
                }
                rowByRuleId.put(gridRules[i].Id, ctx.rowNumber);
            }
            else {
                addError(result, 'GridRules', ctx.rowNumber, 'Failed to upsert GridRule__c: ' + gridRuleResults[i].getErrors()[0].getMessage());
            }
        }
        return rowByRuleId;
    }

    private static void buildGridDetails(Map<Id, Integer> rowByRuleId, ImportResult result) {
        if (rowByRuleId.isEmpty()) {
            return;
        }
        GridDetailBuilder.BuildResult detailResult = GridDetailBuilder.buildForGridRules(rowByRuleId.keySet());
        result.gridDetailsCreated += detailResult.gridDetailsCreated;
        result.gridDetailsUpdated += detailResult.gridDetailsUpdated;
        if (detailResult.errors != null) {
            for (GridDetailBuilder.BuildError detailError : detailResult.errors) {
                Integer rowNumber = detailError.gridRuleId != null ? rowByRuleId.get(detailError.gridRuleId) : null;
                addError(result, 'GridRules', rowNumber, detailError.message);
            }
        }
    }

    private static Integer getRowNumber(ScopeRow row) {
        return row != null && row.rowNumber != null ? row.rowNumber : -1;
    }

    private static Integer getRowNumber(RuleRow row) {
        return row != null && row.rowNumber != null ? row.rowNumber : -1;
    }

    private static Map<String, Id> upsertScopes(Map<String, GridScope__c> scopesByName, Map<String, Id> gridIdByName, Map<String, Integer> scopeRowByName, Map<String, Integer> scopeRuleRowByName, ImportResult result) {
        Map<String, Id> scopeIdByName = new Map<String, Id>();
        if (scopesByName.isEmpty()) {
            return scopeIdByName;
        }

        Set<Id> gridIds = new Set<Id>();
        for (String gridName : scopesByName.keySet()) {
            Id gId = gridIdByName.get(gridName);
            if (gId != null) {
                gridIds.add(gId);
            }
        }

        Map<Id, GridScope__c> existingByGridId = new Map<Id, GridScope__c>();
        for (GridScope__c scope : [SELECT Id, Grid__c FROM GridScope__c WHERE Grid__c IN :gridIds]) {
            existingByGridId.put(scope.Grid__c, scope);
        }

        List<GridScope__c> toUpsert = new List<GridScope__c>();
        List<String> toUpsertGridNames = new List<String>();
        for (String gridName : scopesByName.keySet()) {
            GridScope__c scope = scopesByName.get(gridName);
            Id gridId = gridIdByName.get(gridName);
            scope.Grid__c = gridId;
            if (gridId != null) {
                GridScope__c existing = existingByGridId.get(gridId);
                if (existing != null) {
                    scope.Id = existing.Id;
                }
            }
            toUpsert.add(scope);
            toUpsertGridNames.add(gridName);
        }

        Database.UpsertResult[] results = Database.upsert(toUpsert, false);
        for (Integer i = 0; i < results.size(); i++) {
            String gridName = toUpsertGridNames[i];
            if (results[i].isSuccess()) {
                result.scopesUpserted++;
                scopeIdByName.put(gridName, toUpsert[i].Id);
            }
            else {
                Integer rowNumber = scopeRowByName.containsKey(gridName) ? scopeRowByName.get(gridName) : scopeRuleRowByName.get(gridName);
                String sheetName = scopeRowByName.containsKey(gridName) ? 'GridScopes' : 'GridRules';
                addError(result, sheetName, rowNumber, 'Failed to upsert GridScope__c for Grid "' + gridName + '": ' + results[i].getErrors()[0].getMessage());
            }
        }

        return scopeIdByName;
    }

    private static Map<String, Id> upsertGrids(Set<String> gridNames, Map<String, Integer> scopeRowByName, Map<String, Integer> scopeRuleRowByName, ImportResult result) {
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
            Grid__c grid = new Grid__c();
            grid.Name = gridName;
            grid.RecordTypeId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_STANDARD_GRID).getRecordTypeId();
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
                result.gridsUpserted++;
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

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class ImportResult {
        @AuraEnabled public Integer gridsUpserted          = 0;
        @AuraEnabled public Integer scopesUpserted         = 0;
        @AuraEnabled public Integer criteriaCreated        = 0;
        @AuraEnabled public Integer criteriaDetailsCreated = 0;
        @AuraEnabled public Integer gridRulesCreated       = 0;
        @AuraEnabled public Integer gridRulesUpdated       = 0;
        @AuraEnabled public Integer gridDetailsCreated     = 0;
        @AuraEnabled public Integer gridDetailsUpdated     = 0;
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
        public String RebateRate;
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
        public Decimal finalRebateRate;
        public GridCriteria__c criteria;
        public Id criteriaId;
        public Id existingRuleId;      // non-null when a matching rule already exists in DB
        public Id existingCriteriaId;  // criteria of the existing rule (used to keep the link)
        public List<GridCriteriaExpressionParser.ParsedCondition> conditions;
        public String ruleText;
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