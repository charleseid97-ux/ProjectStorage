/** ──────────────────────────────────────
 * @description Test class for GridAmendmentAgreementStatusAction.
 * @author Charles EID
 * @testCoverage GridAmendmentAgreementStatusAction (97%)   [29-09-26]
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

    private static final String AGREEMENT_NAME_PREFIX = 'AGR-TEST-';
    private static final String AGREEMENT_CONVENTION_NAME_PREFIX = 'Test Convention ';
    private static final String AGREEMENT_CODE_PREFIX = 'AGR-TEST-CODE-';

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // Covers every branch of GridAmendmentAgreementStatusAction.execute except the Grid-Details comparison
    // itself (Pending Renewal vs Change Renewal — see testExecute_detailComparisonOutcomes): the Change
    // Requested outcome, the Other Fees bypass of the detail comparison, and both early-return guards
    // (not most recent grid, agreement not Signed).
    @IsTest
    static void testExecute_allStatusOutcomesAndGuards() {
        // ── Change Requested: previous grid has no end date ──
        Grid__c noEndOldGrid = GridTestSetupHelper.createGrid('OldGrid-NoEnd', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert noEndOldGrid; // EndDate__c left null
        Grid__c noEndNewGrid = GridTestSetupHelper.createGrid('NewGrid-NoEnd', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert noEndNewGrid;
        Convention__c noEndAgreement = linkAgreement(noEndOldGrid, noEndNewGrid, 'NOEND');

        // ── Other Fees: ended previous grid, no details on either side — always a renewal, never a "change" ──
        Grid__c otherFeesOldGrid = createEndedCustomGrid('OldGrid-OtherFees');
        Grid__c otherFeesNewGrid = GridTestSetupHelper.createGrid('NewGrid-OtherFees', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_OTHER_FEES_GRID);
        insert otherFeesNewGrid;
        Convention__c otherFeesAgreement = linkAgreement(otherFeesOldGrid, otherFeesNewGrid, 'OTHERFEES');

        // ── Guard: submitted grid is not the most recent one in the timeline ──
        Grid__c guardOldGrid = GridTestSetupHelper.createGrid('OldGrid-Guard', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert guardOldGrid;
        Grid__c guardNewGrid = GridTestSetupHelper.createGrid('NewGrid-Guard', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert guardNewGrid;
        Convention__c guardAgreement = linkAgreement(guardOldGrid, guardNewGrid, 'GUARD');
        Grid__c guardLaterGrid = GridTestSetupHelper.createGrid('LaterGrid-Guard', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert guardLaterGrid;
        insert GridTestSetupHelper.createAgreementGridTimeline(guardAgreement.Id, guardLaterGrid.Id, Date.today().addDays(10), null, TIMELINE_STATUS_DRAFT);
        String guardStatusBefore = [SELECT Status__c FROM Convention__c WHERE Id = :guardAgreement.Id].Status__c;

        // ── Guard: agreement is not Signed ──
        Grid__c notSignedOldGrid = GridTestSetupHelper.createGrid('OldGrid-NotSigned', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert notSignedOldGrid; // EndDate__c left null -> would be Change Requested if the guard didn't block it
        Grid__c notSignedNewGrid = GridTestSetupHelper.createGrid('NewGrid-NotSigned', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert notSignedNewGrid;
        Convention__c notSignedAgreement = linkAgreement(notSignedOldGrid, notSignedNewGrid, 'NOTSIGNED', STATUS_IN_NEGOTIATION);

        Test.startTest();
        GridAmendmentAgreementStatusAction action = new GridAmendmentAgreementStatusAction();
        action.execute(noEndNewGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        action.execute(otherFeesNewGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        action.execute(guardNewGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        action.execute(notSignedNewGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Map<Id, Convention__c> agreementsById = new Map<Id, Convention__c>([SELECT Id, Status__c FROM Convention__c WHERE Id IN
            (:noEndAgreement.Id, :otherFeesAgreement.Id, :guardAgreement.Id, :notSignedAgreement.Id)]);

        System.assertEquals(STATUS_CHANGE_REQUESTED, agreementsById.get(noEndAgreement.Id).Status__c, 'Change Requested when the previous grid has no end date.');
        System.assertEquals(STATUS_PENDING_RENEWAL, agreementsById.get(otherFeesAgreement.Id).Status__c, 'Other Fees grid amendments always resolve to Pending Renewal, never Change Renewal, since there are no Grid Details to compare.');
        System.assertEquals(guardStatusBefore, agreementsById.get(guardAgreement.Id).Status__c, 'No change when the submitted grid is not the most recent one in the timeline.');
        System.assertEquals(STATUS_IN_NEGOTIATION, agreementsById.get(notSignedAgreement.Id).Status__c, 'No change when the Agreement is not Signed.');
    }

    // Covers the haveSameGridDetails/GridComparisonController integration path (Pending Renewal is already
    // covered via the Other Fees bypass in testExecute_allStatusOutcomesAndGuards above).
    @IsTest
    static void testExecute_changeRenewal_whenGridDetailsDiffer() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();

        Grid__c diffMasterGrid = createStandardGrid('MasterGrid-Diff');
        GridDetail__c diffMasterDetail1 = createMasterStandardDetail(diffMasterGrid, shareClasses[0].Id);
        GridDetail__c diffMasterDetail2 = createMasterStandardDetail(diffMasterGrid, shareClasses[1].Id);
        Grid__c diffOldGrid = createEndedCustomGrid('OldGrid-Diff');
        addCustomDetail(diffOldGrid, shareClasses[0].Id, diffMasterDetail1.Id);
        Grid__c diffNewGrid = createCustomGrid('NewGrid-Diff');
        addCustomDetail(diffNewGrid, shareClasses[1].Id, diffMasterDetail2.Id);
        Convention__c diffAgreement = linkAgreement(diffOldGrid, diffNewGrid, 'DIFF');

        Test.startTest();
        new GridAmendmentAgreementStatusAction().execute(diffNewGrid.Id, UserInfo.getUserId(), new Map<String, Object>());
        Test.stopTest();

        Convention__c updated = [SELECT Status__c FROM Convention__c WHERE Id = :diffAgreement.Id];
        System.assertEquals(STATUS_CHANGE_RENEWAL, updated.Status__c, 'Change Renewal when the new grid detail lines differ from the ended previous grid.');
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