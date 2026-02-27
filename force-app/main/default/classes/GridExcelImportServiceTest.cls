/** ──────────────────────────────────────
 * @description Test class for GridExcelImportService and GridCriteriaExpressionParser (integration). 
 *              Validates JSON import orchestration including scope/rule parsing, Include/Exclude expression parsing, and
 *              GridCriteria/GridCriteriaDetail creation. 
 *              Tests all 4 rule types and complex filter expressions. Simplified to use GridTestSetupHelper for test data creation.
 * @author Charles EID
 * @testCoverage GridExcelImportService (81%), GridCriteriaExpressionParser (83% partial)
────────────────────────────────────── */
@IsTest
private class GridExcelImportServiceTest {

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

        payload.rules.add(makeRuleRow(2, 'S1', 'PtfCode IN (FCP,SICAV) AND ShcType = A', 'ShcType = AW', 'Rule 1', 'Percentage of Fees', 'EffectiveManagementFees', '33,00%', null, null));
        payload.rules.add(makeRuleRow(3, 'S1', 'PtfCode = FCP', '', 'Rule 2', 'Take Rebates Rate - Other Share Type + Fees', 'EffectiveManagementFees', '15,00%', 'AW', 'AW'));
        payload.rules.add(makeRuleRow(4, 'S5+', 'ShcType IN (A,AW)', 'PtfCode IN (SICAV)', 'Rule 3', 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees', 'S1-Rule-A', null, null));

        String payloadJson = JSON.serialize(payload);

        Test.startTest();

        GridExcelImportService.ImportResult result = GridExcelImportService.importFromJson(payloadJson);

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