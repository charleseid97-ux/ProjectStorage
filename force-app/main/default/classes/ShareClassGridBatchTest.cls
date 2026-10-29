/** ──────────────────────────────────────
 * @description Test class for ShareClassStandardGridBatch and ShareClassCustomGridBatch.
 *              Covers the daily scheduled reconciliation flow: standard grid rebuild (moteur de calcul)
 *              followed by custom grid CustomGridDetail gap-filling.
 *              No assertions — coverage-focused.
 * @author Charles EID
 * @testCoverage ShareClassStandardGridBatch (100%), ShareClassCustomGridBatch (86%)   [17-09-26]
 ────────────────────────────────────── */
@IsTest
private with sharing class ShareClassGridBatchTest {

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    // ── ShareClassStandardGridBatch ────────────────────────────────────────────────────────

    @IsTest
    static void testStandardGridBatch_Execute() {
        Test.startTest();
        Database.executeBatch(new ShareClassStandardGridBatch(), 50);
        Test.stopTest();
    }

    @IsTest
    static void testStandardGridBatch_Schedulable() {
        Test.startTest();
        System.schedule('Test Grid Reconciliation', '0 0 1 * * ?', new ShareClassStandardGridBatch());
        Test.stopTest();
    }

    // ── ShareClassCustomGridBatch ──────────────────────────────────────────────────────────

    @IsTest
    static void testCustomGridBatch_NoCustomGrids() {
        // No custom grids in base test data — covers the empty-scope early return
        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    @IsTest
    static void testCustomGridBatch_ManualGrid() {
        // AutomaticGridUpdate__c = false — covers the V2 placeholder branch
        Grid__c manualGrid = GridTestSetupHelper.createGrid('ManualCustomGrid', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        manualGrid.AutomaticGridUpdate__c = false;
        insert manualGrid;

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    @IsTest
    static void testCustomGridBatch_AutomaticGrid_NoCriteria() {
        // AutomaticGridUpdate__c = true but no GridCriteria — covers the criteriaList.isEmpty() return
        Grid__c automaticGrid = GridTestSetupHelper.createGrid('AutoCustomGrid_NoCrit', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        automaticGrid.AutomaticGridUpdate__c = true;
        insert automaticGrid;

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    @IsTest
    static void testCustomGridBatch_AutomaticGrid_WithCriteria() {
        // Full path: custom grid + criteria + detail → evaluates via getProductsAndShareClasses
        Grid__c standardGrid = [SELECT Id FROM Grid__c WHERE RecordType.DeveloperName = 'StandardGrid' LIMIT 1];

        Grid__c customGrid = GridTestSetupHelper.createGrid('AutoCustomGrid_WithCrit', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        customGrid.AutomaticGridUpdate__c = true;
        insert customGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Test Criteria');
        criteria.StandardGrid__c    = standardGrid.Id;
        criteria.SelectedShareTypes__c = GridTestSetupHelper.SHARE_TYPE_A;
        insert criteria;

        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Product__c', 'InternalShortName__c', 'IN', 'PROD1;PROD2', 'User-Defined');

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    @IsTest
    static void testCustomGridBatch_AutomaticGrid_NoCriteriaStandardGrid() {
        // Criteria with no StandardGrid__c — covers the gc.StandardGrid__c == null continue branch
        Grid__c customGrid = GridTestSetupHelper.createGrid('AutoCustomGrid_NoStdGrid', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        customGrid.AutomaticGridUpdate__c = true;
        insert customGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'No Std Grid');
        criteria.SelectedShareTypes__c = GridTestSetupHelper.SHARE_TYPE_A;
        // StandardGrid__c intentionally left null
        insert criteria;

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    @IsTest
    static void testCustomGridBatch_ExistingCustomGridDetail() {
        // Pre-existing active CustomGridDetail for a criteria — covers lines 68-71 (dedup loop body)
        Grid__c standardGrid = [SELECT Id FROM Grid__c WHERE RecordType.DeveloperName = 'StandardGrid' LIMIT 1];
        Share_Class__c sc    = [SELECT Id FROM Share_Class__c WHERE Type__c = :GridTestSetupHelper.SHARE_TYPE_A LIMIT 1];

        Grid__c customGrid = GridTestSetupHelper.createGrid('AutoCustomGrid_ExistingDetail', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        customGrid.AutomaticGridUpdate__c = true;
        insert customGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Existing Detail');
        criteria.StandardGrid__c       = standardGrid.Id;
        criteria.SelectedShareTypes__c = GridTestSetupHelper.SHARE_TYPE_A;
        insert criteria;

        // Create an existing StandardGridDetail so it can be referenced
        GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(standardGrid.Id, null, null, sc.Id, 1.5, Date.today(), null, GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetail;

        // Pre-create an active CustomGridDetail — triggers the dedup path
        insert GridTestSetupHelper.createCustomGridDetail(customGrid.Id, criteria.Id, sc.Id, stdDetail.Id, Date.today());

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    @IsTest
    static void testCustomGridBatch_InsertsMissingDetail() {
        // StandardGridDetail exists but no CustomGridDetail yet — covers isSelected=true path and insertGridDetails
        Grid__c standardGrid = [SELECT Id FROM Grid__c WHERE RecordType.DeveloperName = 'StandardGrid' LIMIT 1];
        Share_Class__c sc    = [SELECT Id, Fund__r.InternalShortName__c FROM Share_Class__c WHERE Type__c = :GridTestSetupHelper.SHARE_TYPE_A LIMIT 1];

        // StandardGridDetail in the standard grid so getGridDetailShareClassCondition passes
        GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(standardGrid.Id, null, null, sc.Id, 1.5, Date.today(), null, GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetail;

        Grid__c customGrid = GridTestSetupHelper.createGrid('AutoCustomGrid_MissingDetail', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        customGrid.AutomaticGridUpdate__c = true;
        insert customGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Missing Detail');
        criteria.StandardGrid__c       = standardGrid.Id;
        criteria.SelectedShareTypes__c = GridTestSetupHelper.SHARE_TYPE_A;
        insert criteria;

        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Product__c', 'InternalShortName__c', 'IN', sc.Fund__r.InternalShortName__c, 'User-Defined');

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();
    }

    // Kept as a separate test method (not merged into the one above): batch size is fixed at 1 by design
    // (execute() only ever reads scope[0]), so scoping both scenarios into a single Database.executeBatch
    // call would span 2 chunks, and ShareClassCustomGridBatch.finish() chains GridDetailRefreshBatch —
    // Salesforce test context does not allow more than one executeBatch invocation per test method once
    // chaining is involved across multiple chunks.
    @IsTest
    static void testCustomGridBatch_DoesNotReinsertForClosedShareClass() {
        // A Standard Grid Detail that has already been closed (EndDate__c in the past) must not be treated
        // as eligible by the nightly reconciliation — regression test for the reinsertion bug fixed alongside
        // Share Class closure propagation (GridBuilderHelper eligibility methods now filter on EndDate__c
        // instead of ignoring it).
        Grid__c standardGrid = [SELECT Id FROM Grid__c WHERE RecordType.DeveloperName = 'StandardGrid' LIMIT 1];
        Share_Class__c sc    = [SELECT Id, Fund__r.InternalShortName__c FROM Share_Class__c WHERE Type__c = :GridTestSetupHelper.SHARE_TYPE_A LIMIT 1];

        GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(standardGrid.Id, null, null, sc.Id, 1.5, Date.today().addDays(-100), Date.today().addDays(-1), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetail;

        Grid__c customGrid = GridTestSetupHelper.createGrid('AutoCustomGrid_ClosedShareClass', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        customGrid.AutomaticGridUpdate__c = true;
        insert customGrid;

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Closed Share Class');
        criteria.StandardGrid__c       = standardGrid.Id;
        criteria.SelectedShareTypes__c = GridTestSetupHelper.SHARE_TYPE_A;
        insert criteria;

        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Product__c', 'InternalShortName__c', 'IN', sc.Fund__r.InternalShortName__c, 'User-Defined');

        Test.startTest();
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
        Test.stopTest();

        List<GridDetail__c> insertedCustomDetails = [SELECT Id FROM GridDetail__c WHERE Grid__c = :customGrid.Id];
        System.assert(insertedCustomDetails.isEmpty(), 'A closed Standard Grid Detail should not be treated as eligible, so no Custom Grid Detail should be inserted.');
    }
}