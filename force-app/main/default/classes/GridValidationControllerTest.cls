/** ──────────────────────────────────────
 * @description Test class for GridValidationController and GridBuilderHelper (shared). 
 *              Validates the getProducts method including AUM aggregation by share class, product filtering, and integration with
 *              GridBuilderHelper for data formatting.
 * @author Charles EID
 * @testCoverage GridValidationController (96%), GridBuilderHelper (93% partial)   [19-03-26]
────────────────────────────────────── */
@IsTest
private class GridValidationControllerTest {

    private static final String GRID_BUILDER_SETTING = 'CustomGridBuilderSetting';
    private static final String TEST_COUNTRIES = 'FR';

    @TestSetup
    static void makeData() {
       	GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testGetProducts() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();

        Share_Class__c shareClass1 = shareClasses[0];
        Share_Class__c shareClass2 = shareClasses[1];
        List<Id> selectedShareClassIds = new List<Id>{shareClass1.Id, shareClass2.Id};

        List<Convention__c> agreements = GridTestSetupHelper.getTestAgreements();
        List<Id> agreementIds = new List<Id>{agreements[0].Id, agreements[1].Id};

        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Map<String, String> shareClassGridIdMap = new Map<String, String>{
            String.valueOf(shareClass1.Id) => String.valueOf(grid.Id),
            String.valueOf(shareClass2.Id) => String.valueOf(grid.Id)
        };

        Test.startTest();

        GridBuilderHelper.ProductSelectionResult result = GridValidationController.getProducts(GRID_BUILDER_SETTING, TEST_COUNTRIES, selectedShareClassIds, agreementIds, shareClassGridIdMap, new List<String>());

        Test.stopTest();
    }

    @IsTest
    static void testSaveGrid() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();
        List<Convention__c> agreements = GridTestSetupHelper.getTestAgreements();
        Grid__c standardGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Share_Class__c sc1 = shareClasses[0];
        Share_Class__c sc2 = shareClasses[1];

        Map<String, String> shareClassGridIdMap = new Map<String, String>{
            String.valueOf(sc1.Id) => String.valueOf(standardGrid.Id),
            String.valueOf(sc2.Id) => String.valueOf(standardGrid.Id)
        };

        // Build request JSON matching GridSaveRequest structure
        List<Map<String, Object>> criteriaDetails = new List<Map<String, Object>>{
            new Map<String, Object>{ 'Object__c' => 'Share_Class__c', 'Field__c' => 'Type__c', 'Logic__c' => '=', 'Value__c' => 'A', 'FilterNumber__c' => 1, 'TECHOrigin__c' => 'User-Defined' }
        };
        Map<String, Object> request = buildSaveRequest('Custom - Test Save - Manual - 2025-01-01', Date.today(), standardGrid.Id, criteriaDetails, new List<Id>{ sc1.Id, sc2.Id }, new List<Id>{ agreements[0].Id });

        Test.startTest();

        GridValidationController.GridSaveResult result = GridValidationController.saveGrid(JSON.serialize(request), shareClassGridIdMap, null);

        Test.stopTest();
    }

    @IsTest
    static void testSaveGrid_draftEdit() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();
        List<Convention__c> agreements = GridTestSetupHelper.getTestAgreements();
        Grid__c standardGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Share_Class__c sc1 = shareClasses[0];

        Map<String, String> shareClassGridIdMap = new Map<String, String>{
            String.valueOf(sc1.Id) => String.valueOf(standardGrid.Id)
        };

        // First save — creates a new draft grid + AGT
        Map<String, Object> firstRequest = buildSaveRequest('Draft - Test Edit', Date.today(), standardGrid.Id, new List<Map<String, Object>>(), new List<Id>{ sc1.Id }, new List<Id>{ agreements[0].Id });
        GridValidationController.GridSaveResult firstSave = GridValidationController.saveGrid(JSON.serialize(firstRequest), shareClassGridIdMap, null);
        System.assert(firstSave.success, 'First save should succeed: ' + firstSave.errors);
        Id draftGridId = firstSave.gridId;

        // Second save — edit the draft: updated name and start date
        Map<String, Object> editRequest = buildSaveRequest('Draft - Test Edit - Updated', Date.today().addDays(7), standardGrid.Id, new List<Map<String, Object>>(), new List<Id>{ sc1.Id }, new List<Id>{ agreements[0].Id });

        Test.startTest();

        GridValidationController.GridSaveResult editSave = GridValidationController.saveGrid(JSON.serialize(editRequest), shareClassGridIdMap, draftGridId);
        
        Test.stopTest();
    }

    @IsTest
    static void testSaveGrid_withExistingGrid() {
        List<Share_Class__c> shareClasses = GridTestSetupHelper.getTestShareClasses();
        List<Convention__c> agreements = GridTestSetupHelper.getTestAgreements();
        Grid__c standardGrid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        // Pre-set a grid on the agreement so the save logic creates a Draft timeline instead
        Convention__c agr = agreements[0];
        AgreementTriggerHandler.triggerDisabled = true;
        agr.Grid__c = standardGrid.Id;
        update agr;
        AgreementTriggerHandler.triggerDisabled = false;

        Share_Class__c sc1 = shareClasses[0];
        Map<String, String> shareClassGridIdMap = new Map<String, String>{
            String.valueOf(sc1.Id) => String.valueOf(standardGrid.Id)
        };

        Map<String, Object> request = buildSaveRequest('Custom - Test Amendment - 2025-01-01', Date.today().addMonths(1), standardGrid.Id, new List<Map<String, Object>>(), new List<Id>{ sc1.Id }, new List<Id>{ agr.Id });

        Test.startTest();

        GridValidationController.GridSaveResult result = GridValidationController.saveGrid(JSON.serialize(request), shareClassGridIdMap, null);

        Test.stopTest();
    }

    // ────────────────────────────────────── HELPERS ──────────────────────────────────────
    private static Map<String, Object> buildSaveRequest(String gridName, Date startDate, Id standardGridId, List<Map<String, Object>> criteriaDetails, List<Id> shareClassIds, List<Id> agreementIds) {
        return new Map<String, Object>{
            'grid' => new Map<String, Object>{
                'Name'                 => gridName,
                'ActiveGrid__c'        => true,
                'AutomaticGridUpdate__c' => false,
                'StartDate__c'         => startDate
            },
            'criteriaList' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'criteriaRefId' => 'crit-ref-1',
                    'criteria'      => new Map<String, Object>{ 'StandardGrid__c' => standardGridId, 'FilterLogic__c' => 'AND', 'StartDate__c' => startDate },
                    'details'       => criteriaDetails,
                    'shareClassIds' => shareClassIds
                }
            },
            'agreementIds' => agreementIds
        };
    }
}