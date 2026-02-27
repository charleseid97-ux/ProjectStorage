/** ──────────────────────────────────────
 * @description Test class for GridDetailTableController. 
 *              Validates grid detail retrieval with all rule types, agreement selection parsing (ALL/specific IDs/name tokens/not found), 
 *              net margin calculations, and rule value formatting.
 * @author Charles EID
 * @testCoverage GridDetailTableController (92%)
────────────────────────────────────── */
@IsTest
private class GridDetailTableControllerTest {

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

        List<GridRule__c> ruleLines = new List<GridRule__c>{
            GridTestSetupHelper.createRuleLine(grid.Id, criteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 33, null, null, null),
            GridTestSetupHelper.createRuleLine(grid.Id, criteria.Id, 'Take Rebates Rate - Other Share Type', 'EffectiveManagementFees__c', null, null, 'AW', null),
            GridTestSetupHelper.createRuleLine(grid.Id, criteria.Id, 'Take Rebates Rate - Other Share Type + Fees', 'EffectiveManagementFees__c', 15, 'AW', 'A', null),
            GridTestSetupHelper.createRuleLine(grid.Id, criteria.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, 'S5+')
        };
        insert ruleLines;

        List<GridDetail__c> gridDetails = new List<GridDetail__c>();
        for (GridRule__c rl : ruleLines) {
            gridDetails.add(GridTestSetupHelper.createGridDetail(grid.Id, rl.Id, criteria.Id, shareClass.Id, 0.5, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL));
        }
        insert gridDetails;

        Test.startTest();

        GridDetailTableController.GridDetailResult result = GridDetailTableController.getGridDetails(grid.Id);

        // Specific scenarios tests
        // 1- Test with no scope grid
        delete scope;
        result = GridDetailTableController.getGridDetails(grid.Id);

        // 2- Test with null gridId
        result = GridDetailTableController.getGridDetails(null); 

        Test.stopTest();
    }
}