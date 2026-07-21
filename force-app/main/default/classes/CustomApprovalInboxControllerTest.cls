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

    private static final String OBJECT_GRID         = 'Grid__c';
    private static final String OBJECT_OPPORTUNITY  = 'Opportunity';
    private static final String AGREEMENT_NAME      = 'Agreement__r.Name';
    private static final String FIELD_STATUS        = 'Status__c';

    private static final String APP_PROCESS_CUSTOM   = 'Custom';
    private static final String APP_PROCESS_STANDARD = 'Standard';

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

    // ─── approvalSystem = APP_PROCESS_CUSTOM only ──────────────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_CustomOnly() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_CUSTOM, '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        System.assertEquals(false, result[0].isStandardApproval, 'Should be a custom approval item');
    }

    // ─── approvalSystem = APP_PROCESS_STANDARD — no workitems in test env ─────────────────
    @IsTest
    static void testGetItemsToApprove_StandardOnly_Empty() {
        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_STANDARD, '');
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
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_STANDARD, '');
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
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_STANDARD, '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(0, result.size(), 'Workitem with null TargetObjectId should be skipped entirely');
    }

    // ─── buildLabelFieldByObjType — direct unit test via @TestVisible ─────────────
    @IsTest
    static void testBuildLabelFieldByObjType_WithAndWithoutCustomField() {
        ApprovalProcessConfig__mdt cfgWithCustom = new ApprovalProcessConfig__mdt(
            DeveloperName            = 'CfgA',
            ObjectType__c            = OBJECT_GRID,
            TargetLabelFieldApiName__c = 'CustomName__c'
        );
        ApprovalProcessConfig__mdt cfgWithBlank = new ApprovalProcessConfig__mdt(
            DeveloperName            = 'CfgB',
            ObjectType__c            = OBJECT_OPPORTUNITY,
            TargetLabelFieldApiName__c = null
        );
        Map<String, ApprovalProcessConfig__mdt> configByObjType = new Map<String, ApprovalProcessConfig__mdt>{
            OBJECT_GRID     => cfgWithCustom,
            OBJECT_OPPORTUNITY => cfgWithBlank
        };

        Test.startTest();
        Map<String, String> result = CustomApprovalInboxController.buildLabelFieldByObjType(configByObjType);
        Test.stopTest();

        System.assertEquals('CustomName__c', result.get(OBJECT_GRID),     'Custom TargetLabelFieldApiName__c should be used');
        System.assertEquals('Name',          result.get(OBJECT_OPPORTUNITY), 'Blank TargetLabelFieldApiName__c should fall back to Name');
    }

    // ─── buildExtendedPathsByObjType — direct unit test via @TestVisible ──────────
    @IsTest
    static void testBuildExtendedPathsByObjType_IncludesLabelAndDisplayFields() {
        ApprovalProcessConfig__mdt cfg = new ApprovalProcessConfig__mdt(
            DeveloperName            = PROCESS_NAME,
            ObjectType__c            = OBJECT_GRID,
            InboxDisplayFields__c    = FIELD_STATUS,
            TargetLabelFieldApiName__c = AGREEMENT_NAME
        );
        Map<String, ApprovalProcessConfig__mdt> configByObjType = new Map<String, ApprovalProcessConfig__mdt>{
            OBJECT_GRID => cfg
        };
        Map<String, String> labelFieldByObjType = new Map<String, String>{
            OBJECT_GRID => AGREEMENT_NAME
        };
        Set<String> allObjTypes = new Set<String>{ OBJECT_GRID };

        Test.startTest();
        Map<String, List<String>> result = CustomApprovalInboxController.buildExtendedPathsByObjType(
            allObjTypes, configByObjType, labelFieldByObjType
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get(OBJECT_GRID), 'Result should contain Grid__c paths');
        List<String> paths = result.get(OBJECT_GRID);
        System.assert(paths.contains(AGREEMENT_NAME), 'Label field path should be included');
        System.assert(paths.contains(FIELD_STATUS),          'Display field path should be included');
    }

    // ─── objectApiName filter — matching object ───────────────────────────────────
    @IsTest
    static void testGetItemsToApprove_ObjectApiNameFilter_Match() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = createApproval(grid.Id, RELATED_TO_LABEL);
        createStep(approval.Id, String.valueOf(UserInfo.getUserId()), UserInfo.getName(), null);

        // Inject MDT config so ObjectType__c is OBJECT_GRID and the filter can match
        ApprovalProcessConfig__mdt mockCfg = new ApprovalProcessConfig__mdt(
            DeveloperName         = PROCESS_NAME,
            ObjectType__c         = OBJECT_GRID,
            InboxDisplayFields__c = null
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove(OBJECT_GRID, APP_PROCESS_CUSTOM, '');
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
            ObjectType__c         = OBJECT_GRID,
            InboxDisplayFields__c = null
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove(OBJECT_OPPORTUNITY, APP_PROCESS_CUSTOM, '');
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
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_CUSTOM, '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        System.assertNotEquals(null, result[0].objectLabel, 'objectLabel should be resolved via Id-casting fallback');
    }

    // ─── Standard items — user-assigned workitem with real TargetObjectId ───────────
    @IsTest
    static void testGetItemsToApprove_StandardItems_UserActorId() {
        // JSON-deserializes a workitem with ActorId = currentUserId and a real Grid__c TargetObjectId.
        // This exercises filterVisibleWorkitems user-match path, all of getStandardItems (lines 104-124),
        // groupWorkitemsByObjType non-null TargetObjectId branch, and buildStandardResult (lines 172-196).
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        String wiJson = '{"ActorId":"' + UserInfo.getUserId() + '","ProcessInstance":{"TargetObjectId":"' + grid.Id + '"}}';
        CustomApprovalInboxController.testWorkitemsOverride = new List<ProcessInstanceWorkitem>{
            (ProcessInstanceWorkitem) JSON.deserialize(wiJson, ProcessInstanceWorkitem.class)
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_STANDARD, '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(1, result.size(), ITEMS_ONE);
        System.assertEquals(true, result[0].isStandardApproval, 'Item should be flagged as standard approval');
        System.assertNotEquals(null, result[0].targetRecordId, 'targetRecordId should be set from TargetObjectId');
    }

    // ─── Standard items — queue-assigned workitem exercises filterVisibleWorkitems queue path ──
    @IsTest
    static void testGetItemsToApprove_StandardItems_QueueActorId() {
        // Creates a queue, adds current user as member, then injects a workitem with ActorId = queueId.
        // Covers filterVisibleWorkitems '00G' branch and QueueMemberService.resolveMembers call.
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Group q = new Group(Name = 'StandardApprovalTestQueue', Type = 'Queue');
        insert q;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }
        String wiJson = '{"ActorId":"' + q.Id + '","ProcessInstance":{"TargetObjectId":"' + grid.Id + '"}}';
        CustomApprovalInboxController.testWorkitemsOverride = new List<ProcessInstanceWorkitem>{
            (ProcessInstanceWorkitem) JSON.deserialize(wiJson, ProcessInstanceWorkitem.class)
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_STANDARD, '');
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
        System.assertEquals(1, result.size(), ITEMS_ONE);
        System.assertEquals(true, result[0].isStandardApproval, 'Item should be flagged as standard approval');
    }

    // ─── Non-blank queueDevNames — covers parseQueueDevNames and resolveQueuesByDevName paths ──
    @IsTest
    static void testGetItemsToApprove_WithQueueDevNames_CoversLoopBodies() {
        // Insert a queue, query back its DeveloperName, then pass it to getItemsToApprove.
        // This covers: parseQueueDevNames split loop body, resolveQueuesByDevName query loop body
        // (result.put when queue is found), and the queueNamesById non-empty path in getCustomItems.
        Group q = new Group(Name = 'InboxCoverageTestQueue', DeveloperName = 'InboxCoverageTestQueue', Type = 'Queue');
        insert q;
        Group inserted = [SELECT Id, DeveloperName FROM Group WHERE Id = :q.Id LIMIT 1];

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_CUSTOM, inserted.DeveloperName);
        Test.stopTest();

        System.assertNotEquals(null, result, RESULT_NOT_NULL);
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
            ObjectType__c         = OBJECT_GRID,
            InboxDisplayFields__c = 'Name\nAgreement__r.Name' // direct + relationship field — exercises resolveFieldDescribeUncached traversal
        );
        CustomApprovalInboxController.testMdtConfigOverride = new Map<String, ApprovalProcessConfig__mdt>{
            PROCESS_NAME => mockCfg
        };

        Test.startTest();
        List<CustomApprovalInboxController.ItemToApprove> result = CustomApprovalInboxController.getItemsToApprove('', APP_PROCESS_CUSTOM, '');
        Test.stopTest();

        System.assertEquals(1, result.size(), ITEMS_ONE);
        CustomApprovalInboxController.ItemToApprove item = result[0];
        System.assertNotEquals(null, item.displayFields, 'displayFields should be populated');
        System.assertEquals(2, item.displayFields.size(), 'Two display field entries expected');
        System.assertNotEquals(null, item.displayFields[0].label, 'Display field label should be resolved');
    }
}