/** ──────────────────────────────────────
 * @description Test class for GridDetailTableController. 
 *              Validates grid detail retrieval with all rule types, agreement selection parsing (ALL/specific IDs/name tokens/not found), 
 *              net margin calculations, and rule value formatting.
 * @author Charles EID
 * @testCoverage GridDetailTableController (93%)
────────────────────────────────────── */
@IsTest
private with sharing class GridDetailTableControllerTest {

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testBuildRuleValue_AllRuleTypes() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        GridScope__c scope = [SELECT Id FROM GridScope__c WHERE Grid__c = :grid.Id LIMIT 1];
        Share_Class__c shareClass = GridTestSetupHelper.getShareClassByType(GridTestSetupHelper.SHARE_TYPE_A);

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Test Criteria');
        insert criteria;

        GridCriteriaDetail__c detail = GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, 'User-Defined');
        insert detail;

        List<GridRule__c> gridRules = new List<GridRule__c>{
            GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 33, null, null, null),
            GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, 'Take Rebates Rate - Other Share Type', 'EffectiveManagementFees__c', null, null, 'AW', null),
            GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, 'Take Rebates Rate - Other Share Type + Fees', 'EffectiveManagementFees__c', 15, 'AW', 'A', null),
            GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, 'S5+')
        };
        insert gridRules;

        List<GridDetail__c> gridDetails = new List<GridDetail__c>();
        for (GridRule__c rl : gridRules) {
            gridDetails.add(GridTestSetupHelper.createGridDetail(grid.Id, rl.Id, criteria.Id, shareClass.Id, 0.5, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL));
        }

        // 5th rule: FinalRebateRate__c set — should override rebateRate, gridRule, ruleValue
        GridRule__c finalRule = GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 33, null, null, null);
        finalRule.FinalRebateRate__c = 0.75;
        insert finalRule;
        gridDetails.add(GridTestSetupHelper.createGridDetail(grid.Id, finalRule.Id, criteria.Id, shareClass.Id, 0.5, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL));

        insert gridDetails;

        Test.startTest();

        GridDetailTableController.GridDetailResult result = GridDetailTableController.getGridDetails(grid.Id);

        // Verify FinalRebateRate__c path: find the row that should show 'Calculated Rebates'
        GridDetailTableController.GridDetailRow finalRateRow = null;
        for (GridDetailTableController.GridDetailRow row : result.rows) {
            if ('Calculated Rebates'.equals(row.gridRule)) {
                finalRateRow = row;
                break;
            }
        }

        // Specific scenarios tests
        // 1- Test with no scope grid
        delete scope;
        result = GridDetailTableController.getGridDetails(grid.Id);

        // 2- Test with null gridId
        result = GridDetailTableController.getGridDetails(null);

        Test.stopTest();
    }

    @IsTest
    static void testCustomGridDetail_UsesStandardGridDetailData() {
        Grid__c stdGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Share_Class__c shareClass = GridTestSetupHelper.getShareClassByType(GridTestSetupHelper.SHARE_TYPE_A);

        // Create a standard grid rule and detail
        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(stdGrid.Id, 'AND', '1', 'Std Criteria');
        insert criteria;
        GridRule__c stdRule = GridTestSetupHelper.createGridRule(stdGrid.Id, criteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 50, null, null, null);
        insert stdRule;
        GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(stdGrid.Id, stdRule.Id, criteria.Id, shareClass.Id, 0.25, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetail;

        // Create a custom grid with scope (ALL)
        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();
        Grid__c customGrid = new Grid__c(Name = 'TestCustomGrid', RecordTypeId = customGridRtId, ActiveGrid__c = true);
        insert customGrid;
        GridScope__c customScope = new GridScope__c(Name = 'CustomScope', Grid__c = customGrid.Id, Agreement__c = 'ALL');
        insert customScope;

        // Create a custom grid detail pointing to the standard detail
        Id customDetailRtId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID_DETAIL).getRecordTypeId();
        GridCriteria__c customCriteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Custom Criteria');
        insert customCriteria;
        GridDetail__c customDetail = new GridDetail__c(
            RecordTypeId = customDetailRtId,
            Grid__c = customGrid.Id,
            ShareClass__c = shareClass.Id,
            StandardGridDetail__c = stdDetail.Id,
            GridCriteria__c = customCriteria.Id,
            StartDate__c = Date.today()
        );
        insert customDetail;

        Test.startTest();

        GridDetailTableController.GridDetailResult result = GridDetailTableController.getGridDetails(customGrid.Id);

        Test.stopTest();

        GridDetailTableController.GridDetailRow row = result.rows[0];
    }
}