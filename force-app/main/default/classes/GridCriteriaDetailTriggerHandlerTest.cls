/** ──────────────────────────────────────
 * @description Test class for GridCriteriaDetailTriggerHandler and GridCriteriaUtility.
 *              Covers BeforeInsert (TECHPythonFilter__c computation) and AfterInsert/AfterUpdate
 *              (TECHPythonExpression__c rollup) across AND, OR, Custom Logic, update, and
 *              NOT IN scenarios.
 * @author Charles EID
 * @testClass GridCriteriaDetailTriggerHandler, GridCriteriaUtility
────────────────────────────────────── */
@IsTest
private class GridCriteriaDetailTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── Test 1: AND ──────────────────────────────────────────────────────────
    @IsTest
    static void testAndLogic() {
        GridCriteria__c criteria = insertCriteria('AND', null);

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Product__c',     'LegalForm__c',         'IN', 'FCP;SICAV', 'User-Defined'),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, 'Share_Class__c', 'Type__c',              '=',  'E',         'User-Defined'),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 3, 'Product__c',     'InternalShortName__c', 'IN', 'CCP;CGB',   'User-Defined')
        };
        Test.stopTest();
    }

    // ─── Test 2: OR ───────────────────────────────────────────────────────────
    @IsTest
    static void testOrLogic() {
        GridCriteria__c criteria = insertCriteria('OR', null);

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c', '=',  'A', 'User-Defined'),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, 'Share_Class__c', 'Type__c', '!=', 'E', 'User-Defined')
        };
        Test.stopTest();
    }

    // ─── Test 3: Custom Logic ────────────────────────────────────────────────
    @IsTest
    static void testCustomLogic() {
        GridCriteria__c criteria = insertCriteria('Custom Logic', '1 AND (2 OR 3)');

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Product__c',     'LegalForm__c', 'IN', 'FCP;SICAV', 'User-Defined'),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, 'Share_Class__c', 'Type__c',      '=',  'A',         'User-Defined'),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 3, 'Share_Class__c', 'Type__c',      '=',  'E',         'User-Defined')
        };
        Test.stopTest();
    }

    // ─── Test 4: Update ───────────────────────────────────────────────────────
    @IsTest
    static void testUpdate() {
        GridCriteria__c criteria = insertCriteria('AND', null);
        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c', '=', 'A', 'User-Defined');

        GridCriteriaDetail__c detail = [SELECT Id FROM GridCriteriaDetail__c WHERE GridCriteria__c = :criteria.Id LIMIT 1];

        Test.startTest();
        detail.Value__c = 'E';
        detail.Logic__c = '!=';
        update detail;
        Test.stopTest();
    }

    // ─── Test 5: NOT IN operator ─────────────────────────────────────────────
    @IsTest
    static void testNotInOperator() {
        GridCriteria__c criteria = insertCriteria('AND', null);

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c',     'NOT IN', 'A;E', 'User-Defined'),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, 'Share_Class__c', 'Currency__c', 'NOT IN', 'USD', 'User-Defined')
        };
        Test.stopTest();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────
    private static GridCriteria__c insertCriteria(String filterLogic, String filterLogicExpression) {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, filterLogic, filterLogicExpression, 'Test');
        insert criteria;
        return criteria;
    }
}