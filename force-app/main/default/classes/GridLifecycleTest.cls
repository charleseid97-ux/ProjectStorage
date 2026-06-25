/** ──────────────────────────────────────
 * @description Integration test class for the Grid–Agreement–AgreementGridTimeline lifecycle.
 *              Covers GridUtility (Branches A/B/C/D), GridTriggerHandler (via GridTrigger),
 *              and the recursion guard (isUpdatingGridsFromAgreementTrigger).
 * @author Charles EID
 * @testCoverage GridUtility (100%), AgreementGridTimelineUtility (100%), GridTriggerHandler (90%), GridTrigger (100%)   [19-03-26]
────────────────────────────────────── */
@IsTest
private class GridLifecycleTest {

    private static final String AGR1_CODE  = 'LC-AGR1'; // first-grid scenario
    private static final String AGR2_CODE  = 'LC-AGR2'; // amendment scenario
    private static final String GRID1_NAME = 'LC-Grid1'; // first grid for agr1
    private static final String GRID2_NAME = 'LC-Grid2'; // current active grid for agr2
    private static final String GRID3_NAME = 'LC-Grid3'; // amendment request grid for agr2

    @TestSetup
    static void makeData() {
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u) {
            Account company = GridTestSetupHelper.createAccount('LC Company', 'Client', '1 Rue Test', 'Paris', '75001', 'France', 'IFA', 'IFA', 'BP_FR');
            insert company;

            Grid__c grid1 = GridTestSetupHelper.createGrid(GRID1_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid2 = GridTestSetupHelper.createGrid(GRID2_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid3 = GridTestSetupHelper.createGrid(GRID3_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            insert new List<Grid__c>{ grid1, grid2, grid3 };

            Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
            AgreementTriggerHandler.triggerDisabled = true;

            // agr1: first-grid scenario — Grid_Request__c only, no Grid__c yet
            Convention__c agr1 = GridTestSetupHelper.createAgreement(AGR1_CODE, 'LC Agreement 1', AGR1_CODE, company.Id, null, grid1.Id, Date.today().addMonths(1), 'FR', agmRtMap);
            // agr2: amendment scenario — Grid__c (active) + Grid_Request__c (new amendment)
            Convention__c agr2 = GridTestSetupHelper.createAgreement(AGR2_CODE, 'LC Agreement 2', AGR2_CODE, company.Id, grid2.Id, grid3.Id, Date.today().addMonths(1), 'FR', agmRtMap);
            insert new List<Convention__c>{ agr1, agr2 };
            AgreementTriggerHandler.triggerDisabled = false;

            insert new List<AgreementGridTimeline__c>{
                GridTestSetupHelper.createAgreementGridTimeline(agr1.Id, grid1.Id, Date.today().addMonths(1),  null, 'Draft'),
                GridTestSetupHelper.createAgreementGridTimeline(agr2.Id, grid2.Id, Date.today().addMonths(-6), null, 'Active'),
                GridTestSetupHelper.createAgreementGridTimeline(agr2.Id, grid3.Id, Date.today().addMonths(1),  null, 'Draft')
            };
        }
    }

    // ────────────────────────────────────── BRANCH A: First Grid Approved ──────────────────────────────────────
    @IsTest
    static void testBranchA_firstGridApproved() {
        Convention__c agr = getAgr(AGR1_CODE);
        Grid__c grid1 = getGrid(GRID1_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, null,     grid1.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS,      '');
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, null,     grid1.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_APPROVALCOMPLETE, '');

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();
    }

    // ────────────────────────────────────── BRANCH B: Amendment Submitted ──────────────────────────────────────
    @IsTest
    static void testBranchB_amendmentSubmitted() {
        Convention__c agr = getAgr(AGR2_CODE);
        Grid__c grid3 = getGrid(GRID3_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, agr.Grid__c, grid3.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, '');
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, agr.Grid__c, grid3.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREQUIRED);

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();
    }

