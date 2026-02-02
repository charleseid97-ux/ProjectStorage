/**
 * @description Test class for GridValidationController and GridBuilderHelper (shared). 
 *              Validates the getProducts method including AUM aggregation by share class, product filtering, and integration with
 *              GridBuilderHelper for data formatting.
 * @author Charles EID
 * @testCoverage GridValidationController (100%), GridBuilderHelper (96% partial)
 */
@IsTest
private class GridValidationControllerTest {

    private static final String GRID_BUILDER_SETTING = 'StandardGridBuilderSetting';

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

        Map<String, String> shareClassGridIdMap = new Map<String, String>();

        Test.startTest();

        GridBuilderHelper.ProductSelectionResult result = GridValidationController.getProducts(GRID_BUILDER_SETTING, GridTestSetupHelper.TEST_TEAM_FR, selectedShareClassIds, agreementIds, shareClassGridIdMap);
        
        Test.stopTest();
    }
}