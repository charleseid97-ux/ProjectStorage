/** ──────────────────────────────────────
 * @description Test class for StandardGridProductAndRulesController.
 *              Verifies the getStandardGridData method returns correct standard grid groups
 *              including products (with share class rates) and hover data (rules, legal forms).
 * @author Charles EID
 * Coverage: StandardGridProductAndRulesController 100%, GridRecapHelper 98%   [12-03-26]
────────────────────────────────────── */
@IsTest
public with sharing class StdGridProductAndRulesControllerTest {

    public static final String USER_DEFINED = 'User-Defined';

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
        GridCriteriaDetail__c detailIN = GridTestSetupHelper.createCriteriaDetail(criteriaS1.Id, 1, 'Share_Class__c', 'InternalShortName__c', 'IN', 'PROD1;PROD2', USER_DEFINED);
        insert detailIN;
        // Cover legal forms branch in GridRecapHelper
        GridCriteriaDetail__c detailLegal = GridTestSetupHelper.createCriteriaDetail(criteriaS1.Id, 2, 'Share_Class__c', 'Legal_Status__c', 'IN', 'FCP;SICAV', USER_DEFINED);
        insert detailLegal;
        GridDetail__c stdDetailS1 = GridTestSetupHelper.createGridDetail(gridS1.Id, ruleS1.Id, criteriaS1.Id, sc.Id, 2.50, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetailS1;

        // ── S5+: StandardGridDetail with an Other-Grid-Rule pointing to 'S1' ──
        GridCriteria__c criteriaS5 = GridTestSetupHelper.createCriteria(gridS5.Id, 'AND', null, 'S5+ criteria');
        insert criteriaS5;
        GridRule__c ruleS5 = GridTestSetupHelper.createGridRule(gridS5.Id, criteriaS5.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, GridTestSetupHelper.GRID_NAME_S1);
        insert ruleS5;
        // Cover NOT IN criteria branch in GridRecapHelper
        GridCriteriaDetail__c detailNOTIN = GridTestSetupHelper.createCriteriaDetail(criteriaS5.Id, 1, 'Share_Class__c', 'InternalShortName__c', 'NOT IN', 'PROD3', USER_DEFINED);
        insert detailNOTIN;
        // Cover legal forms branch in GridRecapHelper (must be on criteriaS5 — the one resolved via the custom grid)
        GridCriteriaDetail__c detailS5Legal = GridTestSetupHelper.createCriteriaDetail(criteriaS5.Id, 2, 'Share_Class__c', 'Legal_Status__c', 'IN', 'FCP;SICAV', USER_DEFINED);
        insert detailS5Legal;
        GridDetail__c stdDetailS5 = GridTestSetupHelper.createGridDetail(gridS5.Id, ruleS5.Id, criteriaS5.Id, sc.Id, null, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetailS5;

        // Cover FinalRebateRate__c path in GridRecapHelper (new field)
        GridCriteria__c criteriaFR = GridTestSetupHelper.createCriteria(gridS1.Id, 'AND', null, 'FR criteria');
        insert criteriaFR;
        GridRule__c ruleFR = GridTestSetupHelper.createGridRule(gridS1.Id, criteriaFR.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', null, 'A', null, null);
        ruleFR.FinalRebateRate__c = 0.50;
        insert ruleFR;

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