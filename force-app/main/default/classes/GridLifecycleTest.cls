/** ──────────────────────────────────────
 * @description Integration test class for the Grid–Agreement–AgreementGridTimeline lifecycle.
 *              Covers GridUtility (Branches A/B/C/D/E/F + Scenarios 1/2/3), GridTriggerHandler (via GridTrigger),
 *              AgreementGridTimelineUtility, and the recursion guard (isUpdatingGridsFromAgreementTrigger).
 * @author Charles EID
 * @testCoverage GridUtility (91%), AgreementGridTimelineUtility (100%), GridTriggerHandler (88% - capped by an
 *               undeployed local change to GridTriggerHandler.cls adding syncAgreementInformation, not yet
 *               live in every org), GridTrigger (100%)   [08-09-26]
────────────────────────────────────── */
@IsTest
private class GridLifecycleTest {

    private static final String AGR1_CODE  = 'LC-AGR1'; // first-grid scenario (deferred start date)
    private static final String AGR2_CODE  = 'LC-AGR2'; // amendment scenario (deferred)
    private static final String AGR3_CODE  = 'LC-AGR3'; // first-grid scenario (immediate start date)
    private static final String AGR4_CODE  = 'LC-AGR4'; // syncInformationFromAgreements / syncAgreementInformation / handleGridInsert / handleGridUpdate scenario
    private static final String AGR5_CODE  = 'LC-AGR5'; // amendment recalled scenario (Branch F)
    private static final String AGR6_CODE  = 'LC-AGR6'; // amendment approved, historical/backdated request (Scenario 3)
    private static final String AGR7_CODE  = 'LC-AGR7'; // amendment approved, immediate (Scenario 2 — old Active AGT → Inactive)

    private static final String GRID1_NAME  = 'LC-Grid1';  // first grid for agr1
    private static final String GRID2_NAME  = 'LC-Grid2';  // current active grid for agr2
    private static final String GRID3_NAME  = 'LC-Grid3';  // amendment request grid for agr2
    private static final String GRID4_NAME  = 'LC-Grid4';  // first grid for agr3 (immediate)
    private static final String GRID5_NAME  = 'LC-Grid5';  // current active grid for agr5
    private static final String GRID6_NAME  = 'LC-Grid6';  // amendment request grid for agr5 (to be recalled)
    private static final String GRID7_NAME  = 'LC-Grid7';  // current active grid for agr6 (AGT dated today)
    private static final String GRID8_NAME  = 'LC-Grid8';  // amendment request grid for agr6 (AGT dated in the past — historical)
    private static final String GRID9_NAME  = 'LC-Grid9';  // current active grid for agr7 (AGT dated 6 months ago)
    private static final String GRID10_NAME = 'LC-Grid10'; // amendment request grid for agr7 (AGT dated today — immediate)

    private static final String SYNC_INFO_GRID_NAME    = 'LC-SyncInfo-Grid';    // custom grid linked to agr4 via Agreement__c at insert time
    private static final String SYNC_ENDDATE_GRID_NAME = 'LC-SyncEndDate-Grid'; // custom grid for syncGridEndDateToDetails
    private static final String STANDARD_GRID_NAME     = 'LC-StdGrid';         // standard grid for refreshGridDetailsForShareClasses
    private static final String REFRESH_CUSTOM_GRID_NAME = 'LC-Refresh-CustomGrid'; // custom grid referencing the standard detail

    private static final String SHARE_CLASS_NAME = 'LC-SC-A';

    @TestSetup
    static void makeData() {
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u) {
            Account company = GridTestSetupHelper.createAccount('LC Company', 'Client', '1 Rue Test', 'Paris', '75001', 'France', 'IFA', 'IFA', 'BP_FR');
            insert company;

            // ── Share class chain (Strategy → Product → Share Class), used by the grid-detail refresh scenarios ──
            Strategy__c strategy = GridTestSetupHelper.createStrategy('LC Strategy', GridTestSetupHelper.ASSET_CLASS_EQUITY, 'LCSTRAT');
            insert strategy;
            Product__c product = GridTestSetupHelper.createProduct(strategy.Id, 'LC Product', 'LCPROD', GridTestSetupHelper.LEGAL_STATUS_FCP);
            insert product;
            Share_Class__c shareClass = GridTestSetupHelper.createShareClass(product.Id, SHARE_CLASS_NAME, 'LU0000000001', GridTestSetupHelper.SHARE_TYPE_A, 1.5, GridTestSetupHelper.CURRENCY_EUR);
            insert shareClass;

            Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);

