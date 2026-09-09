/** ──────────────────────────────────────
 * @description Test class for GridAmendmentAgreementStatusAction.
 * @author Charles EID
 * @testClass GridAmendmentAgreementStatusActionTest
────────────────────────────────────── */
@IsTest
private class GridAmendmentAgreementStatusActionTest {

    private static final String STATUS_SIGNED           = 'Signed';
    private static final String STATUS_IN_NEGOTIATION   = 'In Negotiation';
    private static final String STATUS_CHANGE_REQUESTED = 'Change Requested';
    private static final String STATUS_PENDING_RENEWAL  = 'Pending Renewal';
    private static final String STATUS_CHANGE_RENEWAL   = 'Change Renewal';

    private static final String TIMELINE_STATUS_ACTIVE = 'Active';
    private static final String TIMELINE_STATUS_DRAFT  = 'Draft';

    private static final String COUNTRY_FR = 'FR';

    private static final String CRITERIA_FILTER_LOGIC            = 'AND';
    private static final String CRITERIA_FILTER_LOGIC_EXPRESSION = '1';
    private static final String CRITERIA_COMMENT                 = 'Master Criteria';
    private static final String RULE_TO_APPLY_PERCENTAGE_OF_FEES = 'Percentage of Fees';
    private static final String RULE_FEES_TYPE_EFFECTIVE_MGMT    = 'EffectiveManagementFees__c';

    private static final String NOEND_SUFFIX        = 'NOEND';
    private static final String NOEND_OLD_GRID_NAME  = 'OldGrid-NoEnd';
    private static final String NOEND_NEW_GRID_NAME  = 'NewGrid-NoEnd';

    private static final String MATCH_SUFFIX           = 'MATCH';
    private static final String MATCH_MASTER_GRID_NAME = 'MasterGrid-Match';
    private static final String MATCH_OLD_GRID_NAME    = 'OldGrid-Match';
    private static final String MATCH_NEW_GRID_NAME    = 'NewGrid-Match';

    private static final String DIFF_SUFFIX           = 'DIFF';
    private static final String DIFF_MASTER_GRID_NAME = 'MasterGrid-Diff';
    private static final String DIFF_OLD_GRID_NAME    = 'OldGrid-Diff';
    private static final String DIFF_NEW_GRID_NAME    = 'NewGrid-Diff';

    private static final String GUARD_SUFFIX            = 'GUARD';
    private static final String GUARD_OLD_GRID_NAME      = 'OldGrid-Guard';
    private static final String GUARD_NEW_GRID_NAME      = 'NewGrid-Guard';
    private static final String GUARD_LATER_GRID_NAME    = 'LaterGrid-Guard';

    private static final String NOTSIGNED_SUFFIX          = 'NOTSIGNED';
    private static final String NOTSIGNED_OLD_GRID_NAME    = 'OldGrid-NotSigned';
    private static final String NOTSIGNED_NEW_GRID_NAME    = 'NewGrid-NotSigned';

