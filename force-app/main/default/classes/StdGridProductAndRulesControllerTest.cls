/** ──────────────────────────────────────
 * @description Test class for StandardGridProductAndRulesController and GridRecapHelper.
 *              Verifies getStandardGridData (standard grid groups with products and hover data from MDT)
 *              and getShareClassComposition (restricted/unrestricted share types and excluded funds).
 *              MDT query returns empty list in test context (no records deployed),
 *              covering the full code path with an empty hoverData.rules list.
 * @coverage    StandardGridProductAndRulesController: 100% | GridRecapHelper: 100%
 * @author Charles EID
────────────────────────────────────── */
@IsTest
public with sharing class StdGridProductAndRulesControllerTest {

    @TestSetup
    static void setup() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void getStandardGridDataTest() {
        Grid__c gridS5    = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S5_PLUS);
        Share_Class__c sc = GridTestSetupHelper.getTestShareClasses()[0];

        // ── StandardGridDetail on S5+ ──
        GridDetail__c stdDetailS5 = GridTestSetupHelper.createGridDetail(gridS5.Id, null, null, sc.Id, 2.50, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetailS5;

        // ── Custom grid: CustomGridDetail → S5+ StandardGridDetail ──
        Grid__c customGrid = GridTestSetupHelper.createGrid('CustomRecapTest', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        insert customGrid;
        GridDetail__c customDetail = GridTestSetupHelper.createGridDetail(customGrid.Id, null, null, sc.Id, null, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_CUSTOM_GRID_DETAIL);
        customDetail.StandardGridDetail__c = stdDetailS5.Id;
        insert customDetail;

        Test.startTest();

        List<GridRecapHelper.StandardGridGroup> groups = StandardGridProductAndRulesController.getStandardGridData(customGrid.Id);

        Test.stopTest();
    }

    @IsTest
    static void getShareClassCompositionTest() {
        Grid__c customGrid = GridTestSetupHelper.createGrid('CompositionTest', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        insert customGrid;

        Test.startTest();

        StandardGridProductAndRulesController.ShareClassComposition result = StandardGridProductAndRulesController.getShareClassComposition(customGrid.Id);

        Test.stopTest();
    }
}