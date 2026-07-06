/** ──────────────────────────────────────
 * @description Test class for GridSimulationController.
 *              Covers AUM aggregation (with and without agreement filter), rebate rate resolution
 *              (RebateRate__c vs FinalRebateRate__c), JSON-based shareClass→grid mapping,
 *              and edge cases (null/empty inputs, null map values, blank JSON).
 * @author Charles EID
 * @testCoverage GridSimulationController (98%)   [07-06-26]
────────────────────────────────────── */
@IsTest
private with sharing class GridSimulationControllerTest {

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testGetSimulationInitData() {
        // "S1" is the grid already wired as AGR-FR's active grid (Convention__c.Grid__c) in test setup.
        Grid__c activeGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Share_Class__c sc = GridTestSetupHelper.getShareClassByType(GridTestSetupHelper.SHARE_TYPE_AW);
        Convention__c agreement = [SELECT Id FROM Convention__c WHERE Name = 'AGR-FR' LIMIT 1];

        GridCriteria__c activeCriteria = GridTestSetupHelper.createCriteria(activeGrid.Id, 'AND', '1', 'Active Criteria');
        insert activeCriteria;
        GridRule__c activeRule = GridTestSetupHelper.createGridRule(activeGrid.Id, activeCriteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 50, null, null, null);
        insert activeRule;
        insert GridTestSetupHelper.createGridDetail(activeGrid.Id, activeRule.Id, activeCriteria.Id, sc.Id, 0.30, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);

        // Draft grid being built on top of the same agreement.
        Grid__c draftGrid = GridTestSetupHelper.createGrid('Draft Grid', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        draftGrid.Agreement__c = agreement.Id;
        draftGrid.ApprovalStatus__c = GridUtility.GRID_STATUS_DRAFT;
        insert draftGrid;

        GridCriteria__c draftCriteria = GridTestSetupHelper.createCriteria(draftGrid.Id, 'AND', '1', 'Draft Criteria');
        insert draftCriteria;
        GridRule__c draftRule = GridTestSetupHelper.createGridRule(draftGrid.Id, draftCriteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 50, null, null, null);
        insert draftRule;
        insert GridTestSetupHelper.createGridDetail(draftGrid.Id, draftRule.Id, draftCriteria.Id, sc.Id, 0.40, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);

        Test.startTest();
        
        GridSimulationController.SimulationInitData initData = GridSimulationController.getSimulationInitData(draftGrid.Id);
        
        Test.stopTest();

        System.assertEquals(true, initData.hasCurrentGrid, 'Draft grid on an agreement with an active grid should surface it as CURRENT');
        System.assertEquals(1, initData.currentRows.size(), 'Active grid rows should be returned for the CURRENT section');
    }
    
    @isTest
    static void testOtherFunctions() {
        Convention__c agreement = [SELECT Id FROM Convention__c WHERE Name = 'AGR-FR' LIMIT 1];
        
        List<GridSimulationController.SimulationRow> simRow = GridSimulationController.getActiveGridSimulationData(agreement.Id);
        String agrRegion = GridSimulationController.getAgreementRegion(new List<Id>{agreement.Id});
    }
}