    // ────────────────────────────────────── BRANCH C: Amendment Approved ──────────────────────────────────────
    @IsTest
    static void testBranchC_amendmentApproved() {
        Convention__c agr = getAgr(AGR2_CODE);
        Grid__c grid2 = getGrid(GRID2_NAME);
        Grid__c grid3 = getGrid(GRID3_NAME);

        AgreementGridTimeline__c agt2b = [SELECT Id FROM AgreementGridTimeline__c WHERE Agreement__c = :agr.Id AND Grid__c = :grid3.Id];
        agt2b.Status__c = GridTestSetupHelper.AGR_PENDINGAPPROVAL;
        update agt2b;

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, grid2.Id, grid3.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREQUIRED);
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, grid2.Id, grid3.Id, agr.Grid_Request_Start_Date__c, true,  GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVED);

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();
    }

    // ────────────────────────────────────── BRANCH D: Amendment Rejected ──────────────────────────────────────
    @IsTest
    static void testBranchD_amendmentRejected() {
        Convention__c agr = getAgr(AGR2_CODE);
        Grid__c grid3 = getGrid(GRID3_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, agr.Grid__c, grid3.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREQUIRED);
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, agr.Grid__c, grid3.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREJECTED);

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();
    }

    // ────────────────────────────────────── GRID TRIGGER: Pending Approval ──────────────────────────────────────
    @IsTest
    static void testGridTrigger_pendingApproval() {
        Grid__c grid1 = getGrid(GRID1_NAME);

        Test.startTest();

        update new Grid__c(Id = grid1.Id, ApprovalStatus__c = GridTestSetupHelper.AGR_PENDINGAPPROVAL);

        Test.stopTest();
    }

    // ────────────────────────────────────── GRID TRIGGER: Approved ──────────────────────────────────────
    @IsTest
    static void testGridTrigger_approved() {
        Convention__c agr2 = getAgr(AGR2_CODE);
        Grid__c grid2 = getGrid(GRID2_NAME);
        Grid__c grid3 = getGrid(GRID3_NAME);

        AgreementGridTimeline__c agt2b = [SELECT Id FROM AgreementGridTimeline__c WHERE Agreement__c = :agr2.Id AND Grid__c = :grid3.Id];
        agt2b.Status__c = GridTestSetupHelper.AGR_PENDINGAPPROVAL;
        update agt2b;

        Test.startTest();

        update new Grid__c(Id = grid3.Id, ApprovalStatus__c = GridTestSetupHelper.AGR_APPROVED);

        Test.stopTest();
    }

    // ────────────────────────────────────── GRID TRIGGER: Rejected ──────────────────────────────────────
    @IsTest
    static void testGridTrigger_rejected() {
        Convention__c agr2 = getAgr(AGR2_CODE);
        Grid__c grid3 = getGrid(GRID3_NAME);

        Test.startTest();

        update new Grid__c(Id = grid3.Id, ApprovalStatus__c = 'Rejected');

        Test.stopTest();
    }

    // ────────────────────────────────────── GUARD: Prevents recursion ──────────────────────────────────────
    @IsTest
    static void testGuard_preventsRecursion() {
        Convention__c agr1Before = getAgr(AGR1_CODE);
        Grid__c grid1 = getGrid(GRID1_NAME);

        Test.startTest();

        GridUtility.isUpdatingGridsFromAgreementTrigger = true;
        update new Grid__c(Id = grid1.Id, ApprovalStatus__c = GridTestSetupHelper.AGR_PENDINGAPPROVAL);
        GridUtility.isUpdatingGridsFromAgreementTrigger = false;

        Test.stopTest();
    }

    // ────────────────────────────────────── HELPERS ──────────────────────────────────────
    private static Convention__c getAgr(String agr_code) {
        return [SELECT Id, Grid__c, Grid_Request__c, Grid_Request_Start_Date__c, Grid_Request_Approved__c, Approval_Status__c, Amendment_Approval_Status__c
                FROM Convention__c WHERE Agreement_Code__c = :agr_code LIMIT 1];
    }

    private static Grid__c getGrid(String name) {
        return [SELECT Id, Name, ApprovalStatus__c FROM Grid__c WHERE Name = :name LIMIT 1];
    }

    private static Convention__c makeAgreementSnapshot(Id agrId, Id gridId, Id gridRequestId, Date gridRequestStartDate, Boolean gridRequestApproved, String approvalStatus, String amendmentApprovalStatus) {
        return new Convention__c(
            Id                          = agrId,
            Grid__c                     = gridId,
            Grid_Request__c             = gridRequestId,
            Grid_Request_Start_Date__c  = gridRequestStartDate,
            Grid_Request_Approved__c    = gridRequestApproved,
            Approval_Status__c          = approvalStatus,
            Amendment_Approval_Status__c = amendmentApprovalStatus
        );
    }
}