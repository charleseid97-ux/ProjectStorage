/** ──────────────────────────────────────
 * @description Test class for CustomApprovalHistoryController.
 *              Covers null/empty guards for getApprovalHistory and processApproval.
 *              Real ProcessInstance DML is not creatable in unit tests without a full submission;
 *              these tests cover all reachable code paths with available test data.
 * @author Charles EID
 * @coverage CustomApprovalHistoryController
────────────────────────────────────── */
@IsTest
public with sharing class CustomApprovalHistoryControllerTest {

    private static final String SHOULD_FAIL_INVALID_WORKITEM = SHOULD_FAIL_INVALID_WORKITEM;
    private static final String ERROR_MSG_SHOULD_BE_SET = ERROR_MSG_SHOULD_BE_SET;

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getApprovalHistory
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetApprovalHistory_NullId() {
        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.rows.size(), 'Rows should be empty for null recordId');
        System.assertEquals(false, result.canApproveOrReject, 'canApproveOrReject should be false');
        System.assertEquals(false, result.canRecall, 'canRecall should be false');
        System.assertEquals(null, result.processStatus, 'processStatus should be null');
    }

    @IsTest
    static void testGetApprovalHistory_NoProcess() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(grid.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.rows.size(), 'Rows should be empty when no ProcessInstance exists');
        System.assertEquals(false, result.canApproveOrReject, 'canApproveOrReject should be false');
        System.assertEquals(false, result.canRecall, 'canRecall should be false');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // processApproval
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testProcessApproval_InvalidWorkItem_Approve() {
        Id fakeWorkItemId = '04i000000000001AAA';

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(fakeWorkItemId, 'Approve', null, null);
        Test.stopTest();

        System.assertEquals(false, result.success, SHOULD_FAIL_INVALID_WORKITEM);
        System.assertNotEquals(null, result.errorMessage, ERROR_MSG_SHOULD_BE_SET);
    }

    @IsTest
    static void testProcessApproval_InvalidWorkItem_Reject() {
        Id fakeWorkItemId = '04i000000000002AAA';

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(fakeWorkItemId, 'Reject', 'No reason', null);
        Test.stopTest();

        System.assertEquals(false, result.success, SHOULD_FAIL_INVALID_WORKITEM);
        System.assertNotEquals(null, result.errorMessage, ERROR_MSG_SHOULD_BE_SET);
    }

    @IsTest
    static void testProcessApproval_InvalidWorkItem_Recall() {
        Id fakeWorkItemId = '04i000000000003AAA';

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(fakeWorkItemId, 'Removed', null, null);
        Test.stopTest();

        System.assertEquals(false, result.success, SHOULD_FAIL_INVALID_WORKITEM);
        System.assertNotEquals(null, result.errorMessage, ERROR_MSG_SHOULD_BE_SET);
    }

    @IsTest
    static void testProcessApproval_WithNextApprovers() {
        Id fakeWorkItemId = '04i000000000004AAA';
        List<Id> nextApprovers = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(fakeWorkItemId, 'Approve', 'Approved', nextApprovers);
        Test.stopTest();

        System.assertEquals(false, result.success, SHOULD_FAIL_INVALID_WORKITEM);
        System.assertNotEquals(null, result.errorMessage, ERROR_MSG_SHOULD_BE_SET);
    }
}