/** ──────────────────────────────────────
 * @description Test class for CustomApprovalHistoryUtility.
 *              Covers process submission, step approval/rejection/recall flows,
 *              Any-mode sibling recall, and the dynamic approver resolver path.
 * @author Charles EID
 * @covers CustomApprovalHistoryUtility
 ────────────────────────────────────── */
@IsTest
public with sharing class CustomApprovalHistoryUtilityTest {

    private static final String STEP_DEV_HOC    = 'GridAmendment_HOC';
    private static final String STEP_DEV_DCO    = 'GridAmendment_DCO_DO';
    private static final String STEP_DEV_LEGAL  = 'GridAmendment_Legal';
    private static final String STEP_LABEL_HOC  = 'HOC Approval';
    private static final String STEP_LABEL_DCO  = 'DCO-DO Approval';
    private static final String STEP_LABEL_LEGAL = 'Legal Approval';
    private static final String TEST_USER_NAME  = 'Test User';
    private static final String PROCESS_NAME    = 'GridAmendment';
    private static final String STATUS_PENDING  = 'Pending';

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── submitForApproval ───────────────────────────────────────────────────────
    @IsTest
    static void testSubmitForApproval_InvalidProcess() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.submitForApproval(grid.Id, 'NonExistentProcess', null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for unknown process name');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    @IsTest
    static void testSubmitForApproval_NoApproversResolved() {
        // HOC step uses GridHOCApproverResolver (Dynamic). In the test environment the grid's
        // Agreement has no Business_Region__c, so the resolver returns empty and submitForApproval
        // returns gracefully. Covers resolveDynamicApprovers and the "no approvers" early-return.
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.submitForApproval(grid.Id, PROCESS_NAME, 'comment');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail — HOC dynamic resolver returns empty in test environment');
        System.assertEquals('No approvers could be resolved for the initial step.', result.errorMessage);
    }

    // ─── processApproval — Recall ────────────────────────────────────────────────
    @IsTest
    static void testProcessApproval_Recall() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, STEP_DEV_HOC);
        CustomApprovalStep__c step = createStep(approval.Id, STEP_DEV_HOC, STEP_LABEL_HOC, TEST_USER_NAME);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Removed', 'Test recall', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Recall should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c, CurrentStepDevName__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Recalled', updatedApproval.Status__c, 'Approval status should be Recalled');
        System.assertEquals(null, updatedApproval.CurrentStepDevName__c, 'CurrentStepDevName should be cleared');

        List<CustomApprovalStep__c> updatedSteps = [SELECT Status__c, IsCurrentStep__c FROM CustomApprovalStep__c WHERE CustomApproval__c = :approval.Id];
        for (CustomApprovalStep__c s : updatedSteps) {
            System.assertEquals('Recalled', s.Status__c, 'Step status should be Recalled');
            System.assertEquals(false, s.IsCurrentStep__c, 'IsCurrentStep should be false after recall');
        }
    }

    // ─── processApproval — Reject ────────────────────────────────────────────────
    @IsTest
    static void testProcessApproval_Reject() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, STEP_DEV_HOC);
        CustomApprovalStep__c step = createStep(approval.Id, STEP_DEV_HOC, STEP_LABEL_HOC, TEST_USER_NAME);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Reject', 'Not approved', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Reject should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Rejected', updatedApproval.Status__c, 'Approval status should be Rejected');
    }

    // ─── processApproval — Approve, no next step (final) ────────────────────────
    @IsTest
    static void testProcessApproval_Approve_NoNextStep() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, STEP_DEV_LEGAL);
        CustomApprovalStep__c step = createStep(approval.Id, STEP_DEV_LEGAL, STEP_LABEL_LEGAL, TEST_USER_NAME);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Approve', 'Final approved', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Final approve should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Approved', updatedApproval.Status__c, 'Approval status should be Approved');
    }

    // ─── processApproval — Approve unanimous, partial (All mode, sibling still pending) ──
    @IsTest
    static void testProcessApproval_Approve_Unanimous_Partial() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, STEP_DEV_DCO);
        CustomApprovalStep__c step1 = createStep(approval.Id, STEP_DEV_DCO, STEP_LABEL_DCO, 'User 1');
        CustomApprovalStep__c step2 = createStep(approval.Id, STEP_DEV_DCO, STEP_LABEL_DCO, 'User 2');

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step1.Id, 'Approve', 'First approval', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Partial unanimous approve should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals(STATUS_PENDING, updatedApproval.Status__c, 'Approval should still be Pending (waiting for second approver)');

        List<CustomApprovalStep__c> remainingPending = [SELECT Id FROM CustomApprovalStep__c
                                                        WHERE CustomApproval__c = :approval.Id 
                                                        AND IsCurrentStep__c = true 
                                                        AND Status__c = :STATUS_PENDING];
        System.assertEquals(1, remainingPending.size(), 'One sibling should still be pending');
    }

    // ─── processApproval — Approve, with next step ───────────────────────────────
    @IsTest
    static void testProcessApproval_Approve_WithNextStep() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, STEP_DEV_HOC);
        CustomApprovalStep__c step = createStep(approval.Id, STEP_DEV_HOC, STEP_LABEL_HOC, TEST_USER_NAME);

        List<Id> nextApproverIds = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Approve', 'HOC approved', nextApproverIds);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Approve with next step should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c, CurrentStepDevName__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals(STATUS_PENDING, updatedApproval.Status__c, 'Approval should remain Pending (now at next step)');
        System.assertEquals(STEP_DEV_DCO, updatedApproval.CurrentStepDevName__c, 'Should advance to DCO step');

        List<CustomApprovalStep__c> newSteps = [SELECT Id FROM CustomApprovalStep__c
                                                WHERE CustomApproval__c = :approval.Id 
                                                AND StepDeveloperName__c = :STEP_DEV_DCO 
                                                AND IsCurrentStep__c = true];
        System.assertNotEquals(0, newSteps.size(), 'New pending steps should have been created for DCO');
    }

    // ─── processApproval — Approve, Any mode with sibling ───────────────────────
    @IsTest
    static void testProcessApproval_Approve_Any_WithSibling() {
        // HOC step has ApprovalMode = Any. When one of two sibling HOC steps is approved,
        // the other should be recalled and the process advances to the DCO step.
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, STEP_DEV_HOC);
        CustomApprovalStep__c step1 = createStep(approval.Id, STEP_DEV_HOC, STEP_LABEL_HOC, 'Approver A');
        CustomApprovalStep__c step2 = createStep(approval.Id, STEP_DEV_HOC, STEP_LABEL_HOC, 'Approver B');

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step1.Id, 'Approve', 'Approved by A', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Any-mode approve should succeed: ' + result.errorMessage);

        CustomApprovalStep__c sibling = [SELECT Status__c, IsCurrentStep__c FROM CustomApprovalStep__c WHERE Id = :step2.Id];
        System.assertEquals('Recalled', sibling.Status__c, 'Sibling step should be recalled in Any mode');
        System.assertEquals(false, sibling.IsCurrentStep__c, 'Sibling IsCurrentStep should be false after recall');

        CustomApproval__c updatedApproval = [SELECT Status__c, CurrentStepDevName__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals(STATUS_PENDING, updatedApproval.Status__c, 'Approval should advance to DCO and remain Pending');
        System.assertEquals(STEP_DEV_DCO, updatedApproval.CurrentStepDevName__c, 'Should advance to DCO step');
    }

    // ─── enforceApprovalLock ─────────────────────────────────────────────────────
    @IsTest
    static void testEnforceApprovalLock_BlocksNonExemptFieldOnLockedGrid() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = true);
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = false);

        Test.startTest();
        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });
        Test.stopTest();

        System.assertEquals(true, newGrid.hasErrors(), 'Editing a non-exempt field on an Approved grid should be blocked');
    }

    @IsTest
    static void testEnforceApprovalLock_AllowsGeneralExemptField() {
        // Comment__c is on the Grid General-scope exemption row (ApprovalLockFieldExemptionConfig.Grid_General) —
        // covers both the baseline "everyone" exemption and the line-based ExemptFields__c parsing.
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', Comment__c = 'Old comment');
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', Comment__c = 'New comment');

        Test.startTest();
        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });
        Test.stopTest();

        System.assertEquals(false, newGrid.hasErrors(), 'Comment__c is General-exempt and should remain editable while Approved');
    }

    @IsTest
    static void testEnforceApprovalLock_AllowsStatusTransition() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = true);
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Rejected', ActiveGrid__c = false);

        Test.startTest();
        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });
        Test.stopTest();

        System.assertEquals(false, newGrid.hasErrors(), 'A status transition away from a locked status should bypass field-level enforcement entirely');
    }

    @IsTest
    static void testEnforceApprovalLock_QueueScopeExemption() {
        // Matches ApprovalLockFieldExemptionConfig.Grid_TestExemptQueue: Queue-scope grant on ActiveGrid__c
        // for developer name Grid_ALE_Test_Exempt_Queue.
        Group testQueue = new Group(Name = 'Grid ALE Test Exempt Queue', DeveloperName = 'Grid_ALE_Test_Exempt_Queue', Type = 'Queue');
        insert testQueue;
        insert new GroupMember(GroupId = testQueue.Id, UserOrGroupId = UserInfo.getUserId());

        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = true);
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = false);

        Test.startTest();
        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });
        Test.stopTest();

        System.assertEquals(false, newGrid.hasErrors(), 'Current user is a member of the exempt queue, so ActiveGrid__c should be editable');
    }

    @IsTest
    static void testEnforceApprovalLock_QueueScopeExemption_NonMemberStillBlocked() {
        // Same queue-scoped grant exists, but the current user isn't a member, so it must not apply.
        Group testQueue = new Group(Name = 'Grid ALE Test Exempt Queue', DeveloperName = 'Grid_ALE_Test_Exempt_Queue', Type = 'Queue');
        insert testQueue;

        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = true);
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = false);

        Test.startTest();
        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });
        Test.stopTest();

        System.assertEquals(true, newGrid.hasErrors(), 'Current user is not a member of the exempt queue, so ActiveGrid__c should still be locked');
    }

    @IsTest
    static void testEnforceApprovalLock_AdminStillBlockedWhenEnforceLockOnAdminsTrue() {
        // Grid's ApprovalLockConfig has EnforceLockOnAdmins__c = true, so even an Administrator-profile
        // user must be blocked from editing a non-exempt field while Approved.
        User adminUser = TestFactory.getCarmignacAdminUserTestApex();
        System.assertEquals(true, CustomApprovalHistoryUtility.isAdministrator(adminUser.Id), 'Sanity check: seeded user should resolve as administrator');

        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = true);
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = false);

        Test.startTest();
        System.runAs(adminUser) {
            CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });
        }
        Test.stopTest();

        System.assertEquals(true, newGrid.hasErrors(), 'EnforceLockOnAdmins__c is true, so admins must still be blocked from editing non-exempt fields');
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────
    private static CustomApproval__c createApproval(Id targetId, String currentStepDevName) {
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(targetId),
            Status__c               = STATUS_PENDING,
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = PROCESS_NAME,
            CurrentStepDevName__c   = currentStepDevName
        );
        insert approval;
        return approval;
    }

    private static CustomApprovalStep__c createStep(Id approvalId, String stepDevName, String stepLabel, String assignedToName) {
        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c    = approvalId,
            StepDeveloperName__c = stepDevName,
            StepLabel__c         = stepLabel,
            Status__c            = STATUS_PENDING,
            IsCurrentStep__c     = true,
            AssignedTo__c        = String.valueOf(UserInfo.getUserId()),
            AssignedToName__c    = assignedToName
        );
        insert step;
        return step;
    }
}