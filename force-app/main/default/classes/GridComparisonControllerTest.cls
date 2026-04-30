/** ──────────────────────────────────────
 * @description Test class for GridComparisonController.
 *              Covers grid/agreement search, grid resolution from agreement,
 *              and comparison data retrieval.
 * @author Charles EID
 * @testCoverage GridComparisonController
────────────────────────────────────── */
@IsTest
private with sharing class GridComparisonControllerTest {

    private static final String APPROVED_CUSTOM_GRID_NAME  = 'ApprovedCustomGrid';
    private static final String CUSTOM_AGR_NAME            = 'CUSTOM-AGR';
    private static final String SPECIFIC_STD_GRID_NAME     = 'SpecificStdGrid';
    private static final String CURRENT_GRID_WITH_AGR_NAME = 'CurrentGridWithAgreement';
    private static final String SAME_AGR_GRID_NAME         = 'SameAgreementGrid';
    private static final String PRIORITY_AGR_NAME          = 'PRIORITY-AGR';

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();

        // setupTestData() inserts a User (setup object); subsequent non-setup DML must run inside System.runAs
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
            List<Account> accounts   = GridTestSetupHelper.getTestAccounts();

            // An approved custom grid (needed for searchGrids/searchAgreements custom-grid paths)
            Grid__c approvedCustomGrid = GridTestSetupHelper.createGrid(APPROVED_CUSTOM_GRID_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            approvedCustomGrid.ApprovalStatus__c = 'Approved';
            insert approvedCustomGrid;

            // Agreement linked to that approved custom grid (needed for searchAgreements)
            AgreementTriggerHandler.triggerDisabled = true;
            insert GridTestSetupHelper.createAgreement(CUSTOM_AGR_NAME, 'Custom Agreement', 'CUSTOM-AGR-001', accounts[0].Id, approvedCustomGrid.Id, 'FR', agmRtMap);
            AgreementTriggerHandler.triggerDisabled = false;

            // A specific standard grid (Tech_SpecificStandardGrid__c = true) — must be hidden from comparison filter
            Grid__c specificStdGrid = GridTestSetupHelper.createGrid(SPECIFIC_STD_GRID_NAME, '', true, GridBuilderHelper.RT_STANDARD_GRID);
            specificStdGrid.Tech_SpecificStandardGrid__c = true;
            insert specificStdGrid;

            // A custom grid that acts as "current grid" and belongs to an agreement (for group-2 priority test)
            Grid__c currentGridWithAgreement = GridTestSetupHelper.createGrid(CURRENT_GRID_WITH_AGR_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            insert currentGridWithAgreement;

            AgreementTriggerHandler.triggerDisabled = true;
            Convention__c priorityAgreement = GridTestSetupHelper.createAgreement(PRIORITY_AGR_NAME, 'Priority Test Agreement', 'PRIO-AGR-001', accounts[0].Id, currentGridWithAgreement.Id, 'FR', agmRtMap);
            insert priorityAgreement;
            AgreementTriggerHandler.triggerDisabled = false;

            // Link the current grid back to the agreement (Agreement__c on Grid__c)
            currentGridWithAgreement.Agreement__c = priorityAgreement.Id;
            update currentGridWithAgreement;

            // A second grid from the same agreement — must appear in group 2 (before other custom grids)
            Grid__c sameAgreementGrid = GridTestSetupHelper.createGrid(SAME_AGR_GRID_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            sameAgreementGrid.Agreement__c = priorityAgreement.Id;
            insert sameAgreementGrid;
        }
    }

    @IsTest
    static void testSearchGrids() {
        Grid__c currentGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        GridComparisonController.searchGrids('S5', currentGrid.Id);
        List<GridComparisonController.LookupResult> allResults = GridComparisonController.searchGrids('', currentGrid.Id);
        Test.stopTest();

        // Specific standard grids must never appear
        for (GridComparisonController.LookupResult r : allResults) {
            System.assertNotEquals(SPECIFIC_STD_GRID_NAME, r.name, 'Specific standard grid must be hidden from comparison filter');
        }

        // Standard grids (no subtitle) must all precede custom grids (subtitle present)
        Boolean seenCustom = false;
        for (GridComparisonController.LookupResult r : allResults) {
            if (r.subtitle != null) {
                seenCustom = true;
            } else {
                System.assert(!seenCustom, 'Standard grid "' + r.name + '" appeared after a custom grid — ordering is wrong');
            }
        }
    }

    @IsTest
    static void testSearchGrids_sameAgreementPriority() {
        Grid__c currentGrid = [SELECT Id FROM Grid__c WHERE Name = :CURRENT_GRID_WITH_AGR_NAME LIMIT 1];

        Test.startTest();
        List<GridComparisonController.LookupResult> results = GridComparisonController.searchGrids('', currentGrid.Id);
        Test.stopTest();

        Integer sameAgrIdx    = -1;
        Integer otherCustIdx  = -1;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].name == SAME_AGR_GRID_NAME)       sameAgrIdx   = i;
            if (results[i].name == APPROVED_CUSTOM_GRID_NAME) otherCustIdx = i;
        }

        System.assert(sameAgrIdx   > -1, 'Same-agreement grid must appear in results');
        System.assert(otherCustIdx > -1, 'Other custom grid must appear in results');
        System.assert(sameAgrIdx < otherCustIdx, 'Same-agreement grid must appear before other custom grids');

        // Current grid must not appear in results
        for (GridComparisonController.LookupResult r : results) {
            System.assertNotEquals(CURRENT_GRID_WITH_AGR_NAME, r.name, 'Current grid must be excluded from comparison options');
        }
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