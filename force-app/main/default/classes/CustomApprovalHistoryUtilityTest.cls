/** ──────────────────────────────────────
 * @description Test class for CustomApprovalHistoryUtility.
 *              Covers process submission, step approval/rejection/recall flows,
 *              Any-mode sibling recall, and the dynamic approver resolver path.
 * @author Charles EID
 * @covers CustomApprovalHistoryUtility     73%     [06-07-26]
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
    }

    @IsTest
    static void testEnforceApprovalLock_BlocksFieldClearedToNull() {
        // Regression test: resolveCheckableFields used to source its field list from the NEW record's
        // getPopulatedFieldsAsMap(), so a field cleared to null (absent from that map) silently escaped
        // detection — users could remove EndDate__c on a locked Grid but not put it back. Fixed by
        // building the checkable-field list from the object's schema instead of any record's population.
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', EndDate__c = Date.today());
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', EndDate__c = null);

        Test.startTest();

        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });

        Test.stopTest();

        System.assert(newGrid.hasErrors(), 'Clearing EndDate__c on a locked, non-exempt Grid should be blocked even though the new value is null.');
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
    }

    @IsTest
    static void testEnforceApprovalLock_AllowsStatusTransition() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c oldGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Approved', ActiveGrid__c = true);
        Grid__c newGrid = new Grid__c(Id = grid.Id, ApprovalStatus__c = 'Rejected', ActiveGrid__c = false);

        Test.startTest();

        CustomApprovalHistoryUtility.enforceApprovalLock(new List<SObject>{ newGrid }, new Map<Id, SObject>{ grid.Id => oldGrid });

        Test.stopTest();
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