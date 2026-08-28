/** ──────────────────────────────────────
 * @description Test class for GridDetailRefreshBatch.
 *              Uses GridTestSetupHelper for base data, then adds a Custom Grid + CustomGridDetail
 *              with IsCurrentGridDetail__c = true to exercise the batch scope.
 * @author Charles EID
 * @testCoverage GridDetailRefreshBatch
 ────────────────────────────────────── */
@IsTest
private class GridDetailRefreshBatchTest {

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();

        // setupTestData() inserts a User (setup object). Subsequent non-setup DML must run inside
        // System.runAs to avoid the MIXED_DML_OPERATION error.
        User u = [SELECT Id FROM User WHERE Alias = 'TestApex' LIMIT 1];
        System.runAs(u) {
            Share_Class__c sc      = GridTestSetupHelper.getTestShareClasses()[0];
            Grid__c        stdGrid = [SELECT Id FROM Grid__c WHERE RecordType.DeveloperName = :GridBuilderHelper.RT_STANDARD_GRID LIMIT 1];
            Convention__c  agr     = GridTestSetupHelper.getTestAgreements()[0];

            // Standard GridDetail — needed as StandardGridDetail__c on the CustomGridDetail
            GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(stdGrid.Id, null, null, sc.Id, 0.5, Date.today(), null, GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
            insert stdDetail;

            // Custom Grid: StartDate__c + ApprovalStatus__c = 'Approved' → IsCurrentGrid__c formula = true
            Grid__c customGrid = GridTestSetupHelper.createGrid('TestCustomGrid', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
            customGrid.Agreement__c      = agr.Id;
            customGrid.StartDate__c      = Date.today();
            customGrid.ApprovalStatus__c = GridUtility.GRID_STATUS_APPROVED;
            insert customGrid;

            GridCriteria__c criteria = GridTestSetupHelper.createCriteria(customGrid.Id, 'AND', '1', 'Test Criteria');
            insert criteria;

            // CustomGridDetail: TECH_EffMgtFeesAuditHistory__c = null by default → IsCurrentGridDetail__c = true
            GridDetail__c customDetail = GridTestSetupHelper.createCustomGridDetail(customGrid.Id, criteria.Id, sc.Id, stdDetail.Id, Date.today());
            insert customDetail;
        }
    }

    @IsTest
    static void testUpdatesFields() {
        Share_Class__c sc  = GridTestSetupHelper.getTestShareClasses()[0];
        Convention__c  agr = GridTestSetupHelper.getTestAgreements()[0];
        Account        acc = [SELECT Id FROM Account LIMIT 1];

        Flow__c flow = new Flow__c(Agreement__c = agr.Id, ShareClass__c = sc.Id, Company__c = acc.Id, AmountEUR__c = 500, ValueDate__c = Date.today(), FlowExternalId__c = 'TEST-FLOW-001');
        insert flow;

        AUM__c aum = GridTestSetupHelper.createAUM(sc.Id, agr.Id, acc.Id, 10000, Date.today());
        aum.Last_AUM__c = true;
        insert aum;

        Test.startTest();

        Database.executeBatch(new GridDetailRefreshBatch(), GridUtility.BATCH_SIZE_GRID_DETAIL_REFRESH);
        
        Test.stopTest();

        GridDetail__c result = [SELECT FlowsYTD__c, TotalAUMEur__c
                                FROM GridDetail__c
                                WHERE Grid__r.RecordType.DeveloperName = :GridBuilderHelper.RT_CUSTOM_GRID
                                LIMIT 1];
        System.assertEquals(500,   result.FlowsYTD__c,    'FlowsYTD__c should match inserted flow amount');
        System.assertEquals(10000, result.TotalAUMEur__c, 'TotalAUMEur__c should match inserted AUM amount');
    }

    @IsTest
    static void testNoMatchingData() {
        // No Flow or AUM with Last_AUM__c = true → both fields should be set to 0
        Test.startTest();

        Database.executeBatch(new GridDetailRefreshBatch(), GridUtility.BATCH_SIZE_GRID_DETAIL_REFRESH);

        Test.stopTest();

        GridDetail__c result = [SELECT FlowsYTD__c, TotalAUMEur__c
                                FROM GridDetail__c
                                WHERE Grid__r.RecordType.DeveloperName = :GridBuilderHelper.RT_CUSTOM_GRID
                                LIMIT 1];
        System.assertEquals(0, result.FlowsYTD__c,    'FlowsYTD__c should be 0 when no matching flows');
        System.assertEquals(0, result.TotalAUMEur__c, 'TotalAUMEur__c should be 0 when no matching AUM');
    }

    @IsTest
    static void testBatchRuns() {
        Test.startTest();

        Database.executeBatch(new GridDetailRefreshBatch(), GridUtility.BATCH_SIZE_GRID_DETAIL_REFRESH);

        Test.stopTest();
    }
}