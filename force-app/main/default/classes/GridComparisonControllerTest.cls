/** ──────────────────────────────────────
 * @description Test class for GridComparisonController.
 *              Covers grid/agreement search, grid resolution from agreement,
 *              and comparison data retrieval.
 * @author Charles EID
 * @testCoverage GridComparisonController
────────────────────────────────────── */
@IsTest
private with sharing class GridComparisonControllerTest {

    private static final String APPROVED_CUSTOM_GRID_NAME = 'ApprovedCustomGrid';
    private static final String CUSTOM_AGR_NAME           = 'CUSTOM-AGR';

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();

        // setupTestData() inserts a User (setup object); subsequent non-setup DML must run inside System.runAs
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // An approved custom grid (needed for searchGrids/searchAgreements custom-grid paths)
            Grid__c approvedCustomGrid = GridTestSetupHelper.createGrid(APPROVED_CUSTOM_GRID_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            approvedCustomGrid.ApprovalStatus__c = 'Approved';
            insert approvedCustomGrid;

            // Agreement linked to that approved custom grid (needed for searchAgreements)
            Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
            List<Account> accounts = GridTestSetupHelper.getTestAccounts();
            AgreementTriggerHandler.triggerDisabled = true;
            insert GridTestSetupHelper.createAgreement(CUSTOM_AGR_NAME, 'Custom Agreement', 'CUSTOM-AGR-001', accounts[0].Id, approvedCustomGrid.Id, 'FR', agmRtMap);
            AgreementTriggerHandler.triggerDisabled = false;
        }
    }

    @IsTest
    static void testSearchGrids() {
        Grid__c currentGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();

        GridComparisonController.searchGrids('S5', currentGrid.Id);
        GridComparisonController.searchGrids('ApprovedCustom', currentGrid.Id);

        Test.stopTest();
    }

    @IsTest
    static void testSearchAgreements() {
        Test.startTest();

        GridComparisonController.searchAgreements('CUSTOM');

        Test.stopTest();
    }

    @IsTest
    static void testGetGridFromAgreement() {
        Convention__c agr = [SELECT Id FROM Convention__c WHERE Name = :CUSTOM_AGR_NAME LIMIT 1];

        Test.startTest();

        GridComparisonController.getGridFromAgreement(agr.Id);
        GridComparisonController.getGridFromAgreement(null);

        Test.stopTest();
    }

    @IsTest
    static void testGetComparisonData() {
        Grid__c currentGrid  = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c selectedGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S5_PLUS);

        Test.startTest();

        GridComparisonController.getComparisonData(currentGrid.Id, selectedGrid.Id);

        Test.stopTest();
    }
}