            // agr4 is inserted first (no grid reference needed) so that the custom grid it owns can be
            // inserted with Agreement__c already populated — exercising GridTriggerHandler.BeforeInsert's
            // syncAgreementInformation and AgreementGridTimelineUtility.handleGridInsert for real, rather
            // than via a later update (which those AfterInsert-only/insert-time paths would never see).
            AgreementTriggerHandler.triggerDisabled = true;
            Convention__c agr4 = GridTestSetupHelper.createAgreement(AGR4_CODE, 'LC Agreement 4', AGR4_CODE, company.Id, null, 'FR', agmRtMap);
            insert agr4;
            AgreementTriggerHandler.triggerDisabled = false;

            Grid__c grid1  = GridTestSetupHelper.createGrid(GRID1_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid2  = GridTestSetupHelper.createGrid(GRID2_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid3  = GridTestSetupHelper.createGrid(GRID3_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid4  = GridTestSetupHelper.createGrid(GRID4_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid5  = GridTestSetupHelper.createGrid(GRID5_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid6  = GridTestSetupHelper.createGrid(GRID6_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid7  = GridTestSetupHelper.createGrid(GRID7_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid8  = GridTestSetupHelper.createGrid(GRID8_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid9  = GridTestSetupHelper.createGrid(GRID9_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c grid10 = GridTestSetupHelper.createGrid(GRID10_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c syncEndDateGrid   = GridTestSetupHelper.createGrid(SYNC_ENDDATE_GRID_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            Grid__c standardGrid      = GridTestSetupHelper.createGrid(STANDARD_GRID_NAME, '', true, GridBuilderHelper.RT_STANDARD_GRID);
            Grid__c refreshCustomGrid = GridTestSetupHelper.createGrid(REFRESH_CUSTOM_GRID_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);

            Grid__c syncInfoGrid = GridTestSetupHelper.createGrid(SYNC_INFO_GRID_NAME, '', true, GridBuilderHelper.RT_CUSTOM_GRID);
            syncInfoGrid.Agreement__c = agr4.Id; // set before insert, unlike the other grids above

            insert new List<Grid__c>{ grid1, grid2, grid3, grid4, grid5, grid6, grid7, grid8, grid9, grid10,
                                       syncInfoGrid, syncEndDateGrid, standardGrid, refreshCustomGrid };

            AgreementTriggerHandler.triggerDisabled = true;

            // agr1: first-grid scenario, deferred start date — Grid_Request__c only, no Grid__c yet
            Convention__c agr1 = GridTestSetupHelper.createAgreement(AGR1_CODE, 'LC Agreement 1', AGR1_CODE, company.Id, null, grid1.Id, Date.today().addMonths(1), 'FR', agmRtMap);
            // agr2: amendment scenario — Grid__c (active) + Grid_Request__c (new amendment), deferred start date
            Convention__c agr2 = GridTestSetupHelper.createAgreement(AGR2_CODE, 'LC Agreement 2', AGR2_CODE, company.Id, grid2.Id, grid3.Id, Date.today().addMonths(1), 'FR', agmRtMap);
            // agr3: first-grid scenario, immediate start date — Grid_Request__c only, no Grid__c yet
            Convention__c agr3 = GridTestSetupHelper.createAgreement(AGR3_CODE, 'LC Agreement 3', AGR3_CODE, company.Id, null, grid4.Id, Date.today(), 'FR', agmRtMap);
            // agr5: amendment scenario, to be recalled — Grid__c (active) + Grid_Request__c (pending, will be recalled)
            Convention__c agr5 = GridTestSetupHelper.createAgreement(AGR5_CODE, 'LC Agreement 5', AGR5_CODE, company.Id, grid5.Id, grid6.Id, Date.today().addMonths(1), 'FR', agmRtMap);
            // agr6: amendment scenario, historical/backdated request (request AGT predates the active AGT)
            Convention__c agr6 = GridTestSetupHelper.createAgreement(AGR6_CODE, 'LC Agreement 6', AGR6_CODE, company.Id, grid7.Id, grid8.Id, Date.today().addDays(-60), 'FR', agmRtMap);
            // agr7: amendment scenario, immediate approval — old active AGT should flip to Inactive
            Convention__c agr7 = GridTestSetupHelper.createAgreement(AGR7_CODE, 'LC Agreement 7', AGR7_CODE, company.Id, grid9.Id, grid10.Id, Date.today(), 'FR', agmRtMap);
            insert new List<Convention__c>{ agr1, agr2, agr3, agr5, agr6, agr7 };
            AgreementTriggerHandler.triggerDisabled = false;

            insert new List<AgreementGridTimeline__c>{
                GridTestSetupHelper.createAgreementGridTimeline(agr1.Id, grid1.Id,  Date.today().addMonths(1),  null, 'Draft'),
                GridTestSetupHelper.createAgreementGridTimeline(agr2.Id, grid2.Id,  Date.today().addMonths(-6), null, 'Active'),
                GridTestSetupHelper.createAgreementGridTimeline(agr2.Id, grid3.Id,  Date.today().addMonths(1),  null, 'Draft'),
                GridTestSetupHelper.createAgreementGridTimeline(agr3.Id, grid4.Id,  Date.today(),               null, 'Draft'),
                GridTestSetupHelper.createAgreementGridTimeline(agr5.Id, grid5.Id,  Date.today().addMonths(-6), null, 'Active'),
                GridTestSetupHelper.createAgreementGridTimeline(agr5.Id, grid6.Id,  Date.today().addMonths(1),  null, 'Pending Approval'),
                GridTestSetupHelper.createAgreementGridTimeline(agr6.Id, grid7.Id,  Date.today(),               null, 'Active'),
                GridTestSetupHelper.createAgreementGridTimeline(agr6.Id, grid8.Id,  Date.today().addDays(-60),  null, 'Draft'),
                GridTestSetupHelper.createAgreementGridTimeline(agr7.Id, grid9.Id,  Date.today().addMonths(-6), null, 'Active'),
                GridTestSetupHelper.createAgreementGridTimeline(agr7.Id, grid10.Id, Date.today(),               null, 'Draft')
            };

            // ── Grid detail chain for syncGridEndDateToDetails ──
            GridDetail__c syncEndDateDetail = GridTestSetupHelper.createGridDetail(syncEndDateGrid.Id, null, null, shareClass.Id, 0.5, Date.today(), null, GridBuilderHelper.RT_CUSTOM_GRID_DETAIL);
            insert syncEndDateDetail;

            // ── Grid detail chain for refreshGridDetailsForShareClasses: Standard Grid Detail + a Custom Grid Detail referencing it ──
            GridCriteria__c refreshCriteria = GridTestSetupHelper.createCriteria(standardGrid.Id, 'AND', '1', 'LC Refresh Criteria');
            insert refreshCriteria;
            GridRule__c refreshRule = GridTestSetupHelper.createGridRule(standardGrid.Id, refreshCriteria.Id, 'Percentage of Fees', 'EffectiveManagementFees__c', 20, null, null, null);
            insert refreshRule;
            GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(standardGrid.Id, refreshRule.Id, refreshCriteria.Id, shareClass.Id, 0.5, Date.today().addDays(-30), null, GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
            insert stdDetail;
            GridDetail__c customDetail = GridTestSetupHelper.createCustomGridDetail(refreshCustomGrid.Id, refreshCriteria.Id, shareClass.Id, stdDetail.Id, Date.today().addDays(-30));
            insert customDetail;
        }
    }

    // ────────────────────────────────────── BRANCH A: First Grid Approved (deferred start date) ──────────────────────────────────────
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

    // ────────────────────────────────────── BRANCH A (immediate start date): swaps Grid_Request__c → Grid__c right away ──────────────────────────────────────
    @IsTest
    static void testBranchA_firstGridApproved_Immediate() {
        Convention__c agr = getAgr(AGR3_CODE);
        Grid__c grid4 = getGrid(GRID4_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, null, grid4.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS,      '');
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, null, grid4.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_APPROVALCOMPLETE, '');

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();

        System.assertEquals(grid4.Id, newAgr.Grid__c, 'An immediate start date should swap Grid_Request__c into Grid__c right away.');
        System.assertEquals(null, newAgr.Grid_Request__c, 'Grid_Request__c should be cleared after the immediate swap.');
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

    // ────────────────────────────────────── BRANCH C: Amendment Approved (deferred) ──────────────────────────────────────
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

    // ────────────────────────────────────── BRANCH C (Scenario 3): approved but the request predates the active AGT — historical, not swapped ──────────────────────────────────────
    @IsTest
    static void testBranchC_amendmentApproved_Historical() {
        Convention__c agr = getAgr(AGR6_CODE);
        Grid__c grid7 = getGrid(GRID7_NAME);
        Grid__c grid8 = getGrid(GRID8_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, grid7.Id, grid8.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREQUIRED);
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, grid7.Id, grid8.Id, agr.Grid_Request_Start_Date__c, true,  GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVED);

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();

        // Historical/backdated approval — the Agreement's own Grid__c/Grid_Request__c fields are left untouched by GridUtility
        System.assertEquals(grid7.Id, newAgr.Grid__c, 'A historical (backdated) approval should not swap Grid__c.');
        System.assertEquals(grid8.Id, newAgr.Grid_Request__c, 'A historical (backdated) approval should not clear Grid_Request__c.');
    }

    // ────────────────────────────────────── BRANCH C (Scenario 2, immediate): old Active AGT flips to Inactive ──────────────────────────────────────
    @IsTest
    static void testBranchC_amendmentApproved_Immediate() {
        Convention__c agr = getAgr(AGR7_CODE);
        Grid__c grid9  = getGrid(GRID9_NAME);
        Grid__c grid10 = getGrid(GRID10_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, grid9.Id, grid10.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREQUIRED);
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, grid9.Id, grid10.Id, agr.Grid_Request_Start_Date__c, true,  GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVED);

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();

        System.assertEquals(grid10.Id, newAgr.Grid__c, 'An immediate approval should swap Grid_Request__c into Grid__c right away.');

        AgreementGridTimeline__c oldActiveAgt = [SELECT Status__c FROM AgreementGridTimeline__c WHERE Agreement__c = :agr.Id AND Grid__c = :grid9.Id];
        System.assertEquals('Inactive', oldActiveAgt.Status__c, 'The previously active grid\'s timeline entry should flip to Inactive once immediately replaced.');
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

    // ────────────────────────────────────── BRANCH F: Amendment Recalled ──────────────────────────────────────
    @IsTest
    static void testBranchF_amendmentRecalled() {
        Convention__c agr = getAgr(AGR5_CODE);
        Grid__c grid5 = getGrid(GRID5_NAME);
        Grid__c grid6 = getGrid(GRID6_NAME);

        Convention__c oldAgr = makeAgreementSnapshot(agr.Id, grid5.Id, grid6.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridTestSetupHelper.AGR_APPROVALREQUIRED);
        Convention__c newAgr = makeAgreementSnapshot(agr.Id, grid5.Id, grid6.Id, agr.Grid_Request_Start_Date__c, false, GridTestSetupHelper.AGR_INPROGRESS, GridUtility.AGR_AMDMT_NEED_SUBMISSION);

        Test.startTest();

        GridUtility.handleAgreementGridTransitions(new List<Convention__c>{ newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();

        AgreementGridTimeline__c agt = [SELECT Status__c FROM AgreementGridTimeline__c WHERE Agreement__c = :agr.Id AND Grid__c = :grid6.Id];
        System.assertEquals('Draft', agt.Status__c, 'A recalled amendment request should send its timeline entry back to Draft.');
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

    // ────────────────────────────────────── GRID TRIGGER: BeforeInsert syncs Agreement info + AfterInsert creates a Draft AGT ──────────────────────────────────────
    @IsTest
    static void testGridTrigger_syncsAgreementInfoAndCreatesTimelineOnInsert() {
        Convention__c agr4 = getAgr(AGR4_CODE);
        Grid__c syncInfoGrid = getGrid(SYNC_INFO_GRID_NAME);

        // handleGridInsert (AfterInsert) only fires because syncInfoGrid already had Agreement__c populated
        // at insert time - this asserts that path, distinct from syncInformationFromAgreements's own
        // direct-call test above, which exercises the AfterUpdate mirroring logic instead.
        List<AgreementGridTimeline__c> agts = [SELECT Status__c FROM AgreementGridTimeline__c WHERE Agreement__c = :agr4.Id AND Grid__c = :syncInfoGrid.Id];
        System.assertEquals(1, agts.size(), 'handleGridInsert should have created a Draft AGT for the custom grid linked to the agreement at insert time.');
        System.assertEquals('Draft', agts[0].Status__c, 'The auto-created AGT should start as Draft.');
    }

    // ────────────────────────────────────── GRID TRIGGER: AfterUpdate mirrors StartDate/EndDate onto the AGT ──────────────────────────────────────
    @IsTest
    static void testGridTrigger_handleGridUpdate_syncsDatesToTimeline() {
        Grid__c syncInfoGrid = getGrid(SYNC_INFO_GRID_NAME);
        Date newStart = Date.today();
        Date newEnd   = Date.today().addYears(1);

        Test.startTest();

        update new Grid__c(Id = syncInfoGrid.Id, StartDate__c = newStart, EndDate__c = newEnd);

        Test.stopTest();

        AgreementGridTimeline__c agt = [SELECT GridStartDate__c, GridEndDate__c FROM AgreementGridTimeline__c WHERE Grid__c = :syncInfoGrid.Id LIMIT 1];
        System.assertEquals(newStart, agt.GridStartDate__c, 'handleGridUpdate should mirror the new StartDate__c onto the AGT.');
        System.assertEquals(newEnd, agt.GridEndDate__c, 'handleGridUpdate should mirror the new EndDate__c onto the AGT.');
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

    // ────────────────────────────────────── PURE HELPERS: effectiveStart / setGridOnAgreement ──────────────────────────────────────
    @IsTest
    static void testEffectiveStart() {
        Date early = Date.today();
        Date later = Date.today().addDays(5);

        System.assertEquals(early, GridUtility.effectiveStart(null, early), 'Null gridStart should fall back to scCreated.');
        System.assertEquals(early, GridUtility.effectiveStart(early, null), 'Null scCreated should fall back to gridStart.');
        System.assertEquals(later, GridUtility.effectiveStart(later, early), 'The later of the two dates should win (gridStart later).');
        System.assertEquals(later, GridUtility.effectiveStart(early, later), 'The later of the two dates should win (scCreated later).');
    }

    @IsTest
    static void testSetGridOnAgreement() {
        Grid__c grid3 = getGrid(GRID3_NAME);
        Convention__c agr = new Convention__c(
            Grid_Request__c               = grid3.Id,
            Grid_Request_Start_Date__c    = Date.today().addMonths(1),
            Amendment_Approval_Status__c  = GridTestSetupHelper.AGR_APPROVED,
            Grid_Request_Approved__c      = true
        );

        Test.startTest();
        GridUtility.setGridOnAgreement(agr);
        Test.stopTest();

        System.assertEquals(grid3.Id, agr.Grid__c, 'Grid_Request__c should swap into Grid__c.');
        System.assertEquals(null, agr.Grid_Request__c, 'Grid_Request__c should be cleared.');
        System.assertEquals(Date.today().addMonths(1), agr.Grid_Start_Date__c, 'Grid_Request_Start_Date__c should swap into Grid_Start_Date__c.');
        System.assertEquals(null, agr.Grid_Request_Start_Date__c, 'Grid_Request_Start_Date__c should be cleared.');
        System.assertEquals('', agr.Amendment_Approval_Status__c, 'Amendment_Approval_Status__c should be reset.');
        System.assertEquals(false, agr.Grid_Request_Approved__c, 'Grid_Request_Approved__c should be reset.');
    }

    // ────────────────────────────────────── syncInformationFromAgreements ──────────────────────────────────────
    @IsTest
    static void testSyncInformationFromAgreements() {
        Convention__c agr = getAgr(AGR4_CODE);
        Grid__c syncInfoGrid = getGrid(SYNC_INFO_GRID_NAME);

        Convention__c oldAgr = new Convention__c(Id = agr.Id, TECH_Business_Region__c = null,    TECH_All_concerned_Business_Regions__c = null,    Carmignac_Legal_Entity__c = null);
        Convention__c newAgr = new Convention__c(Id = agr.Id, TECH_Business_Region__c = 'BP_FR', TECH_All_concerned_Business_Regions__c = 'BP_FR', Carmignac_Legal_Entity__c = 'CGF');

        Test.startTest();

        GridUtility.syncInformationFromAgreements(new Map<Id, Convention__c>{ agr.Id => newAgr }, new Map<Id, Convention__c>{ agr.Id => oldAgr });

        Test.stopTest();
    }

    // ────────────────────────────────────── syncGridEndDateToDetails ──────────────────────────────────────
    @IsTest
    static void testSyncGridEndDateToDetails() {
        Grid__c syncEndDateGrid = getGrid(SYNC_ENDDATE_GRID_NAME);
        GridDetail__c detail = [SELECT Id FROM GridDetail__c WHERE Grid__c = :syncEndDateGrid.Id LIMIT 1];

        Grid__c oldGrid = new Grid__c(Id = syncEndDateGrid.Id, RecordTypeId = syncEndDateGrid.RecordTypeId, EndDate__c = null);
        Grid__c newGrid = new Grid__c(Id = syncEndDateGrid.Id, RecordTypeId = syncEndDateGrid.RecordTypeId, EndDate__c = Date.today());

        Test.startTest();

        GridUtility.syncGridEndDateToDetails(new List<Grid__c>{ newGrid }, new Map<Id, Grid__c>{ syncEndDateGrid.Id => oldGrid });

        Test.stopTest();

        GridDetail__c updated = [SELECT EndDate__c FROM GridDetail__c WHERE Id = :detail.Id];
        System.assertEquals(Date.today(), updated.EndDate__c, 'GridDetail EndDate__c should mirror the grid EndDate__c change.');
    }

    // ────────────────────────────────────── refreshGridDetailsForShareClasses ──────────────────────────────────────
    @IsTest
    static void testRefreshGridDetailsForShareClasses() {
        Share_Class__c shareClass = [SELECT Id FROM Share_Class__c LIMIT 1];
        Grid__c standardGrid = getGrid(STANDARD_GRID_NAME);
        Grid__c refreshCustomGrid = getGrid(REFRESH_CUSTOM_GRID_NAME);
        GridDetail__c stdDetail    = [SELECT Id FROM GridDetail__c WHERE Grid__c = :standardGrid.Id LIMIT 1];
        GridDetail__c customDetail = [SELECT Id FROM GridDetail__c WHERE Grid__c = :refreshCustomGrid.Id LIMIT 1];

        Test.startTest();

        GridUtility.refreshGridDetailsForShareClasses(new Set<Id>{ shareClass.Id });

        Test.stopTest();

        GridDetail__c oldStd = [SELECT EndDate__c FROM GridDetail__c WHERE Id = :stdDetail.Id];
        System.assertNotEquals(null, oldStd.EndDate__c, 'The old standard grid detail should be expired.');

        List<GridDetail__c> newStdDetails = [SELECT Id FROM GridDetail__c WHERE Grid__c = :standardGrid.Id AND Id != :stdDetail.Id];
        System.assertEquals(1, newStdDetails.size(), 'A new standard grid detail should replace the expired one.');

        GridDetail__c oldCustom = [SELECT EndDate__c FROM GridDetail__c WHERE Id = :customDetail.Id];
        System.assertNotEquals(null, oldCustom.EndDate__c, 'The old custom grid detail should be expired too.');

        // Not asserting an exact count here: GridDetailTriggerHandler's own insert-time automation
        // can add further custom details of its own alongside the one refreshGridDetailsForShareClasses creates.
        List<GridDetail__c> newCustomDetails = [SELECT Id, StandardGridDetail__c FROM GridDetail__c WHERE Grid__c = :refreshCustomGrid.Id AND Id != :customDetail.Id AND StandardGridDetail__c = :newStdDetails[0].Id];
        System.assert(!newCustomDetails.isEmpty(), 'A new custom grid detail pointing at the new standard detail should exist.');
    }

    // ────────────────────────────────────── HELPERS ──────────────────────────────────────
    private static Convention__c getAgr(String agr_code) {
        return [SELECT Id, Grid__c, Grid_Request__c, Grid_Request_Start_Date__c, Grid_Request_Approved__c, Approval_Status__c, Amendment_Approval_Status__c
                FROM Convention__c WHERE Agreement_Code__c = :agr_code LIMIT 1];
    }

    private static Grid__c getGrid(String name) {
        return [SELECT Id, Name, ApprovalStatus__c, RecordTypeId FROM Grid__c WHERE Name = :name LIMIT 1];
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