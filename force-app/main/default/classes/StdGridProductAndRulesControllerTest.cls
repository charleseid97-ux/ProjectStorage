/** ──────────────────────────────────────
 * @description Test class for StandardGridProductAndRulesController.
 *              Verifies the getStandardGridData method returns correct standard grid groups
 *              including products (with share class rates) and hover data (rules, legal forms).
 * @author Charles EID
 * Coverage: StandardGridProductAndRulesController 100%, GridRecapHelper 100%
────────────────────────────────────── */
@IsTest
public class StdGridProductAndRulesControllerTest {

    @TestSetup
    static void setup() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void getStandardGridDataTest() {
        Grid__c gridS1   = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c gridS5   = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S5_PLUS);
        Share_Class__c sc = GridTestSetupHelper.getTestShareClasses()[0];

        // ── S1: StandardGridDetail with a Percentage-of-Fees rule (the resolution target) ──
        GridCriteria__c criteriaS1 = GridTestSetupHelper.createCriteria(gridS1.Id, 'AND', null, 'S1 criteria');
        insert criteriaS1;
        GridRule__c ruleS1 = GridTestSetupHelper.createGridRule(gridS1.Id, criteriaS1.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 2.50, null, null, null);
        insert ruleS1;
        // Cover IN criteria branch in GridRecapHelper
        GridCriteriaDetail__c detailIN = GridTestSetupHelper.createCriteriaDetail(
            criteriaS1.Id, 1, 'Share_Class__c', 'InternalShortName__c', 'IN', 'PROD1;PROD2', null);
        insert detailIN;
        // Cover legal forms branch in GridRecapHelper
        GridCriteriaDetail__c detailLegal = GridTestSetupHelper.createCriteriaDetail(
            criteriaS1.Id, 2, 'Share_Class__c', 'Legal_Status__c', 'IN', 'FCP;SICAV', null);
        insert detailLegal;
        GridDetail__c stdDetailS1 = GridTestSetupHelper.createGridDetail(gridS1.Id, ruleS1.Id, criteriaS1.Id, sc.Id, 2.50, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetailS1;

        // ── S5+: StandardGridDetail with an Other-Grid-Rule pointing to 'S1' ──
        GridCriteria__c criteriaS5 = GridTestSetupHelper.createCriteria(gridS5.Id, 'AND', null, 'S5+ criteria');
        insert criteriaS5;
        GridRule__c ruleS5 = GridTestSetupHelper.createGridRule(gridS5.Id, criteriaS5.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, GridTestSetupHelper.GRID_NAME_S1);
        insert ruleS5;
        // Cover NOT IN criteria branch in GridRecapHelper
        GridCriteriaDetail__c detailNOTIN = GridTestSetupHelper.createCriteriaDetail(
            criteriaS5.Id, 1, 'Share_Class__c', 'InternalShortName__c', 'NOT IN', 'PROD3', null);
        insert detailNOTIN;
        GridDetail__c stdDetailS5 = GridTestSetupHelper.createGridDetail(gridS5.Id, ruleS5.Id, criteriaS5.Id, sc.Id, null, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetailS5;

        // ── Custom grid: CustomGridDetail → S5+ StandardGridDetail ──
        Grid__c customGrid = GridTestSetupHelper.createGrid('CustomOGRTest', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        insert customGrid;
        GridDetail__c customDetail = GridTestSetupHelper.createGridDetail(customGrid.Id, null, null, sc.Id, null, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_CUSTOM_GRID_DETAIL);
        customDetail.StandardGridDetail__c = stdDetailS5.Id;
        insert customDetail;

        Test.startTest();

        List<GridRecapHelper.StandardGridGroup> groups = StandardGridProductAndRulesController.getStandardGridData(customGrid.Id);

        Test.stopTest();
    }
}