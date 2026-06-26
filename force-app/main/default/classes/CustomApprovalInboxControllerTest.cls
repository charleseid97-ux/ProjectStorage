/** ──────────────────────────────────────
 * @description Test class for CustomApprovalInboxController.
 *              Covers empty-inbox, user-assigned steps, queue-assigned steps,
 *              TECH_ReadOnly exclusion, and correctness of returned item fields.
 * @author Charles EID
 * @covers CustomApprovalInboxController
 ────────────────────────────────────── */
@IsTest
public with sharing class CustomApprovalInboxControllerTest {

    private static final String PROCESS_NAME     = 'GridAmendment';
    private static final String STEP_DEV_HOC     = 'GridAmendment_HOC';
    private static final String STEP_LABEL_HOC   = 'HOC Approval';
    private static final String STATUS_PENDING   = 'Pending';
    private static final String RELATED_TO_LABEL = 'Test Grid Record';

    private static final String RESULT_NOT_NULL  = 'Result should not be null';
    private static final String ITEMS_EMPTY      = 'Items list should be empty';
    private static final String ITEMS_ONE        = 'Items list should contain one item';

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────
    private static CustomApproval__c createApproval(Id targetId, String relatedToLabel) {
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(targetId),
            RelatedToLabel__c       = relatedToLabel,
            Status__c               = STATUS_PENDING,
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = PROCESS_NAME,
            CurrentStepDevName__c   = STEP_DEV_HOC
        );
        insert approval;
        return approval;
    }

    private static CustomApprovalStep__c createStep(Id approvalId, String assignedToId, String assignedToName, Id previousApproverId) {
        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c         = approvalId,
            StepDeveloperName__c      = STEP_DEV_HOC,
            StepLabel__c              = STEP_LABEL_HOC,
            Status__c                 = STATUS_PENDING,
            IsCurrentStep__c          = true,
            AssignedTo__c             = assignedToId,
            AssignedToName__c         = assignedToName,
            OriginalAssignedTo__c     = assignedToId,
            OriginalAssignedToName__c = assignedToName,
            PreviousApprover__c       = previousApproverId
        );
        insert step;
        return step;
    }

    // ─── No pending steps ─────────────────────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_NoPendingSteps() {
        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', '', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.size(), ITEMS_EMPTY);
    }

    // ─── User directly assigned ───────────────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_UserAssignedDirectly() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', '', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(1, result.size(), ITEMS_ONE);
    }

    // ─── Correct field values ─────────────────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_FieldValues() {
        Grid__c grid   = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        CustomApprovalStep__c step = createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), UserInfo.getUserId());

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', '', '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        CustomApprovalInboxController.ItemToApprove item = result[0];

        System.assertEquals(String.valueOf(step.Id), item.stepId, 'stepId should match the step record');
        System.assertEquals(RELATED_TO_LABEL, item.targetRecordName, 'targetRecordName should come from RelatedToLabel__c');
        System.assertEquals(String.valueOf(grid.Id), item.targetRecordId, 'targetRecordId should match the grid Id');
        System.assertNotEquals(null, item.objectLabel, 'objectLabel should be resolved from the target record Id');
        System.assertEquals(STEP_LABEL_HOC, item.stepLabel, 'stepLabel should match the step label');
        System.assertNotEquals(null, item.submissionDateFormatted, 'submissionDateFormatted should not be null');
        System.assertNotEquals('', item.submissionDateFormatted, 'submissionDateFormatted should not be empty');
        System.assertEquals(UserInfo.getName(), item.previousApproverName, 'previousApproverName should come from PreviousApprover__r.Name');
    }

    // ─── Queue-assigned step, current user is member ──────────────────────────────
    @IsTest
    static void testGetItemsToApprove_QueueAssigned_UserIsMember() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Group testQueue = new Group(Name = 'Test Inbox Queue', Type = 'Queue');
        insert testQueue;
        // GroupMember is a setup object — must be in a separate DML transaction
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = testQueue.Id, UserOrGroupId = UserInfo.getUserId());
        }

        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(testQueue.Id), 'Test Inbox Queue', null);

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', '', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(1, result.size(), 'Queue-assigned step should be visible to a queue member');
    }

    // ─── TECH_ReadOnly exclusion ──────────────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_ReadOnlyApproval_Excluded() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        // Mark the approval as read-only — the step should be excluded from the inbox
        approval.TECH_ReadOnly__c = true;
        update approval;

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', '', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.size(), 'Steps on a TECH_ReadOnly approval should be excluded');
    }

    // ─── Multiple items — all returned ───────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_MultipleItems_AllReturned() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        CustomApproval__c approval1 = createApproval(grid.Id, 'Record A');
        CustomApproval__c approval2 = createApproval(grid.Id, 'Record B');
        createStep(approval1.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);
        createStep(approval2.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', '', '');
        Test.stopTest();

        System.assertEquals(2, result.size(), 'All approvable items should be returned without a cap');
    }

    // ─── approvalSystem = 'Custom' only ──────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_CustomOnly() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', 'Custom', '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        System.assertEquals(false, result[0].isStandardApproval, 'Should be a custom approval item');
    }

    // ─── approvalSystem = 'Standard' — no workitems in test env ─────────────────
    @IsTest
    static void testGetItemsToApprove_StandardOnly_Empty() {
        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', 'Standard', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.size(), 'No standard workitems expected in test environment');
    }

    // ─── Standard items — empty workitem list — exercises queryPendingWorkitems override ──
    @IsTest
    static void testGetItemsToApprove_StandardItems_Injected_Empty() {
        // Inject an empty list — exercises the testWorkitemsOverride branch and the isEmpty guard
        CustomApprovalInboxController.testWorkitemsOverride = new List<ProcessInstanceWorkitem>();

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', 'Standard', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.size(), 'Empty workitem override should yield no items');
    }

    // ─── Standard items — non-empty injection — exercises getStandardItems body to early return ──
    @IsTest
    static void testGetItemsToApprove_StandardItems_Injected_NonEmpty() {
        // Inject a workitem with null ProcessInstance (relationship not settable in Apex DML).
        // groupWorkitemsByObjType skips null TargetObjectId, so targetIdsByObjType stays empty
        // and getStandardItems returns early. This covers: isEmpty guard false-branch,
        // buildSObjectInfoCacheFromWorkitems loop, groupWorkitemsByObjType null-check, empty-map guard.
        ProcessInstanceWorkitem wi = new ProcessInstanceWorkitem();
        CustomApprovalInboxController.testWorkitemsOverride = new List<ProcessInstanceWorkitem>{ wi };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', 'Standard', '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.size(), 'Workitem with null TargetObjectId should be skipped entirely');
    }

    // ─── buildLabelFieldByObjType — direct unit test via @TestVisible ─────────────
    @IsTest
    static void testBuildLabelFieldByObjType_WithAndWithoutCustomField() {
        ApprovalProcessConfig__mdt cfgWithCustom = new ApprovalProcessConfig__mdt(
            DeveloperName            = 'CfgA',
            ObjectType__c            = 'Grid__c',
            TargetLabelFieldApiName__c = 'CustomName__c'
        );
        ApprovalProcessConfig__mdt cfgWithBlank = new ApprovalProcessConfig__mdt(
            DeveloperName            = 'CfgB',
            ObjectType__c            = 'Opportunity',
            TargetLabelFieldApiName__c = null
        );
        Map<String, ApprovalProcessConfig__mdt> configByObjType = new Map<String, ApprovalProcessConfig__mdt>{
            'Grid__c'     => cfgWithCustom,
            'Opportunity' => cfgWithBlank
        };

        Test.startTest();
        Map<String, String> result = CustomApprovalInboxController.buildLabelFieldByObjType(configByObjType);
        Test.stopTest();

        System.assertEquals('CustomName__c', result.get('Grid__c'),     'Custom TargetLabelFieldApiName__c should be used');
        System.assertEquals('Name',          result.get('Opportunity'), 'Blank TargetLabelFieldApiName__c should fall back to Name');
    }

    // ─── buildExtendedPathsByObjType — direct unit test via @TestVisible ──────────
    @IsTest
    static void testBuildExtendedPathsByObjType_IncludesLabelAndDisplayFields() {
        ApprovalProcessConfig__mdt cfg = new ApprovalProcessConfig__mdt(
            DeveloperName            = PROCESS_NAME,
            ObjectType__c            = 'Grid__c',
            InboxDisplayFields__c    = 'Status__c',
            TargetLabelFieldApiName__c = 'Agreement__r.Name'
        );
        Map<String, ApprovalProcessConfig__mdt> configByObjType = new Map<String, ApprovalProcessConfig__mdt>{
            'Grid__c' => cfg
        };
        Map<String, String> labelFieldByObjType = new Map<String, String>{
            'Grid__c' => 'Agreement__r.Name'
        };
        Set<String> allObjTypes = new Set<String>{ 'Grid__c' };

        Test.startTest();
        Map<String, List<String>> result = CustomApprovalInboxController.buildExtendedPathsByObjType(
            allObjTypes, configByObjType, labelFieldByObjType
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('Grid__c'), 'Result should contain Grid__c paths');
        List<String> paths = result.get('Grid__c');
        System.assert(paths.contains('Agreement__r.Name'), 'Label field path should be included');
        System.assert(paths.contains('Status__c'),          'Display field path should be included');
    }

    // ─── objectApiName filter — matching object ───────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_ObjectApiNameFilter_Match() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        // Inject MDT config so ObjectType__c is 'Grid__c' and the filter can match
        ApprovalProcessConfig__mdt mockCfg = new ApprovalProcessConfig__mdt(
            DeveloperName         = PROCESS_NAME,
            ObjectType__c         = 'Grid__c',
            InboxDisplayFields__c = null
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('Grid__c', 'Custom', , '');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Grid__c step should pass the object filter');
    }

    // ─── objectApiName filter — non-matching object ───────────────────────────────
    @IsTest
    static void testGetItemsToApprove_ObjectApiNameFilter_NoMatch() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        ApprovalProcessConfig__mdt mockCfg = new ApprovalProcessConfig__mdt(
            DeveloperName         = PROCESS_NAME,
            ObjectType__c         = 'Grid__c',
            InboxDisplayFields__c = null
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('Opportunity', 'Custom', '');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Grid__c step should be excluded when filtering by Opportunity');
    }

    // ─── objectLabel falls back to Id casting when ObjectType__c is null ────────
    @IsTest
    static void testGetItemsToApprove_ObjectLabel_FallbackToIdCasting() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        // Inject config with null ObjectType__c — forces the Id-casting else branch in buildCustomItem
        ApprovalProcessConfig__mdt mockCfg = new ApprovalProcessConfig__mdt(
            DeveloperName         = PROCESS_NAME,
            ObjectType__c         = null,
            InboxDisplayFields__c = null
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', 'Custom', '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        System.assertNotEquals(null, result[0].objectLabel, 'objectLabel should be resolved via Id-casting fallback');
    }

    // ─── Display fields resolved from MDT ────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_DisplayFields_Resolved() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        // Inject MDT config with a real field path on Grid__c
        ApprovalProcessConfig__mdt mockCfg = new ApprovalProcessConfig__mdt(
            DeveloperName         = PROCESS_NAME,
            ObjectType__c         = 'Grid__c',
            InboxDisplayFields__c = 'Name\nAgreement__r.Name' // direct + relationship field — exercises resolveFieldDescribeUncached traversal
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', 'Custom', '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        CustomApprovalInboxController.ItemToApprove item = result[0];
        System.assertNotEquals(null, item.displayFields, 'displayFields should be populated');
        System.assertEquals(2, item.displayFields.size(), 'Two display field entries expected');
        System.assertNotEquals(null, item.displayFields[0].label, 'Display field label should be resolved');
    }
}