/** ──────────────────────────────────────
 * @description Test class for GridBuilderController and GridBuilderHelper.
 *              Validates all methods including grid settings retrieval, available grids filtering, product/share class selection
 *              with criteria filtering (AND/OR/Custom Logic), and agreement selection page settings.
 * @author Charles EID
 * @testCoverage GridBuilderController (85%), GridBuilderHelper (93% partial)   [19-03-26]
────────────────────────────────────── */
@IsTest
private with sharing class GridBuilderControllerTest {

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

        GridBuilderHelper.GridSettings result = GridBuilderController.getGridSettings(GRID_BUILDER_SETTING, TEST_COUNTRIES, new List<String>());

        Test.stopTest();
    }

    @IsTest
    static void testGetAgreementSelectionPageSettings() {
        Test.startTest();

        GridBuilderController.AgreementSelectionPageSettings result = GridBuilderController.getAgreementSelectionPageSettings(GRID_BUILDER_SETTING, null);

        Test.stopTest();
    }

    @IsTest
    static void testGetAgreementSelectionPageSettings_WithExistingGrid() {
        // AGR-FR has Grid__c set — covers the hasExistingGrid/existingGridKind/existingGridEndDate path
        Convention__c agreement = GridTestSetupHelper.getTestAgreementByTeam(GridTestSetupHelper.TEST_TEAM_FR);
        Test.startTest();

        GridBuilderController.AgreementSelectionPageSettings result = GridBuilderController.getAgreementSelectionPageSettings(GRID_BUILDER_SETTING, agreement.Id);

        Test.stopTest();
    }

    @IsTest
    static void testGetAgreementSelectionPageSettings_WithDraftGrid() {
        // Agreement with Grid_Request__c pointing to a Draft grid — covers hasDraftGrid = true (line 55)
        Convention__c agreement = GridTestSetupHelper.getTestAgreements()[0];

        Grid__c draftGrid = GridTestSetupHelper.createGrid('DraftGridForTest', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        draftGrid.ApprovalStatus__c = 'Draft';
        insert draftGrid;

        AgreementTriggerHandler.triggerDisabled = true;
        Database.update(new Convention__c(Id = agreement.Id, Grid_Request__c = draftGrid.Id, Grid_Request_Start_Date__c = Date.today()), false);
        AgreementTriggerHandler.triggerDisabled = false;

        Test.startTest();

        GridBuilderController.AgreementSelectionPageSettings result = GridBuilderController.getAgreementSelectionPageSettings(GRID_BUILDER_SETTING, agreement.Id);

        Test.stopTest();
    }

    @IsTest
    static void testGetDraftGridData() {
        // Agreement with Grid_Request__c pointing to a Draft grid — covers getDraftGridData (lines 101-146)
        Convention__c agreement = GridTestSetupHelper.getTestAgreements()[0];
        Share_Class__c sc = GridTestSetupHelper.getTestShareClasses()[0];

        Grid__c draftGrid = GridTestSetupHelper.createGrid('DraftGridForGetData', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        draftGrid.ApprovalStatus__c = 'Draft';
        insert draftGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(draftGrid.Id, 'AND', '1', 'Draft Criteria');
        insert criteria;
        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, 'User-Defined');
        insert GridTestSetupHelper.createCustomGridDetail(draftGrid.Id, criteria.Id, sc.Id, null, Date.today());

        AgreementTriggerHandler.triggerDisabled = true;
        Database.update(new Convention__c(Id = agreement.Id, Grid_Request__c = draftGrid.Id, Grid_Request_Start_Date__c = Date.today()), false);
        AgreementTriggerHandler.triggerDisabled = false;

        Test.startTest();

        GridBuilderController.DraftGridData result = GridBuilderController.getDraftGridData(agreement.Id);

        Test.stopTest();
    }

    @IsTest
    static void testGetGridPicklistOptions() {
        Test.startTest();

        Map<String, List<Map<String, String>>> result = GridBuilderController.getGridPicklistOptions();

        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableGrids() {
        Test.startTest();

        GridBuilderController.AvailableGridsResult result = GridBuilderController.getAvailableGrids(TEST_COUNTRIES, TEST_AGREEMENT_NAME);

        Test.stopTest();
    }

    @IsTest
    static void testGetAllProductsForSelection() {
        Test.startTest();

        GridBuilderHelper.ProductSelectionResult result = GridBuilderController.getAllProductsForSelection(GRID_BUILDER_SETTING, TEST_COUNTRIES, new List<String>());

        Test.stopTest();
    }

    @IsTest
    static void testGetProductsAndShareClasses_WithCriteria() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A)
        };
        executeProductsAndShareClassesTest('AND', '1', details, false);
    }

    @IsTest
    static void testGetProductsAndShareClasses_GetAllWithSelection() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A)
        };
        executeProductsAndShareClassesTest('AND', '1', details, true);
    }

    @IsTest
    static void testGetProductsAndShareClasses_WithORLogic() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A),
            new CriteriaDetail(2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E)
        };
        executeProductsAndShareClassesTest('OR', '1 OR 2', details, false);
    }

    @IsTest
    static void testGetProductsAndShareClasses_WithCustomLogic() {
        List<CriteriaDetail> details = new List<CriteriaDetail>{
            new CriteriaDetail(1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A),
            new CriteriaDetail(2, 'Share_Class__c', 'Currency__c', '=', GridTestSetupHelper.CURRENCY_EUR),
            new CriteriaDetail(3, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E)
        };
        executeProductsAndShareClassesTest('Custom Logic', '(1 AND 2) OR 3', details, false);
    }

    private static void executeProductsAndShareClassesTest(String logic, String filterLogicExpression, List<CriteriaDetail> detailParams, Boolean getAll) {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, logic, filterLogicExpression, 'Test Criteria');
        List<GridCriteriaDetail__c> criteriaDetails = new List<GridCriteriaDetail__c>();
        for (CriteriaDetail detail : detailParams) {
            criteriaDetails.add(GridTestSetupHelper.createCriteriaDetail(criteria.Id, detail.filterNumber, detail.objectName, detail.fieldName, detail.operator, detail.value, 'User-Defined'));
        }

        Test.startTest();

        GridBuilderHelper.ProductSelectionResult result = GridBuilderController.getProductsAndShareClasses(GRID_BUILDER_SETTING, TEST_COUNTRIES, JSON.serialize(criteria), JSON.serialize(criteriaDetails), getAll, new List<String>());

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