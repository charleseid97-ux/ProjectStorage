/** ──────────────────────────────────────
 * @description Test class for CustomApprovalHistoryController.
 *              Covers approval history retrieval, user and queue-based permission
 *              checks, process submission delegation, and approval/recall actions.
 * @author Charles EID
 * @covers CustomApprovalHistoryController
 ────────────────────────────────────── */
@IsTest
public with sharing class CustomApprovalHistoryControllerTest {

    private static final String RESULT_NOT_NULL = 'Result should not be null';
    private static final String STATUS_PENDING  = 'Pending';
    private static final String PROCESS_NAME    = 'GridAmendment';

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    private static CustomApproval__c insertTestApproval(Id gridId, String status) {
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(gridId),
            Status__c               = status,
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = PROCESS_NAME,
            CurrentStepDevName__c   = status == STATUS_PENDING ? 'GridAmendment_HOC' : null
        );
        insert approval;
        return approval;
    }

    private static CustomApprovalStep__c insertPendingStep(Id approvalId) {
        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c     = approvalId,
            StepDeveloperName__c  = 'GridAmendment_HOC',
            StepLabel__c          = 'HOC Approval',
            Status__c             = STATUS_PENDING,
            IsCurrentStep__c      = true,
            AssignedTo__c         = String.valueOf(UserInfo.getUserId()),
            AssignedToName__c     = UserInfo.getName(),
            OriginalAssignedTo__c = String.valueOf(UserInfo.getUserId()),
            OriginalAssignedToName__c = UserInfo.getName()
        );
        insert step;
        return step;
    }

    // ─── getApprovalHistory ──────────────────────────────────────────────────────

    @IsTest
    static void testGetApprovalHistory_NullId() {
        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(null);
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.rows.size(), 'Rows should be empty for null recordId');
        System.assertEquals(false, result.canApproveOrReject, 'canApproveOrReject should be false');
        System.assertEquals(false, result.canRecall, 'canRecall should be false');
        System.assertEquals(null, result.processStatus, 'processStatus should be null');
    }

    @IsTest
    static void testGetApprovalHistory_NoApprovals() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(grid.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.rows.size(), 'Rows should be empty when no CustomApproval__c exists');
        System.assertEquals(false, result.canApproveOrReject, 'canApproveOrReject should be false');
        System.assertEquals(false, result.canRecall, 'canRecall should be false');
    }

    @IsTest
    static void testGetApprovalHistory_WithPendingStep() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = insertTestApproval(grid.Id, STATUS_PENDING);
        insertPendingStep(approval.Id);

        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(grid.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(1, result.rows.size(), 'Should have one row');
        System.assertEquals(STATUS_PENDING, result.processStatus, 'Process status should be Pending');
        System.assertEquals(true, result.canApproveOrReject, 'Current user should be able to approve (assigned to self)');
        System.assertEquals(true, result.canRecall, 'Submitter should be able to recall');
    }

    @IsTest
    static void testGetApprovalHistory_ApprovedProcess() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = insertTestApproval(grid.Id, 'Approved');
        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c      = approval.Id,
            StepDeveloperName__c   = 'GridAmendment_HOC',
            StepLabel__c           = 'HOC Approval',
            Status__c              = 'Approved',
            IsCurrentStep__c       = false,
            ActualApprover__c      = UserInfo.getUserId(),
            ActionDate__c          = System.now()
        );
        insert step;

        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(grid.Id);
        Test.stopTest();

        System.assertEquals('Approved', result.processStatus, 'Process status should be Approved');
        System.assertEquals(false, result.canApproveOrReject, 'No pending steps — cannot approve');
        System.assertEquals(false, result.canRecall, 'Approved process cannot be recalled');
    }

    // ─── processApproval ────────────────────────────────────────────────────────

    @IsTest
    static void testProcessApproval_InvalidStepId_Approve() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = insertTestApproval(grid.Id, STATUS_PENDING);
        CustomApprovalStep__c step = insertPendingStep(approval.Id);
        delete step;

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(step.Id, 'Approve', null, null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for deleted step Id');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    @IsTest
    static void testProcessApproval_Recall() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = insertTestApproval(grid.Id, STATUS_PENDING);
        CustomApprovalStep__c step = insertPendingStep(approval.Id);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(step.Id, 'Removed', 'Recalled by test', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Recall should succeed: ' + result.errorMessage);
        CustomApproval__c updated = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Recalled', updated.Status__c, 'Approval status should be Recalled');
    }

    @IsTest
    static void testProcessApproval_WithNextApprovers_InvalidStep() {
        List<Id> nextApprovers = new List<Id>{ UserInfo.getUserId() };
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = insertTestApproval(grid.Id, STATUS_PENDING);
        CustomApprovalStep__c step = insertPendingStep(approval.Id);
        delete step;

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.processApproval(step.Id, 'Approve', 'Approved', nextApprovers);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for deleted step Id');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    // ─── submitForApproval ──────────────────────────────────────────────────────

    @IsTest
    static void testSubmitForApproval_InvalidProcess() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.submitForApproval(grid.Id, 'NonExistentProcess', null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for unknown process name');
        System.assertNotEquals(null, result.errorMessage, RESULT_NOT_NULL);
    }

    @IsTest
    static void testSubmitForApproval_ValidProcess() {
        // Exercises the controller delegation and the dynamic resolver path in the utility.
        // HOC resolver finds no approver for a test grid, so result is a graceful failure.
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryController.submitForApproval(grid.Id, PROCESS_NAME, null);
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(false, result.success, 'HOC dynamic resolver returns empty in test environment');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    // ─── getApprovalHistory — queue-assigned step ───────────────────────────────

    @IsTest
    static void testGetApprovalHistory_QueueAssignedStep_UserIsMember() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Group testQueue = new Group(Name = 'Test Approval Queue', Type = 'Queue');
        insert testQueue;
        // GroupMember is a setup object — must be in a separate DML transaction from custom objects
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = testQueue.Id, UserOrGroupId = UserInfo.getUserId());
        }

        CustomApproval__c approval = insertTestApproval(grid.Id, STATUS_PENDING);
        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c    = approval.Id,
            StepDeveloperName__c = 'GridAmendment_HOC',
            StepLabel__c         = 'HOC Approval',
            Status__c            = STATUS_PENDING,
            IsCurrentStep__c     = true,
            AssignedTo__c        = String.valueOf(testQueue.Id),
            AssignedToName__c    = 'Test Approval Queue'
        );
        insert step;

        Test.startTest();
        CustomApprovalHistoryController.ApprovalHistoryResult result = CustomApprovalHistoryController.getApprovalHistory(grid.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(1, result.rows.size(), 'Should have one row');
        System.assertEquals(true, result.canApproveOrReject, 'User is a member of the assigned queue — should be able to approve');
        System.assertEquals(true, result.canRecall, 'Submitter should be able to recall');
    }
}
