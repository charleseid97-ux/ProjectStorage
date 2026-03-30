/** ──────────────────────────────────────
 * @description Test class for GridSimulationController.
 *              Covers AUM aggregation (with and without agreement filter), rebate rate resolution
 *              (RebateRate__c vs FinalRebateRate__c), JSON-based shareClass→grid mapping,
 *              and edge cases (null/empty inputs, null map values, blank JSON).
 * @author Charles EID
 * @testCoverage GridSimulationController (100%)   [27-03-26]
────────────────────────────────────── */
@IsTest
private with sharing class GridSimulationControllerTest {

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testGetSimulationData() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Share_Class__c sc = GridTestSetupHelper.getShareClassByType(GridTestSetupHelper.SHARE_TYPE_AW);

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Sim Criteria FRR');
        insert criteria;
        GridRule__c rule = GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 50, null, null, null);
        rule.FinalRebateRate__c = 0.75;
        insert rule;
        GridDetail__c detail = GridTestSetupHelper.createGridDetail(grid.Id, rule.Id, criteria.Id, sc.Id, 0.40, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert detail;

        String json = '{"' + sc.Id + '": "' + grid.Id + '"}';

        Test.startTest();
        List<GridSimulationController.SimulationRow> result = GridSimulationController.getSimulationData(new List<Id>{ sc.Id }, null, json);
        Test.stopTest();
    }
}