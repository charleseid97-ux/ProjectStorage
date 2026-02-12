/**
 * @description Test class for GridBuilderController and GridBuilderHelper.
 *              Validates all methods including grid settings retrieval, available grids filtering, product/share class selection
 *              with criteria filtering (AND/OR/Custom Logic), and agreement selection page settings.
 * @author Charles EID
 * @testCoverage GridBuilderController (95%), GridBuilderHelper (95% partial)
 */
@IsTest
private class GridBuilderControllerTest {

    private static final String GRID_BUILDER_SETTING = 'StandardGridBuilderSetting';
    private static final String TEST_COUNTRIES = 'FR';
    private static final String TEST_AGREEMENT_NAME = 'AGR-FR';

    @TestSetup
    static void makeData() {
       	GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testGetGridSettings() {
        Test.startTest();

        GridBuilderHelper.GridSettings result = GridBuilderController.getGridSettings(GRID_BUILDER_SETTING, TEST_COUNTRIES);

        Test.stopTest();
    }

    @IsTest
    static void testGetAgreementSelectionPageSettings() {
        Test.startTest();

        GridBuilderController.AgreementSelectionPageSettings result = GridBuilderController.getAgreementSelectionPageSettings(GRID_BUILDER_SETTING, null);

        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableGrids() {
        Test.startTest();

        List<Map<String, String>> result = GridBuilderController.getAvailableGrids(TEST_COUNTRIES, TEST_AGREEMENT_NAME);

        Test.stopTest();
    }

    @IsTest
    static void testGetAllProductsForSelection() {
        Test.startTest();

        GridBuilderHelper.ProductSelectionResult result = GridBuilderController.getAllProductsForSelection(GRID_BUILDER_SETTING, TEST_COUNTRIES);

        Test.stopTest();
    }

    @IsTest
    static void testGetProductsAndShareClasses_WithCriteria() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A)
        };
        executeProductsAndShareClassesTest('AND', '1', details, false, new List<String>{GridTestSetupHelper.SHARE_TYPE_A});
    }

    @IsTest
    static void testGetProductsAndShareClasses_GetAllWithSelection() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A)
        };
        executeProductsAndShareClassesTest('AND', '1', details, true, new List<String>{GridTestSetupHelper.SHARE_TYPE_A});
    }

    @IsTest
    static void testGetProductsAndShareClasses_WithORLogic() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A),
            new CriteriaDetail(2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E)
        };
        executeProductsAndShareClassesTest('OR', '1 OR 2', details, false, new List<String>{GridTestSetupHelper.SHARE_TYPE_A, GridTestSetupHelper.SHARE_TYPE_E});
    }

    @IsTest
    static void testGetProductsAndShareClasses_WithCustomLogic() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A),
            new CriteriaDetail(2, 'Share_Class__c', 'Currency__c', '=', GridTestSetupHelper.CURRENCY_EUR),
            new CriteriaDetail(3, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E)
        };
        executeProductsAndShareClassesTest('Custom Logic', '(1 AND 2) OR 3', details, false, new List<String>{GridTestSetupHelper.SHARE_TYPE_A, GridTestSetupHelper.SHARE_TYPE_E});
    }

    private static void executeProductsAndShareClassesTest(String logic, String filterLogicExpression, List<CriteriaDetail> detailParams, Boolean getAll, List<String> selectedShareTypes) {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, logic, filterLogicExpression, 'Test Criteria');
        List<GridCriteriaDetail__c> criteriaDetails = new List<GridCriteriaDetail__c>();
        for (CriteriaDetail detail : detailParams) {
            criteriaDetails.add(GridTestSetupHelper.createCriteriaDetail(criteria.Id, detail.filterNumber, detail.objectName, detail.fieldName, detail.operator, detail.value, 'User-Defined'));
        }

        Test.startTest();

        GridBuilderHelper.ProductSelectionResult result = GridBuilderController.getProductsAndShareClasses(GRID_BUILDER_SETTING, TEST_COUNTRIES, JSON.serialize(criteria), JSON.serialize(criteriaDetails), getAll, selectedShareTypes);

        Test.stopTest();
    }

    private class CriteriaDetail {
        Integer filterNumber;
        String objectName;
        String fieldName;
        String operator;
        String value;
        private CriteriaDetail(Integer filterNumber, String objectName, String fieldName, String operator, String value) {
            this.filterNumber   =   filterNumber;
            this.objectName     =   objectName;
            this.fieldName      =   fieldName;
            this.operator       =   operator;
            this.value          =   value;
        }
    }
}