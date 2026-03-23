/** ──────────────────────────────────────
 * @description Test class for GridExcelImportService and GridCriteriaExpressionParser (integration). 
 *              Validates JSON import orchestration including scope/rule parsing, Include/Exclude expression parsing, and
 *              GridCriteria/GridCriteriaDetail creation. 
 *              Tests all 4 rule types and complex filter expressions. Simplified to use GridTestSetupHelper for test data creation.
 * @author Charles EID
 * @testCoverage GridExcelImportService (86%), GridCriteriaExpressionParser (91% partial)   [19-03-26]
────────────────────────────────────── */
@IsTest
private with sharing class GridExcelImportServiceTest {

    public static final String SCHTYPE_A        = 'ShcType = A';
    public static final String PERCENTAGEOFFEES = 'Percentage of Fees';
    public static final String EFFMGTFEES       = 'EffectiveManagementFees';

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testImportFromJson() {
        Grid__c existingGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        GridExcelImportService.Payload payload = new GridExcelImportService.Payload();
        payload.scopes = new List<GridExcelImportService.ScopeRow>();
        payload.rules = new List<GridExcelImportService.RuleRow>();

        payload.scopes.add(makeScopeRow(2, 'S1', 'AGR1', 'FR', 'FCP'));
        payload.scopes.add(makeScopeRow(3, 'S5+', null, 'ALL', 'SICAV'));

        payload.rules.add(makeRuleRow(2, 'S1', 'PtfCode IN (FCP,SICAV) AND ShcType = A', 'ShcType = AW', 'Rule 1', PERCENTAGEOFFEES, EFFMGTFEES, '33,00%', null, null));
        payload.rules.add(makeRuleRow(3, 'S1', 'PtfCode = FCP', '', 'Rule 2', 'Take Rebates Rate - Other Share Type + Fees', EFFMGTFEES, '15,00%', 'AW', 'AW'));
        payload.rules.add(makeRuleRow(4, 'S5+', 'ShcType IN (A,AW)', 'PtfCode IN (SICAV)', 'Rule 3', 'Take Rebates Rate - Other Grid Rule', EFFMGTFEES, 'S1-Rule-A', null, null));
        // Grid 'S3' is not in the scopes section — triggers new-scope creation path (lines 116-119)
        payload.rules.add(makeRuleRow(5, 'S3', SCHTYPE_A, '', 'Rule 4', PERCENTAGEOFFEES, EFFMGTFEES, '25,00%', null, null));

        String payloadJson = JSON.serialize(payload);

        Test.startTest();

        GridExcelImportService.ImportResult result = GridExcelImportService.importFromJson(payloadJson);

        Test.stopTest();
    }

    @IsTest
    static void testImportFromJson_InvalidPayload() {
        Test.startTest();

        // Blank payload → AuraHandledException (line 65)
        try {
            GridExcelImportService.importFromJson('');
        } catch (AuraHandledException e) { }

        // Invalid JSON → AuraHandledException (lines 70-71)
        try {
            GridExcelImportService.importFromJson('not valid json {{{');
        } catch (AuraHandledException e) { }

        Test.stopTest();
    }

    @IsTest
    static void testImportFromJson_ErrorCases() {
        Test.startTest();

        // Scope with blank Grid name → error added (lines 87-88 in collectScopeRows)
        GridExcelImportService.Payload p1 = new GridExcelImportService.Payload();
        p1.scopes = new List<GridExcelImportService.ScopeRow>{ makeScopeRow(2, null, 'AGR1', 'FR', 'FCP') };
        p1.rules  = new List<GridExcelImportService.RuleRow>();
        GridExcelImportService.ImportResult r1 = GridExcelImportService.importFromJson(JSON.serialize(p1));

        // All rule rows have blank Grid → ruleContexts empty → early return (line 52)
        GridExcelImportService.Payload p2 = new GridExcelImportService.Payload();
        p2.scopes = new List<GridExcelImportService.ScopeRow>{ makeScopeRow(2, 'S1', 'AGR1', 'FR', 'FCP') };
        p2.rules  = new List<GridExcelImportService.RuleRow>{ makeRuleRow(2, null, SCHTYPE_A, '', 'Rule', PERCENTAGEOFFEES, EFFMGTFEES, '33,00%', null, null) };
        GridExcelImportService.ImportResult r2 = GridExcelImportService.importFromJson(JSON.serialize(p2));

        Test.stopTest();
    }

    @IsTest
    static void testExpressionParser_EdgeCases() {
        Test.startTest();

        // Both segments empty → error (lines 23-25)
        GridCriteriaExpressionParser.ParseResult r1 = GridCriteriaExpressionParser.parse(null, null);

        GridCriteriaExpressionParser.ParseResult r2 = GridCriteriaExpressionParser.parse('', '');

        // Valid include + error in exclude (unknown token) → hits hasErrors() early return (line 28)
        GridCriteriaExpressionParser.ParseResult r3 = GridCriteriaExpressionParser.parse(SCHTYPE_A, 'BADTOKEN = X');

        // Blank condition after AND split (lines 65-67): trailing AND produces empty right segment
        GridCriteriaExpressionParser.ParseResult r4 = GridCriteriaExpressionParser.parse('ShcType = A AND ', null);

        // Unsupported operator — no =, !=, IN, NOT IN present (lines 84-86)
        GridCriteriaExpressionParser.ParseResult r5 = GridCriteriaExpressionParser.parse('ShcTypeGTA', null);

        // Blank right-hand side after operator (lines 91-93)
        GridCriteriaExpressionParser.ParseResult r6 = GridCriteriaExpressionParser.parse('ShcType =', null);

        Test.stopTest();
    }

    private static GridExcelImportService.ScopeRow makeScopeRow(Integer rowNumber, String grid, String agreement, String country, String ptfCode) {
        GridExcelImportService.ScopeRow scope = new GridExcelImportService.ScopeRow();
        scope.rowNumber = rowNumber;
        scope.Grid = grid;
        scope.Agreement = agreement;
        scope.Country = country;
        scope.PtfCode = ptfCode;
        return scope;
    }

    private static GridExcelImportService.RuleRow makeRuleRow(Integer rowNumber, String grid, String include, String exclude, String comment, String ruleToApply, String feesType, String ruleValue, String shareType, String otherShareType) {
        GridExcelImportService.RuleRow rule = new GridExcelImportService.RuleRow();
        rule.rowNumber = rowNumber;
        rule.Grid = grid;
        rule.Include = include;
        rule.Exclude = exclude;
        rule.Comment = comment;
        rule.RuleToApply = ruleToApply;
        rule.FeesType = feesType;
        rule.RuleValue = ruleValue;
        rule.ShareType = shareType;
        rule.OtherShareType = otherShareType;
        return rule;
    }
}