/** ──────────────────────────────────────
 * @description Test class for StandardGridProductAndRulesController and GridRecapHelper.
 *              Verifies getStandardGridData (standard grid groups with products and hover data from MDT)
 *              and getShareClassComposition (restricted/unrestricted share types and excluded funds).
 *              MDT query returns empty list in test context (no records deployed),
 *              covering the full code path with an empty hoverData.rules list.
 * @coverage    StandardGridProductAndRulesController: 99% | GridRecapHelper: 100%   [17-09-26]
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

    // getShareClassCompositionTest above uses a Custom Grid with no GridDetail__c records at all, so the
    // restricted/unrestricted classification loop, the excluded-funds section, and
    // buildAvailableFundsByShareType's populated-map branch never execute. This test builds a grid with
    // real classified Grid Details to exercise all three.
    @IsTest
    static void getShareClassCompositionTest_WithClassifiedShareClasses() {
        Strategy__c strategy = GridTestSetupHelper.createStrategy('Composition Strategy', GridTestSetupHelper.ASSET_CLASS_EQUITY, 'COMPSTRAT');
        insert strategy;

        Product__c productInGrid   = GridTestSetupHelper.createProduct(strategy.Id, 'Composition Product In Grid', 'COMPPRODIN', GridTestSetupHelper.LEGAL_STATUS_FCP);
        Product__c productExcluded = GridTestSetupHelper.createProduct(strategy.Id, 'Composition Product Excluded', 'COMPPRODOUT', GridTestSetupHelper.LEGAL_STATUS_FCP);
        insert new List<Product__c>{ productInGrid, productExcluded };

        // Type 'A' is in DefaultShareTypeInclusion__c ('A, AW, B, E, F, FW, I, IW') → classified unrestricted
        // when the criteria's SelectedShareTypes__c also includes it.
        Share_Class__c scUnrestricted = GridTestSetupHelper.createShareClass(productInGrid.Id, 'Comp SC Unrestricted', 'LU7777770001', GridTestSetupHelper.SHARE_TYPE_A, 1.0, GridTestSetupHelper.CURRENCY_EUR);
        // Type 'X' is NOT in DefaultShareTypeInclusion__c → classified restricted regardless of criteria.
        Share_Class__c scRestricted = GridTestSetupHelper.createShareClass(productInGrid.Id, 'Comp SC Restricted', 'LU7777770002', 'X', 1.0, GridTestSetupHelper.CURRENCY_EUR);
        // Not attached to the custom grid at all → should surface as an excluded fund.
        Share_Class__c scExcludedFund = GridTestSetupHelper.createShareClass(productExcluded.Id, 'Comp SC Excluded', 'LU7777770003', GridTestSetupHelper.SHARE_TYPE_A, 1.0, GridTestSetupHelper.CURRENCY_EUR);
        insert new List<Share_Class__c>{ scUnrestricted, scRestricted, scExcludedFund };

        // getShareClassComposition's excluded-funds section (buildProductSelectionResult) and
        // buildAvailableFundsByShareType both gate eligibility on getGridDetailShareClassCondition, which
        // requires an open Standard Grid Detail on one of the grids in availableGridIds. GRID_NAME_S5_PLUS
        // has an unconditional 'ALL'/'ALL' GridScope__c, so it's always in availableGridIds regardless of
        // country/agreement — attach the excluded share class there so it clears that eligibility gate.
        Grid__c standardGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S5_PLUS);
        insert GridTestSetupHelper.createGridDetail(standardGrid.Id, null, null, scExcludedFund.Id, 1.0, Date.today().addDays(-365), null, GridBuilderHelper.RT_STANDARD_GRID_DETAIL);

        Grid__c customGrid = GridTestSetupHelper.createGrid('CompositionTestWithData', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        insert customGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Composition Criteria');
        criteria.SelectedShareTypes__c = GridTestSetupHelper.SHARE_TYPE_A;
        insert criteria;

        GridDetail__c detailUnrestricted = GridTestSetupHelper.createCustomGridDetail(customGrid.Id, criteria.Id, scUnrestricted.Id, null, Date.today());
        GridDetail__c detailRestricted   = GridTestSetupHelper.createCustomGridDetail(customGrid.Id, null, scRestricted.Id, null, Date.today());
        insert new List<GridDetail__c>{ detailUnrestricted, detailRestricted };

        Test.startTest();

        StandardGridProductAndRulesController.ShareClassComposition result = StandardGridProductAndRulesController.getShareClassComposition(customGrid.Id);

        Test.stopTest();

        Boolean foundUnrestrictedA = false;
        for (StandardGridProductAndRulesController.ShareTypeGroup g : result.unrestricted) {
            if (g.shareType == GridTestSetupHelper.SHARE_TYPE_A) foundUnrestrictedA = true;
        }
        System.assert(foundUnrestrictedA, 'Type A should be classified as unrestricted since it is in DefaultShareTypeInclusion__c and matches the criteria SelectedShareTypes__c.');

        Boolean foundRestrictedX = false;
        for (StandardGridProductAndRulesController.ShareTypeGroup g : result.restricted) {
            if (g.shareType == 'X') foundRestrictedX = true;
        }
        System.assert(foundRestrictedX, 'Type X should be classified as restricted since it is not in DefaultShareTypeInclusion__c.');

        System.assert(result.excludedFundShortNames.contains('Composition Product Excluded'), 'A product with no Grid Detail on this Custom Grid should be listed as an excluded fund.');
    }
}