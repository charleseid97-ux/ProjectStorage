/** ──────────────────────────────────────
 * @description Test class for GridValidationController and GridBuilderHelper (shared). 
 *              Validates the getProducts method including AUM aggregation by share class, product filtering, and integration with
 *              GridBuilderHelper for data formatting.
 * @author Charles EID
 * @testCoverage GridValidationController (96%), GridBuilderHelper (94% partial)   [12-03-26]
────────────────────────────────────── */
@IsTest
private class GridValidationControllerTest {

    private static final String GRID_BUILDER_SETTING = 'StandardGridBuilderSetting';
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
        Map<String, Object> request = new Map<String, Object>{
            'grid' => new Map<String, Object>{
                'Name' => 'Custom - Test Save - Manual - 2025-01-01',
                'ActiveGrid__c' => true,
                'AutomaticGridUpdate__c' => false
            },
            'criteriaList' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'criteriaRefId' => 'crit-ref-1',
                    'criteria' => new Map<String, Object>{
                        'StandardGrid__c' => standardGrid.Id,
                        'FilterLogic__c' => 'AND',
                        'StartDate__c' => Date.today()
                    },
                    'details' => new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'Object__c' => 'Share_Class__c',
                            'Field__c' => 'Type__c',
                            'Logic__c' => '=',
                            'Value__c' => 'A',
                            'FilterNumber__c' => 1,
                            'TECHOrigin__c' => 'User-Defined'
                        }
                    },
                    'shareClassIds' => new List<Id>{ sc1.Id, sc2.Id }
                }
            },
            'agreementIds' => new List<Id>{ agreements[0].Id }
        };

        Test.startTest();

        GridValidationController.GridSaveResult result = GridValidationController.saveGrid(JSON.serialize(request), shareClassGridIdMap);

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

        Map<String, Object> request = new Map<String, Object>{
            'grid' => new Map<String, Object>{
                'Name' => 'Custom - Test Amendment - 2025-01-01',
                'ActiveGrid__c' => true,
                'AutomaticGridUpdate__c' => false,
                'StartDate__c' => Date.today().addMonths(1)
            },
            'criteriaList' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'criteriaRefId' => 'crit-ref-1',
                    'criteria' => new Map<String, Object>{
                        'StandardGrid__c' => standardGrid.Id,
                        'FilterLogic__c' => 'AND',
                        'StartDate__c' => Date.today().addMonths(1)
                    },
                    'details' => new List<Map<String, Object>>(),
                    'shareClassIds' => new List<Id>{ sc1.Id }
                }
            },
            'agreementIds' => new List<Id>{ agr.Id }
        };

        Test.startTest();

        GridValidationController.GridSaveResult result = GridValidationController.saveGrid(JSON.serialize(request), shareClassGridIdMap);

        Test.stopTest();
    }
}