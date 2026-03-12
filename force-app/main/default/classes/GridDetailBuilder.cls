/** ──────────────────────────────────────
 * @description Core service class that builds GridDetail__c records by evaluating GridRule__c rules
 *              against Share_Class__c records. 
 *              Implements complex rebate calculation logic including percentage-based fees, cross-share-type references, 
 *              and cross-grid rule dependencies.
 *              Supports multi-pass resolution for interdependent rules and postfix expression evaluation
 *              for complex filter logic (AND/OR/parentheses).
 * @author Charles EID
 * @testClass GridDetailBuilderTest
 * @coverage 84%
────────────────────────────────────── */
public with sharing class GridDetailBuilder {
    private static final Date DEFAULT_END_DATE = Date.newInstance(2099, 12, 31);

    private static final String RULE_PERCENTAGE = 'Percentage of Fees';
    private static final String RULE_OTHER_SHARE = 'Take Rebates Rate - Other Share Type';
    private static final String RULE_OTHER_SHARE_FEES = 'Take Rebates Rate - Other Share Type + Fees';
    private static final String RULE_OTHER_GRID = 'Take Rebates Rate - Other Grid Rule';

    private static final String TYPE_FIELD_PATH = 'Type__c';
    private static final Set<String> SUPPORTED_OBJECTS = new Set<String>{ 'Share_Class__c', 'Product__c', 'Strategy__c' };

    private static final String gridRulesQuery = 'SELECT Id, Grid__c, GridCriteria__c, RuleToApply__c, GridRate__c, '+
                                                    'ShareType__c, OtherShareType__c, OtherGridRule__c, '+
                                                    'GridCriteria__r.FilterLogicExpression__c, CreatedDate '+
                                                  ' FROM GridRule__c ';

    public static BuildResult buildForGridRules(Set<Id> gridRuleIds) {
        BuildResult result = new BuildResult();
        result.errors = new List<BuildError>();
        if (gridRuleIds == null || gridRuleIds.isEmpty()) {
            return result;
        }

        String rlQuery = gridRulesQuery + ' WHERE Id IN :gridRuleIds ORDER BY CreatedDate ASC';
        return build(Database.query(rlQuery), result);
    }

    public static BuildResult buildForGrids(Set<Id> gridIds) {
        BuildResult result = new BuildResult();
        result.errors = new List<BuildError>();
        if (gridIds == null || gridIds.isEmpty()) {
            return result;
        }

        Map<String, Id> gridIdByName = new Map<String, Id>();
        for (Grid__c grid : [SELECT Id, Name FROM Grid__c WHERE Id IN :gridIds]) {
            gridIdByName.put(grid.Name, grid.Id);
        }

        String rlQuery = gridRulesQuery + ' WHERE Grid__c IN :gridIds ORDER BY CreatedDate ASC';
        return build(Database.query(rlQuery), gridIdByName, result);
    }

    private static BuildResult build(List<GridRule__c> gridRules, BuildResult result) {
        if (gridRules == null || gridRules.isEmpty()) {
            return result;
        }

        Set<Id> gridIds = new Set<Id>();
        for (GridRule__c line : gridRules) {
            if (line.Grid__c != null) {
                gridIds.add(line.Grid__c);
            }
        }

        Map<String, Id> gridIdByName = new Map<String, Id>();
        for (Grid__c grid : [SELECT Id, Name FROM Grid__c WHERE Id IN :gridIds]) {
            gridIdByName.put(grid.Name, grid.Id);
        }

        return build(gridRules, gridIdByName, result);
    }

    private static BuildResult build(List<GridRule__c> gridRules, Map<String, Id> gridIdByName, BuildResult result) {
        if (gridRules == null || gridRules.isEmpty()) {
            return result;
        }

        ensureOtherGridIds(gridRules, gridIdByName);
        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId = loadCriteriaDetails(gridRules);
        ShareClassData shareData = loadShareClasses();
        List<GridRuleContext> contexts = buildGridRuleContexts(gridRules, detailsByCriteriaId, result);
        if (contexts.isEmpty()) {
            return result;
        }

        AssignmentBuildResult assignmentBuild = buildAssignments(contexts, shareData, result);
        if (assignmentBuild.assignments.isEmpty()) {
            return result;
        }

        Map<String, Decimal> rebatesByGridShareKey = computeRebatesForAssignments(assignmentBuild, shareData, gridIdByName, result);
        addMissingRebateErrors(assignmentBuild.assignments, rebatesByGridShareKey, result);
        insertGridDetails(assignmentBuild.assignments, result);
        return result;
    }

    private static void ensureOtherGridIds(List<GridRule__c> gridRules, Map<String, Id> gridIdByName) {
        Set<String> otherGridNames = new Set<String>();
        for (GridRule__c line : gridRules) {
            if (line.RuleToApply__c == RULE_OTHER_GRID && String.isNotBlank(line.OtherGridRule__c)) {
                otherGridNames.add(line.OtherGridRule__c);
            }
        }
        if (!otherGridNames.isEmpty()) {
            ensureGridIds(otherGridNames, gridIdByName);
        }
    }

    private static Map<Id, List<GridCriteriaDetail__c>> loadCriteriaDetails(List<GridRule__c> gridRules) {
        Set<Id> criteriaIds = new Set<Id>();
        for (GridRule__c line : gridRules) {
            if (line.GridCriteria__c != null) {
                criteriaIds.add(line.GridCriteria__c);
            }
        }

        Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId = new Map<Id, List<GridCriteriaDetail__c>>();
        if (criteriaIds.isEmpty()) {
            return detailsByCriteriaId;
        }

        for (GridCriteriaDetail__c detail : [SELECT GridCriteria__c, FilterNumber__c, Logic__c, Value__c, Object__c, Field__c
                                             FROM GridCriteriaDetail__c
                                             WHERE GridCriteria__c IN :criteriaIds
                                             ORDER BY FilterNumber__c ASC]) {
            if (!detailsByCriteriaId.containsKey(detail.GridCriteria__c)) {
                detailsByCriteriaId.put(detail.GridCriteria__c, new List<GridCriteriaDetail__c>());
            }
            detailsByCriteriaId.get(detail.GridCriteria__c).add(detail);
        }
        return detailsByCriteriaId;
    }

    private static ShareClassData loadShareClasses() {
        ShareClassData data = new ShareClassData();
        data.shareClasses = [SELECT Id, Type__c, ISIN__c, EffectiveManagementFees__c, Fund__c, Fund__r.Legal_Status__c, Fund__r.InternalShortName__c
                             FROM Share_Class__c
                             WHERE EffectiveManagementFees__c != null
                             AND Type__c != null
                             AND Currency__c != 'JPY'
                             AND Id IN (SELECT ShareClass__c FROM Country__c WHERE (RegistrationStatus__c = 'REG' OR RegistrationStatus__c = 'INSTITUTIONAL_ONLY'))
                             AND Status__c != 'Active - Lab'];
        data.shareClassById = new Map<Id, Share_Class__c>(data.shareClasses);
        data.allShareClassIds = new Set<Id>(data.shareClassById.keySet());
        data.indexByField = buildShareClassIndex(data.shareClasses);
        return data;
    }

    private static List<GridRuleContext> buildGridRuleContexts(List<GridRule__c> gridRules, Map<Id, List<GridCriteriaDetail__c>> detailsByCriteriaId, BuildResult result) {
        List<GridRuleContext> contexts = new List<GridRuleContext>();
        for (GridRule__c line : gridRules) {
            GridRuleContext ctx = new GridRuleContext(line);
            ctx.gridId = line.Grid__c;
            if (ctx.gridId == null) {
                ctx.hasErrors = true;
                result.errors.add(new BuildError(line.Id, 'Grid__c is missing on GridRule__c.'));
            }
            if (line.GridCriteria__c == null) {
                ctx.hasErrors = true;
                result.errors.add(new BuildError(line.Id, 'GridCriteria__c is missing on GridRule__c.'));
            }
            ctx.filterLogicExpression = line.GridCriteria__r != null ? line.GridCriteria__r.FilterLogicExpression__c : null;
            ctx.details = detailsByCriteriaId.containsKey(line.GridCriteria__c) ? detailsByCriteriaId.get(line.GridCriteria__c) : new List<GridCriteriaDetail__c>();
            if (ctx.details.isEmpty()) {
                ctx.hasErrors = true;
                result.errors.add(new BuildError(line.Id, 'No GridCriteriaDetail__c found for the linked GridCriteria__c.'));
            }
            contexts.add(ctx);
        }
        return contexts;
    }

    private static AssignmentBuildResult buildAssignments(List<GridRuleContext> contexts, ShareClassData shareData, BuildResult result) {
        AssignmentBuildResult assignmentBuild = new AssignmentBuildResult();

        for (GridRuleContext ctx : contexts) {
            if (ctx.hasErrors) {
                continue;
            }

            Set<Id> matches = evaluateCriteria(ctx, shareData.indexByField, shareData.allShareClassIds, result);
            if (ctx.hasErrors || matches.isEmpty()) {
                continue;
            }

            matches = filterByShareTypeIfNeeded(ctx, matches, shareData.shareClassById);
            for (Id shareId : matches) {
                String gridShareKey = buildGridShareKey(ctx.gridId, shareId);
                if (assignmentBuild.assignmentByGridShareKey.containsKey(gridShareKey)) {
                    continue;
                }
                RuleAssignment assignment = new RuleAssignment(ctx, shareId);
                assignmentBuild.assignmentByGridShareKey.put(gridShareKey, assignment);
                assignmentBuild.assignments.add(assignment);
            }
        }

        return assignmentBuild;
    }

    private static Set<Id> filterByShareTypeIfNeeded(GridRuleContext ctx, Set<Id> matches, Map<Id, Share_Class__c> shareClassById) {
        if (RULE_OTHER_SHARE_FEES != ctx.gridRule.RuleToApply__c || String.isBlank(ctx.gridRule.ShareType__c)) {
            return matches;
        }
        Set<Id> filtered = new Set<Id>();
        for (Id shareId : matches) {
            Share_Class__c share = shareClassById.get(shareId);
            if (share != null && share.Type__c == ctx.gridRule.ShareType__c) {
                filtered.add(shareId);
            }
        }
        return filtered;
    }

    private static Map<String, Decimal> computeRebatesForAssignments(AssignmentBuildResult assignmentBuild, ShareClassData shareData, Map<String, Id> gridIdByName, BuildResult result) {
        Map<String, Decimal> rebatesByGridShareKey = new Map<String, Decimal>();
        Map<String, Decimal> existingRebates = loadExistingRebates(assignmentBuild.assignments, gridIdByName, assignmentBuild.assignmentByGridShareKey.keySet());
        Map<String, Map<String, Id>> shareTypeLookupCache = new Map<String, Map<String, Id>>();

        Integer remaining = assignmentBuild.assignments.size();
        for (Integer pass = 0; pass < 6 && remaining > 0; pass++) {
            Integer computedInPass = computeRebatesPass(assignmentBuild, shareData, gridIdByName, existingRebates, shareTypeLookupCache, rebatesByGridShareKey, result);
            if (computedInPass == 0) {
                break;
            }
            remaining -= computedInPass;
        }

        return rebatesByGridShareKey;
    }

    private static Integer computeRebatesPass(AssignmentBuildResult assignmentBuild, ShareClassData shareData, Map<String, Id> gridIdByName, Map<String, Decimal> existingRebates, Map<String, Map<String, Id>> shareTypeLookupCache, Map<String, Decimal> rebatesByGridShareKey, BuildResult result) {
        Integer computedInPass = 0;
        for (RuleAssignment assignment : assignmentBuild.assignments) {
            if (assignment.hasError || rebatesByGridShareKey.containsKey(assignment.gridShareKey)) {
                continue;
            }
            Decimal rebate = computeRebate(assignment, assignmentBuild.assignmentByGridShareKey, rebatesByGridShareKey, existingRebates, shareTypeLookupCache, shareData.shareClasses, shareData.shareClassById, gridIdByName, result);
            if (assignment.hasError) {
                continue;
            }
            if (rebate != null) {
                assignment.rebate = rebate;
                rebatesByGridShareKey.put(assignment.gridShareKey, rebate);
                computedInPass++;
            }
        }
        return computedInPass;
    }

    private static void addMissingRebateErrors(List<RuleAssignment> assignments, Map<String, Decimal> rebatesByGridShareKey, BuildResult result) {
        for (RuleAssignment assignment : assignments) {
            if (assignment.hasError) {
                continue;
            }
            if (!rebatesByGridShareKey.containsKey(assignment.gridShareKey)) {
                assignment.hasError = true;
                result.errors.add(new BuildError(assignment.gridRuleId, 'Unable to resolve a rebate value for GridRule__c. Check dependent rules or missing matching share classes.'));
            }
        }
    }

    private static void insertGridDetails(List<RuleAssignment> assignments, BuildResult result) {
        List<GridDetail__c> detailsToInsert = new List<GridDetail__c>();
        List<RuleAssignment> assignmentsForInsert = new List<RuleAssignment>();
        Date startDate = Date.today();
        Id standardGridDetailRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_STANDARD_GRID_DETAIL).getRecordTypeId();
        for (RuleAssignment assignment : assignments) {
            if (assignment.hasError || assignment.rebate == null) {
                continue;
            }
            GridDetail__c detail = new GridDetail__c();
            detail.RecordTypeId = standardGridDetailRtId;
            detail.Grid__c = assignment.gridId;
            detail.GridRule__c = assignment.gridRuleId;
            detail.GridCriteria__c = assignment.criteriaId;
            detail.ShareClass__c = assignment.shareClassId;
            detail.RebateRate__c = assignment.rebate;
            detail.StartDate__c = startDate;
            detail.EndDate__c = DEFAULT_END_DATE;
            detailsToInsert.add(detail);
            assignmentsForInsert.add(assignment);
        }

        if (detailsToInsert.isEmpty()) {
            return;
        }

        Database.SaveResult[] insertResults = Database.insert(detailsToInsert, false);
        for (Integer i = 0; i < insertResults.size(); i++) {
            RuleAssignment assignment = assignmentsForInsert[i];
            if (insertResults[i].isSuccess()) {
                result.gridDetailsCreated++;
            } else {
                result.errors.add(new BuildError(assignment.gridRuleId, 'Failed to create GridDetail__c: ' + insertResults[i].getErrors()[0].getMessage()));
            }
        }
    }

    private static Set<Id> evaluateCriteria(GridRuleContext ctx, Map<String, Map<String, Set<Id>>> indexByField, Set<Id> allShareClassIds, BuildResult result) {
        Map<Integer, Set<Id>> conditionSets = new Map<Integer, Set<Id>>();
        ctx.resolvedFieldPaths.clear();

        for (GridCriteriaDetail__c detail : ctx.details) {
            Integer filterNumber = detail.FilterNumber__c != null ? detail.FilterNumber__c.intValue() : null;
            if (filterNumber == null) {
                ctx.hasErrors = true;
                result.errors.add(new BuildError(ctx.gridRule.Id, 'FilterNumber__c is missing for a GridCriteriaDetail__c.'));
                return new Set<Id>();
            }
            String fieldPath = resolveFieldPath(detail.Object__c, detail.Field__c);
            if (fieldPath == null) {
                ctx.hasErrors = true;
                result.errors.add(new BuildError(ctx.gridRule.Id, 'Unsupported criteria field mapping for Object__c "' + detail.Object__c + '" and Field__c "' + detail.Field__c + '".'));
                return new Set<Id>();
            }
            ctx.resolvedFieldPaths.add(fieldPath);
            Set<Id> conditionSet = buildConditionSet(detail, fieldPath, indexByField, allShareClassIds, result, ctx.gridRule.Id);
            if (conditionSet == null) {
                ctx.hasErrors = true;
                return new Set<Id>();
            }
            conditionSets.put(filterNumber, conditionSet);
        }

        if (String.isBlank(ctx.filterLogicExpression)) {
            ctx.hasErrors = true;
            result.errors.add(new BuildError(ctx.gridRule.Id, 'FilterLogicExpression__c is missing for GridCriteria__c.'));
            return new Set<Id>();
        }

        return evaluateExpression(ctx.filterLogicExpression, conditionSets, result, ctx.gridRule.Id);
    }

    private static Set<Id> buildConditionSet(GridCriteriaDetail__c detail, String fieldPath, Map<String, Map<String, Set<Id>>> indexByField, Set<Id> allShareClassIds, BuildResult result, Id gridRuleId) {
        List<String> values = splitValues(detail.Value__c);
        if (values.isEmpty()) {
            result.errors.add(new BuildError(gridRuleId, 'Value__c is blank for a GridCriteriaDetail__c.'));
            return null;
        }

        Map<String, Set<Id>> valueIndex = indexByField.get(fieldPath);
        if (valueIndex == null) {
            result.errors.add(new BuildError(gridRuleId, 'No share class index found for field "' + fieldPath + '".'));
            return null;
        }

        Set<Id> matching = new Set<Id>();
        for (String value : values) {
            if (String.isBlank(value)) {
                continue;
            }
            Set<Id> ids = valueIndex.get(value);
            if (ids != null) {
                matching.addAll(ids);
            }
        }

        String logic = detail.Logic__c;
        if (logic == '=' || logic == 'IN') {
            return matching;
        }
        if (logic == '!=' || logic == 'NOT IN') {
            Set<Id> remaining = new Set<Id>(allShareClassIds);
            remaining.removeAll(matching);
            return remaining;
        }

        result.errors.add(new BuildError(gridRuleId, 'Unsupported Logic__c "' + logic + '" in GridCriteriaDetail__c.'));
        return null;
    }

    private static Set<Id> evaluateExpression(String expression, Map<Integer, Set<Id>> conditionSets, BuildResult result, Id gridRuleId) {
        List<String> tokens = tokenizeExpression(expression, result, gridRuleId);
        if (tokens.isEmpty()) {
            return new Set<Id>();
        }

        List<String> output = toPostfix(tokens, result, gridRuleId);
        if (output == null) {
            return new Set<Id>();
        }
        return evaluatePostfix(output, conditionSets, result, gridRuleId);
    }

    private static List<String> toPostfix(List<String> tokens, BuildResult result, Id gridRuleId) {
        List<String> output = new List<String>();
        List<String> operators = new List<String>();

        for (String token : tokens) {
            if (isNumberToken(token)) {
                output.add(token);
                continue;
            }
            if (isLogicToken(token)) {
                applyOperatorToken(token, operators, output);
                continue;
            }
            if (token == '(') {
                operators.add(token);
                continue;
            }
            if (token == ')') {
                if (!flushUntilOpenParen(operators, output, result, gridRuleId)) {
                    return null;
                }
                continue;
            }
            result.errors.add(new BuildError(gridRuleId, 'Unsupported token "' + token + '" in FilterLogicExpression__c.'));
            return null;
        }

        if (!flushRemainingOperators(operators, output, result, gridRuleId)) {
            return null;
        }
        return output;
    }

    private static Boolean flushUntilOpenParen(List<String> operators, List<String> output, BuildResult result, Id gridRuleId) {
        while (!operators.isEmpty() && operators[operators.size() - 1] != '(') {
            output.add(operators.remove(operators.size() - 1));
        }
        if (operators.isEmpty() || operators[operators.size() - 1] != '(') {
            result.errors.add(new BuildError(gridRuleId, 'Unbalanced parentheses in FilterLogicExpression__c.'));
            return false;
        }
        operators.remove(operators.size() - 1);
        return true;
    }

    private static Boolean flushRemainingOperators(List<String> operators, List<String> output, BuildResult result, Id gridRuleId) {
        while (!operators.isEmpty()) {
            String op = operators.remove(operators.size() - 1);
            if (op == '(' || op == ')') {
                result.errors.add(new BuildError(gridRuleId, 'Unbalanced parentheses in FilterLogicExpression__c.'));
                return false;
            }
            output.add(op);
        }
        return true;
    }

    private static void applyOperatorToken(String token, List<String> operators, List<String> output) {
        while (!operators.isEmpty() && operators[operators.size() - 1] != '(' && getPrecedence(operators[operators.size() - 1]) >= getPrecedence(token)) {
            output.add(operators.remove(operators.size() - 1));
        }
        operators.add(token);
    }

    private static Integer getPrecedence(String token) {
        return token == 'AND' ? 2 : 1;
    }

    private static Boolean isLogicToken(String token) {
        return token == 'AND' || token == 'OR';
    }

    private static Set<Id> evaluatePostfix(List<String> output, Map<Integer, Set<Id>> conditionSets, BuildResult result, Id gridRuleId) {
        List<Set<Id>> stack = new List<Set<Id>>();
        for (String token : output) {
            if (isNumberToken(token)) {
                Integer key = Integer.valueOf(token);
                Set<Id> setValue = conditionSets.get(key);
                if (setValue == null) {
                    result.errors.add(new BuildError(gridRuleId, 'FilterLogicExpression__c references missing condition ' + token + '.'));
                    return new Set<Id>();
                }
                stack.add(setValue);
                continue;
            }
            if (isLogicToken(token)) {
                if (stack.size() < 2) {
                    result.errors.add(new BuildError(gridRuleId, 'Invalid FilterLogicExpression__c evaluation.'));
                    return new Set<Id>();
                }
                Set<Id> right = stack.remove(stack.size() - 1);
                Set<Id> left = stack.remove(stack.size() - 1);
                Set<Id> combined = token == 'AND' ? intersectSets(left, right) : unionSets(left, right);
                stack.add(combined);
            }
        }
        return stack.isEmpty() ? new Set<Id>() : stack[0];
    }

    private static Decimal computeRebate(RuleAssignment assignment, Map<String, RuleAssignment> assignmentByGridShareKey, Map<String, Decimal> rebatesByGridShareKey, Map<String, Decimal> existingRebates, Map<String, Map<String, Id>> shareTypeLookupCache, List<Share_Class__c> shareClasses, Map<Id, Share_Class__c> shareClassById, Map<String, Id> gridIdByName, BuildResult result) {
        GridRule__c line = assignment.context.gridRule;
        Share_Class__c share = shareClassById.get(assignment.shareClassId);
        if (share == null) {
            setAssignmentError(assignment, result, 'Share_Class__c not found for assignment.');
            return null;
        }

        if (line.RuleToApply__c == RULE_PERCENTAGE) {
            return computePercentageRebate(assignment, share, line, result);
        }

        if (line.RuleToApply__c == RULE_OTHER_SHARE || line.RuleToApply__c == RULE_OTHER_SHARE_FEES) {
            return computeOtherShareRebate(assignment, share, line, rebatesByGridShareKey, existingRebates, shareTypeLookupCache, shareClasses, shareClassById, result);
        }

        if (line.RuleToApply__c == RULE_OTHER_GRID) {
            return computeOtherGridRebate(assignment, line, rebatesByGridShareKey, existingRebates, gridIdByName, result);
        }

        setAssignmentError(assignment, result, 'Unsupported RuleToApply__c "' + line.RuleToApply__c + '".');
        return null;
    }

    private static Decimal computePercentageRebate(RuleAssignment assignment, Share_Class__c share, GridRule__c line, BuildResult result) {
        if (share.EffectiveManagementFees__c == null || line.GridRate__c == null) {
            setAssignmentError(assignment, result, 'EffectiveManagementFees__c and GridRate__c are required to compute the rebate.');
            return null;
        }
        return (share.EffectiveManagementFees__c * line.GridRate__c / 100).setScale(5);
    }

    private static Decimal computeOtherShareRebate(RuleAssignment assignment, Share_Class__c share, GridRule__c line, Map<String, Decimal> rebatesByGridShareKey, Map<String, Decimal> existingRebates, Map<String, Map<String, Id>> shareTypeLookupCache, List<Share_Class__c> shareClasses, Map<Id, Share_Class__c> shareClassById, BuildResult result) {
        String otherShareType = line.OtherShareType__c;
        if (String.isBlank(otherShareType)) {
            setAssignmentError(assignment, result, 'OtherShareType__c is required for this rule.');
            return null;
        }

        Id otherShareId = findOtherShareTypeShareClass(assignment, otherShareType, shareTypeLookupCache, shareClasses, shareClassById);
        if (otherShareId == null) {
            setAssignmentError(assignment, result, 'No matching Share_Class__c found for OtherShareType__c "' + otherShareType + '".');
            return null;
        }

        String otherKey = buildGridShareKey(assignment.gridId, otherShareId);
        Decimal baseRebate = resolveRebate(otherKey, rebatesByGridShareKey, existingRebates);
        if (baseRebate == null) {
            return null;
        }

        if (line.RuleToApply__c == RULE_OTHER_SHARE) {
            return baseRebate;
        }

        Share_Class__c otherShare = shareClassById.get(otherShareId);
        if (otherShare == null || otherShare.EffectiveManagementFees__c == null || share.EffectiveManagementFees__c == null) {
            setAssignmentError(assignment, result, 'EffectiveManagementFees__c is required for both share types to compute the rebate.');
            return null;
        }
        if (line.GridRate__c == null) {
            setAssignmentError(assignment, result, 'GridRate__c is required for Other Share Type + Fees.');
            return null;
        }
        Decimal deltaFees = share.EffectiveManagementFees__c - otherShare.EffectiveManagementFees__c;
        return (baseRebate + (deltaFees * line.GridRate__c / 100)).setScale(5);
    }

    private static Decimal computeOtherGridRebate(RuleAssignment assignment, GridRule__c line, Map<String, Decimal> rebatesByGridShareKey, Map<String, Decimal> existingRebates, Map<String, Id> gridIdByName, BuildResult result) {
        if (String.isBlank(line.OtherGridRule__c)) {
            setAssignmentError(assignment, result, 'OtherGridRule__c is required for Other Grid Rule.');
            return null;
        }
        Id otherGridId = gridIdByName.get(line.OtherGridRule__c);
        if (otherGridId == null) {
            setAssignmentError(assignment, result, 'Grid__c not found for OtherGridRule__c "' + line.OtherGridRule__c + '".');
            return null;
        }
        String otherKey = buildGridShareKey(otherGridId, assignment.shareClassId);
        return resolveRebate(otherKey, rebatesByGridShareKey, existingRebates);
    }

    private static Decimal resolveRebate(String gridShareKey, Map<String, Decimal> rebatesByGridShareKey, Map<String, Decimal> existingRebates) {
        Decimal rebate = rebatesByGridShareKey.get(gridShareKey);
        if (rebate == null) {
            rebate = existingRebates.get(gridShareKey);
        }
        return rebate;
    }

    private static void setAssignmentError(RuleAssignment assignment, BuildResult result, String message) {
        assignment.hasError = true;
        result.errors.add(new BuildError(assignment.gridRuleId, message));
    }

    private static Id findOtherShareTypeShareClass(RuleAssignment assignment, String desiredShareType, Map<String, Map<String, Id>> lookupCache, List<Share_Class__c> shareClasses, Map<Id, Share_Class__c> shareClassById) {
        Set<String> matchFieldSet = new Set<String>(assignment.context.resolvedFieldPaths);
        matchFieldSet.remove(TYPE_FIELD_PATH);
        List<String> matchFields = new List<String>(matchFieldSet);
        matchFields.sort();
        String fieldSetKey = String.join(matchFields, '|');

        Map<String, Id> lookup = getLookupFromCache(fieldSetKey, lookupCache, shareClasses, matchFields);

        Share_Class__c currentShare = shareClassById.get(assignment.shareClassId);
        if (currentShare == null) {
            return null;
        }
        String currentKeyBase = buildKeyBase(currentShare, matchFields);
        if (currentKeyBase == null) {
            return null;
        }
        String desiredKey = currentKeyBase + '|TYPE=' + desiredShareType;
        return lookup.get(desiredKey);
    }

    private static Map<String, Id> getLookupFromCache(String fieldSetKey, Map<String, Map<String, Id>> lookupCache, List<Share_Class__c> shareClasses, List<String> matchFields) {
        Map<String, Id> lookup = lookupCache.get(fieldSetKey);
        if (lookup == null) {
            lookup = new Map<String, Id>();
            for (Share_Class__c share : shareClasses) {
                String keyBase = buildKeyBase(share, matchFields);
                if (keyBase == null) {
                    continue;
                }
                String fullKey = keyBase + '|TYPE=' + share.Type__c;
                if (!lookup.containsKey(fullKey)) {
                    lookup.put(fullKey, share.Id);
                }
            }
            lookupCache.put(fieldSetKey, lookup);
        }
        return lookup;
    }

    private static Map<String, Decimal> loadExistingRebates(List<RuleAssignment> assignments, Map<String, Id> gridIdByName, Set<String> targetGridShareKeys) {
        Map<String, Decimal> existing = new Map<String, Decimal>();
        if (assignments.isEmpty()) {
            return existing;
        }

        LoadExistingContext ctx = buildLoadExistingContext(assignments, targetGridShareKeys, gridIdByName);
        if (ctx.shareClassIds.isEmpty() || ctx.externalGridIds.isEmpty()) {
            return existing;
        }
        return queryExistingRebates(ctx.externalGridIds, ctx.shareClassIds, existing);
    }

    private static LoadExistingContext buildLoadExistingContext(List<RuleAssignment> assignments, Set<String> targetGridShareKeys, Map<String, Id> gridIdByName) {
        LoadExistingContext ctx = new LoadExistingContext();
        ctx.targetGridIds = parseTargetGridIds(targetGridShareKeys);
        collectOtherGridNamesAndShares(assignments, ctx);
        ctx.externalGridIds = resolveExternalGridIds(ctx.otherGridNames, ctx.targetGridIds, gridIdByName);
        return ctx;
    }

    private static Set<Id> parseTargetGridIds(Set<String> targetGridShareKeys) {
        Set<Id> targetGridIds = new Set<Id>();
        for (String key : targetGridShareKeys) {
            List<String> parts = key.split(':');
            if (parts.size() == 2) {
                targetGridIds.add((Id)parts[0]);
            }
        }
        return targetGridIds;
    }

    private static void collectOtherGridNamesAndShares(List<RuleAssignment> assignments, LoadExistingContext ctx) {
        for (RuleAssignment assignment : assignments) {
            GridRule__c line = assignment.context.gridRule;
            if (line.RuleToApply__c == RULE_OTHER_GRID && String.isNotBlank(line.OtherGridRule__c)) {
                ctx.otherGridNames.add(line.OtherGridRule__c);
                ctx.shareClassIds.add(assignment.shareClassId);
            }
        }
    }

    private static Set<Id> resolveExternalGridIds(Set<String> otherGridNames, Set<Id> targetGridIds, Map<String, Id> gridIdByName) {
        Set<Id> externalGridIds = new Set<Id>();
        if (otherGridNames.isEmpty()) {
            return externalGridIds;
        }
        for (String gridName : otherGridNames) {
            Id gridId = gridIdByName.get(gridName);
            if (gridId != null && !targetGridIds.contains(gridId)) {
                externalGridIds.add(gridId);
            }
        }
        return externalGridIds;
    }

    private static Map<String, Decimal> queryExistingRebates(Set<Id> externalGridIds, Set<Id> shareClassIds, Map<String, Decimal> existing) {
        for (GridDetail__c detail : [SELECT Grid__c, ShareClass__c, RebateRate__c
                                     FROM GridDetail__c
                                     WHERE Grid__c IN :externalGridIds AND ShareClass__c IN :shareClassIds]) {
            if (detail.RebateRate__c != null) {
                existing.put(buildGridShareKey(detail.Grid__c, detail.ShareClass__c), detail.RebateRate__c);
            }
        }
        return existing;
    }

    private static Map<String, Map<String, Set<Id>>> buildShareClassIndex(List<Share_Class__c> shareClasses) {
        Map<String, Map<String, Set<Id>>> indexByField = new Map<String, Map<String, Set<Id>>>();
        List<String> fieldPaths = new List<String>{'Fund__r.Legal_Status__c', 'Fund__r.InternalShortName__c', 'Type__c', 'ISIN__c'};

        for (String fieldPath : fieldPaths) {
            indexByField.put(fieldPath, new Map<String, Set<Id>>());
        }

        for (Share_Class__c share : shareClasses) {
            for (String fieldPath : fieldPaths) {
                String value = getShareFieldValue(share, fieldPath);
                if (String.isBlank(value)) {
                    continue;
                }
                Map<String, Set<Id>> valueMap = indexByField.get(fieldPath);
                if (!valueMap.containsKey(value)) {
                    valueMap.put(value, new Set<Id>());
                }
                valueMap.get(value).add(share.Id);
            }
        }

        return indexByField;
    }

    private static String resolveFieldPath(String objectApiName, String fieldApiName) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName) || !SUPPORTED_OBJECTS.contains(objectApiName)) {
            return null;
        }
        return GridBuilderHelper.getRelationshipPath(objectApiName) + fieldApiName;
    }

    private static String buildKeyBase(Share_Class__c share, List<String> matchFields) {
        if (share == null) {
            return null;
        }
        List<String> parts = new List<String>();
        for (String fieldPath : matchFields) {
            String value = getShareFieldValue(share, fieldPath);
            parts.add(fieldPath + '=' + (value == null ? '' : value));
        }
        return String.join(parts, '|');
    }

    private static String getShareFieldValue(Share_Class__c share, String fieldPath) {
        if (share == null || String.isBlank(fieldPath)) {
            return null;
        }
        Object rawValue = GridBuilderHelper.getFieldValue(share, fieldPath.split('\\.'), 0);
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    private static String buildGridShareKey(Id gridId, Id shareClassId) {
        return String.valueOf(gridId) + ':' + String.valueOf(shareClassId);
    }

    private static void ensureGridIds(Set<String> gridNames, Map<String, Id> gridIdByName) {
        Set<String> missingNames = new Set<String>();
        for (String gridName : gridNames) {
            if (String.isNotBlank(gridName) && !gridIdByName.containsKey(gridName)) {
                missingNames.add(gridName);
            }
        }
        if (missingNames.isEmpty()) {
            return;
        }
        for (Grid__c grid : [SELECT Id, Name FROM Grid__c WHERE Name IN :missingNames]) {
            gridIdByName.put(grid.Name, grid.Id);
        }
    }

    private static List<String> splitValues(String raw) {
        List<String> values = new List<String>();
        if (String.isBlank(raw)) {
            return values;
        }
        for (String part : raw.split('\\s*;\\s*')) {
            String cleaned = part != null ? part.trim() : null;
            if (String.isNotBlank(cleaned)) {
                values.add(cleaned);
            }
        }
        return values;
    }

    private static List<String> tokenizeExpression(String expression, BuildResult result, Id gridRuleId) {
        List<String> tokens = new List<String>();
        if (String.isBlank(expression)) {
            result.errors.add(new BuildError(gridRuleId, 'FilterLogicExpression__c is blank.'));
            return tokens;
        }

        Integer i = 0;
        while (i < expression.length()) {
            String ch = expression.substring(i, i + 1);
            if (isWhitespace(ch)) {
                i++;
                continue;
            }
            if (ch == '(' || ch == ')') {
                tokens.add(ch);
                i++;
                continue;
            }
            Integer endInt = readTokenEnd(expression, i, ch);
            if (endInt > i) {
                String token = expression.substring(i, endInt);
                tokens.add(isLetterToken(ch) ? token.toUpperCase() : token);
                i = endInt;
                continue;
            }
            result.errors.add(new BuildError(gridRuleId, 'Unsupported character "' + ch + '" in FilterLogicExpression__c.'));
            return new List<String>();
        }

        return tokens;
    }

    private static Boolean isWhitespace(String ch) {
        return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
    }

    private static Integer readTokenEnd(String expression, Integer start, String firstChar) {
        if (isDigitToken(firstChar)) {
            return scanWhileMatch(expression, start, '\\d');
        }
        if (isLetterToken(firstChar)) {
            return scanWhileMatch(expression, start, '[A-Za-z]');
        }
        return start;
    }

    private static Integer scanWhileMatch(String expression, Integer start, String regex) {
        Integer i = start;
        while (i < expression.length() && Pattern.matches(regex, expression.substring(i, i + 1))) {
            i++;
        }
        return i;
    }

    private static Boolean isDigitToken(String ch) {
        return Pattern.matches('\\d', ch);
    }

    private static Boolean isLetterToken(String ch) {
        return Pattern.matches('[A-Za-z]', ch);
    }

    private static Boolean isNumberToken(String token) {
        return String.isNotBlank(token) && Pattern.matches('\\d+', token);
    }

    private static Set<Id> unionSets(Set<Id> left, Set<Id> right) {
        Set<Id> result = new Set<Id>();
        if (left != null) {
            result.addAll(left);
        }
        if (right != null) {
            result.addAll(right);
        }
        return result;
    }

    private static Set<Id> intersectSets(Set<Id> left, Set<Id> right) {
        if (left == null || right == null) {
            return new Set<Id>();
        }
        Set<Id> result = new Set<Id>(left);
        result.retainAll(right);
        return result;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class BuildResult {
        @AuraEnabled public Integer gridDetailsCreated = 0;
        @AuraEnabled public List<BuildError> errors;
    }

    public class BuildError {
        @AuraEnabled public Id gridRuleId;
        @AuraEnabled public String message;
        public BuildError(Id gridRuleId, String message) {
            this.gridRuleId = gridRuleId;
            this.message = message;
        }
    }

    private class GridRuleContext {
        public GridRule__c gridRule;
        public Id gridId;
        public String filterLogicExpression;
        public List<GridCriteriaDetail__c> details = new List<GridCriteriaDetail__c>();
        public Set<String> resolvedFieldPaths = new Set<String>();
        public Boolean hasErrors = false;

        public GridRuleContext(GridRule__c gridRule) {
            this.gridRule = gridRule;
        }
    }

    private class RuleAssignment {
        public GridRuleContext context;
        public Id shareClassId;
        public Id gridId;
        public Id gridRuleId;
        public Id criteriaId;
        public String gridShareKey;
        public Decimal rebate;
        public Boolean hasError = false;

        public RuleAssignment(GridRuleContext context, Id shareClassId) {
            this.context = context;
            this.shareClassId = shareClassId;
            this.gridId = context.gridId;
            this.gridRuleId = context.gridRule.Id;
            this.criteriaId = context.gridRule.GridCriteria__c;
            this.gridShareKey = buildGridShareKey(context.gridId, shareClassId);
        }
    }

    private class LoadExistingContext {
        public Set<String> otherGridNames = new Set<String>();
        public Set<Id> shareClassIds = new Set<Id>();
        public Set<Id> targetGridIds = new Set<Id>();
        public Set<Id> externalGridIds = new Set<Id>();
    }

    private class ShareClassData {
        public List<Share_Class__c> shareClasses = new List<Share_Class__c>();
        public Map<Id, Share_Class__c> shareClassById = new Map<Id, Share_Class__c>();
        public Set<Id> allShareClassIds = new Set<Id>();
        public Map<String, Map<String, Set<Id>>> indexByField = new Map<String, Map<String, Set<Id>>>();
    }

    private class AssignmentBuildResult {
        public Map<String, RuleAssignment> assignmentByGridShareKey = new Map<String, RuleAssignment>();
        public List<RuleAssignment> assignments = new List<RuleAssignment>();
    }
}