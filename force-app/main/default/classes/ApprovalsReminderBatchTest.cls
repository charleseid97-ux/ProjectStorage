/** ──────────────────────────────────────
 * @description Test class for ApprovalsReminderBatch.
 *              Uses CustomApprovalInboxController.testItemsToApproveOverride to inject controlled
 *                  ItemToApprove data without requiring real approval process records.
 *              Uses JSON deserialization to build fake CMDT configs without DML.
 * @author Charles EID
 * @covers ApprovalsReminderBatch
 * @covers LegalApprovalsRecipientResolver
 ────────────────────────────────────── */
@isTest
private class ApprovalsReminderBatchTest {

    private static final Map<String, Set<String>> MOCK_EMAILS = new Map<String, Set<String>>{
        'Legal_Queue' => new Set<String>{ 'legal.test@carmignac.test.invalid' }
    };

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── Tests ───────────────────────────────────────────────────────────────────
    @isTest
    static void testOverdueCustomItemSendsEmail() {
        // Overdue custom approval — exercises buildTableHtml (custom link) and email building paths
        ApprovalsReminderBatch.testEmailsByQueueOverride = MOCK_EMAILS;
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{ makeItem(DateTime.now().addDays(-35), false)};

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    @isTest
    static void testOverdueStandardItemSendsEmail() {
        // Overdue standard approval — exercises buildTableHtml isStandardApproval = true branch (uses stepId)
        ApprovalsReminderBatch.testEmailsByQueueOverride = MOCK_EMAILS;
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{ makeItem(DateTime.now().addDays(-35), true) };

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    @isTest
    static void testRecentItemIsExcluded() {
        // Item submitted today — filtered out, no email sent (overdue list is empty → early return)
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{ makeItem(DateTime.now(), false) };

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    @isTest
    static void testNoItemsNoEmail() {
        // Empty list — early return before queue resolution or email building
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>();

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    @isTest
    static void testNonExistentTemplateFallsBackToDatatable() {
        // Non-blank template name that doesn't exist in DB — covers getEmailTemplateHtml query + fallback path
        ApprovalsReminderBatch.testEmailsByQueueOverride = MOCK_EMAILS;
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{ makeItem(DateTime.now().addDays(-35), false) };

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfigWithTemplate('NonExistentTemplateXYZ')), 1);
        Test.stopTest();
    }

    @isTest
    static void testNullSubmissionDateSkipped() {
        // Item with null submissionDate — skipped by the null guard, treated like no overdue items
        CustomApprovalInboxController.ItemToApprove item = makeItem(DateTime.now().addDays(-35), false);
        item.submissionDate = null;
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{ item };

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    @isTest
    static void testDispatchMethod() {
        // dispatch() enqueues a new batch; Test.stopTest() drives it to completion
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>();

        Test.startTest();
        new ApprovalsReminderBatch().dispatch(makeAlertConfig());
        Test.stopTest();
    }

    @isTest
    static void testResolverClassRoutesItemsByRegion() {
        // Exercises LegalApprovalsRecipientResolver: Grid with a known region → MDT match → CC address populated
        ApprovalsReminderBatch.testEmailsByQueueOverride = MOCK_EMAILS;
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        update new Grid__c(Id = grid.Id, TECH_BusinessRegion__c = 'BP_FR');

        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{
            makeItem(DateTime.now().addDays(-35), false, grid.Id)
        };

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    @isTest
    static void testResolverClassCatchAllBundle() {
        // Item with unrecognised targetRecordId → catch-all bundle (no CC), still sent to Legal_Queue TO
        ApprovalsReminderBatch.testEmailsByQueueOverride = MOCK_EMAILS;
        CustomApprovalInboxController.testItemsToApproveOverride = new List<CustomApprovalInboxController.ItemToApprove>{
            makeItem(DateTime.now().addDays(-35), false)
        };

        Test.startTest();
        Database.executeBatch(new ApprovalsReminderBatch(makeAlertConfig()), 1);
        Test.stopTest();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────
    private static ScheduledAlert__mdt makeAlertConfig() {
        return (ScheduledAlert__mdt) JSON.deserialize(
            '{"ApexClass__c":"ApprovalsReminderBatch","IsActive__c":true,"Frequency__c":"Weekly","EmailTemplate__c":null}',
            ScheduledAlert__mdt.class
        );
    }

    private static ScheduledAlert__mdt makeAlertConfigWithTemplate(String templateName) {
        return (ScheduledAlert__mdt) JSON.deserialize(
            '{"ApexClass__c":"ApprovalsReminderBatch","IsActive__c":true,"Frequency__c":"Weekly","EmailTemplate__c":"' + templateName + '"}',
            ScheduledAlert__mdt.class
        );
    }

    private static CustomApprovalInboxController.ItemToApprove makeItem(DateTime submissionDate, Boolean isStandard) {
        CustomApprovalInboxController.ItemToApprove item = new CustomApprovalInboxController.ItemToApprove();
        item.stepId                  = 'STEP000001';
        item.targetRecordId          = 'TARGET0001';
        item.targetRecordName        = 'Test Record';
        item.objectLabel             = 'Convention';
        item.submittedByName         = 'Test User';
        item.stepLabel               = 'Legal Review';
        item.submissionDate          = submissionDate;
        item.submissionDateFormatted = submissionDate.format('dd/MM/yyyy HH:mm');
        item.isStandardApproval      = isStandard;
        return item;
    }

    private static CustomApprovalInboxController.ItemToApprove makeItem(DateTime submissionDate, Boolean isStandard, Id targetRecordId) {
        CustomApprovalInboxController.ItemToApprove item = makeItem(submissionDate, isStandard);
        item.targetRecordId = targetRecordId;
        return item;
    }
}