    private static final String AGREEMENT_NAME_PREFIX = 'AGR-TEST-';
    private static final String AGREEMENT_CONVENTION_NAME_PREFIX = 'Test Convention ';
    private static final String AGREEMENT_CODE_PREFIX = 'AGR-TEST-CODE-';

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testChangeRequested_whenPreviousGridHasNoEndDate() {
        Grid__c oldGrid = GridTestSetupHelper.createGrid(NOEND_OLD_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert oldGrid; // EndDate__c left null

        Grid__c newGrid = GridTestSetupHelper.createGrid(NOEND_NEW_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert newGrid;

        Convention__c agreement = linkAgreement(oldGrid, newGrid, NOEND_SUFFIX);

        Test.startTest();
        new GridAmendmentAgreementStatusAction().execute(newGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Convention__c updated = [SELECT Status__c FROM Convention__c WHERE Id = :agreement.Id];
        System.assertEquals(STATUS_CHANGE_REQUESTED, updated.Status__c, 'Agreement status should be Change Requested when the previous grid has no end date.');
    }

    @IsTest
    static void testPendingRenewal_whenGridDetailsMatch() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();
        Grid__c masterGrid = createStandardGrid(MATCH_MASTER_GRID_NAME);
        GridDetail__c masterDetail = createMasterStandardDetail(masterGrid, shareClasses[0].Id);

        Grid__c oldGrid = createEndedCustomGrid(MATCH_OLD_GRID_NAME);
        addCustomDetail(oldGrid, shareClasses[0].Id, masterDetail.Id);

        Grid__c newGrid = createCustomGrid(MATCH_NEW_GRID_NAME);
        addCustomDetail(newGrid, shareClasses[0].Id, masterDetail.Id);

        Convention__c agreement = linkAgreement(oldGrid, newGrid, MATCH_SUFFIX);

        Test.startTest();
        new GridAmendmentAgreementStatusAction().execute(newGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Convention__c updated = [SELECT Status__c FROM Convention__c WHERE Id = :agreement.Id];
        System.assertEquals(STATUS_PENDING_RENEWAL, updated.Status__c, 'Agreement status should be Pending Renewal when the new grid has identical detail lines to the ended previous grid.');
    }

    @IsTest
    static void testChangeRenewal_whenGridDetailsDiffer() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();
        Grid__c masterGrid = createStandardGrid(DIFF_MASTER_GRID_NAME);
        GridDetail__c masterDetail1 = createMasterStandardDetail(masterGrid, shareClasses[0].Id);
        GridDetail__c masterDetail2 = createMasterStandardDetail(masterGrid, shareClasses[1].Id);

        Grid__c oldGrid = createEndedCustomGrid(DIFF_OLD_GRID_NAME);
        addCustomDetail(oldGrid, shareClasses[0].Id, masterDetail1.Id);

        Grid__c newGrid = createCustomGrid(DIFF_NEW_GRID_NAME);
        addCustomDetail(newGrid, shareClasses[1].Id, masterDetail2.Id);

        Convention__c agreement = linkAgreement(oldGrid, newGrid, DIFF_SUFFIX);

        Test.startTest();
        new GridAmendmentAgreementStatusAction().execute(newGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Convention__c updated = [SELECT Status__c FROM Convention__c WHERE Id = :agreement.Id];
        System.assertEquals(STATUS_CHANGE_RENEWAL, updated.Status__c, 'Agreement status should be Change Renewal when the new grid detail lines differ from the ended previous grid.');
    }

    @IsTest
    static void testNoUpdate_whenSubmittedGridIsNotMostRecent() {
        Grid__c oldGrid = GridTestSetupHelper.createGrid(GUARD_OLD_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert oldGrid;

        Grid__c newGrid = GridTestSetupHelper.createGrid(GUARD_NEW_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert newGrid;

        Convention__c agreement = linkAgreement(oldGrid, newGrid, GUARD_SUFFIX);

        Grid__c laterGrid = GridTestSetupHelper.createGrid(GUARD_LATER_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert laterGrid;
        insert GridTestSetupHelper.createAgreementGridTimeline(agreement.Id, laterGrid.Id, Date.today().addDays(10), null, TIMELINE_STATUS_DRAFT);

        Convention__c before = [SELECT Status__c FROM Convention__c WHERE Id = :agreement.Id];

        Test.startTest();
        new GridAmendmentAgreementStatusAction().execute(newGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Convention__c after = [SELECT Status__c FROM Convention__c WHERE Id = :agreement.Id];
        System.assertEquals(before.Status__c, after.Status__c, 'Agreement status should not change when the submitted grid is not the most recent one in the timeline.');
    }

    @IsTest
    static void testNoUpdate_whenAgreementIsNotSigned() {
        Grid__c oldGrid = GridTestSetupHelper.createGrid(NOTSIGNED_OLD_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert oldGrid; // EndDate__c left null -> would be Change Requested if the guard didn't block it

        Grid__c newGrid = GridTestSetupHelper.createGrid(NOTSIGNED_NEW_GRID_NAME, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert newGrid;

        Convention__c agreement = linkAgreement(oldGrid, newGrid, NOTSIGNED_SUFFIX, STATUS_IN_NEGOTIATION);

        Test.startTest();
        new GridAmendmentAgreementStatusAction().execute(newGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Convention__c updated = [SELECT Status__c FROM Convention__c WHERE Id = :agreement.Id];
        System.assertEquals(STATUS_IN_NEGOTIATION, updated.Status__c, 'Agreement status should not change when the Agreement is not Signed.');
    }

    // ────────────────────────────────────── HELPERS ──────────────────────────────────────
    private static Convention__c linkAgreement(Grid__c oldGrid, Grid__c newGrid, String uniqueSuffix) {
        return linkAgreement(oldGrid, newGrid, uniqueSuffix, STATUS_SIGNED);
    }

    private static Convention__c linkAgreement(Grid__c oldGrid, Grid__c newGrid, String uniqueSuffix, String agreementStatus) {
        Account acc = GridTestSetupHelper.getTestAccounts()[0];
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);

        AgreementTriggerHandler.triggerDisabled = true;
        Convention__c agreement = GridTestSetupHelper.createAgreement(AGREEMENT_NAME_PREFIX + uniqueSuffix, AGREEMENT_CONVENTION_NAME_PREFIX + uniqueSuffix, AGREEMENT_CODE_PREFIX + uniqueSuffix, acc.Id, oldGrid.Id, COUNTRY_FR, agmRtMap);
        agreement.Status__c = agreementStatus;
        insert agreement;
        AgreementTriggerHandler.triggerDisabled = false;

        newGrid.Agreement__c = agreement.Id;
        update newGrid;

        insert GridTestSetupHelper.createAgreementGridTimeline(agreement.Id, newGrid.Id, Date.today(), null, TIMELINE_STATUS_ACTIVE);

        return agreement;
    }

    private static Grid__c createStandardGrid(String name) {
        Grid__c grid = GridTestSetupHelper.createGrid(name, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert grid;
        return grid;
    }

    private static Grid__c createCustomGrid(String name) {
        Grid__c grid = GridTestSetupHelper.createGrid(name, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        insert grid;
        return grid;
    }

    // EndDate__c is set at insert time (not via a later update) to mirror production, where the previous
    // grid's EndDate__c is already-committed data from an earlier, separate transaction (set at that grid's
    // own final approval - see GridUtility.handleApprovalTransition). Setting it via a same-transaction
    // update here previously tripped a same-transaction sharing-recalculation quirk in the "with sharing"
    // GridDetailTableController query, which doesn't reflect how this data actually arrives in production.
    private static Grid__c createEndedCustomGrid(String name) {
        Grid__c grid = GridTestSetupHelper.createGrid(name, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_CUSTOM_GRID);
        grid.EndDate__c = Date.today().addDays(-1);
        insert grid;
        return grid;
    }

    private static GridDetail__c createMasterStandardDetail(Grid__c standardGrid, Id shareClassId) {
        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(standardGrid.Id, CRITERIA_FILTER_LOGIC, CRITERIA_FILTER_LOGIC_EXPRESSION, CRITERIA_COMMENT);
        insert criteria;
        GridRule__c rule = GridTestSetupHelper.createGridRule(standardGrid.Id, criteria.Id, RULE_TO_APPLY_PERCENTAGE_OF_FEES, RULE_FEES_TYPE_EFFECTIVE_MGMT, 50, null, null, null);
        insert rule;
        GridDetail__c detail = GridTestSetupHelper.createGridDetail(standardGrid.Id, rule.Id, criteria.Id, shareClassId, 0.5, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert detail;
        return detail;
    }

    private static void addCustomDetail(Grid__c customGrid, Id shareClassId, Id standardGridDetailId) {
        insert GridTestSetupHelper.createCustomGridDetail(customGrid.Id, null, shareClassId, standardGridDetailId, Date.today());
    }
}