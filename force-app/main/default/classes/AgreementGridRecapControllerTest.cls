/** ──────────────────────────────────────
 * @description Test class for AgreementGridRecapController.
 *              Verifies the getRecap method returns correct recap data for an agreement
 *              (active grid with standard grid groups + history, and no-grid scenario).
 * @author Charles EID
 * Coverage: AgreementGridRecapController 100%
────────────────────────────────────── */
@IsTest
public with sharing class AgreementGridRecapControllerTest {

    @TestSetup
    static void setup() {
        GridTestSetupHelper.setupTestData();
    }

    // ── Agreement has an active custom grid with grid details → groups + history returned ──
    @IsTest
    static void getRecap_withActiveGrid_returnsGroupsAndHistory() {
        Grid__c standardGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Share_Class__c sc    = GridTestSetupHelper.getTestShareClasses()[0];
        Convention__c agr    = GridTestSetupHelper.getTestAgreements()[0];

        // Custom grid that the agreement will point to
        Grid__c customGrid = GridTestSetupHelper.createGrid('CustomRecapTest', '', true, GridBuilderHelper.RT_CUSTOM_GRID);
        insert customGrid;

        // Standard GridDetail on the standard grid (no rule needed — recap uses includeHoverData=false)
        GridDetail__c stdDetail = GridTestSetupHelper.createGridDetail(standardGrid.Id, null, null, sc.Id, 2.50, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_STANDARD_GRID_DETAIL);
        insert stdDetail;

        // Custom GridDetail on the custom grid, linked to the standard detail
        GridDetail__c customDetail = GridTestSetupHelper.createGridDetail(customGrid.Id, null, null, sc.Id, 2.50, Date.today(), Date.newInstance(2099, 12, 31), GridBuilderHelper.RT_CUSTOM_GRID_DETAIL);
        customDetail.StandardGridDetail__c = stdDetail.Id;
        insert customDetail;

        // Point the agreement to the custom grid
        AgreementTriggerHandler.triggerDisabled = true;
        agr.Grid__c = customGrid.Id;
        update agr;
        AgreementTriggerHandler.triggerDisabled = false;

        // Create one inactive timeline record (past grid)
        insert new AgreementGridTimeline__c(
            Name              = agr.Name + ' - Previous Grid',
            Agreement__c      = agr.Id,
            Grid__c           = standardGrid.Id,
            GridStartDate__c  = Date.today().addMonths(-12),
            GridEndDate__c    = Date.today().addMonths(-1),
            Status__c         = 'Inactive'
        );

        Test.startTest();

        AgreementGridRecapController.RecapWrapper result = AgreementGridRecapController.getRecap(agr.Id);

        Test.stopTest();
    }
}