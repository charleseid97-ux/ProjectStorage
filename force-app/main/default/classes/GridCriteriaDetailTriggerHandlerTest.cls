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

    public static final String FLTRLOGIC_AND     = 'AND';
    public static final String FLTRLOGIC_OR      = 'OR';
    public static final String FLTRLOGIC_CUSTOM  = 'Custom Logic';

    public static final String OBJ_PRODUCT     = 'Product__c';
    public static final String OBJ_SHARECLASS  = 'Share_Class__c';

    public static final String FIELD_LEGALFORM    = 'LegalForm__c';
    public static final String FIELD_TYPE         = 'Type__c';
    public static final String FIELD_INTSHORTNAME = 'InternalShortName__c';
    public static final String FIELD_CURRENCY     = 'Currency__c';

    public static final String OPER_EQUALS    = '=';
    public static final String OPER_NOTEQUALS = '!=';
    public static final String OPER_IN        = 'IN';
    public static final String OPER_NOTIN     = 'NOT IN';

    public static final String VAL_FCPSICAV = 'FCP;SICAV';
    public static final String VAL_A        = 'A';
    public static final String VAL_E        = 'E';
    public static final String VAL_AE       = 'A;E';
    public static final String VAL_USD      = 'USD';
    public static final String VAL_CCPCGB   = 'CCP;CGB';

    public static final String ORIGIN_USERDEFINED = 'User-Defined';

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── Test 1: AND ──────────────────────────────────────────────────────────
    @IsTest
    static void testAndLogic() {
        GridCriteria__c criteria = insertCriteria(FLTRLOGIC_AND, null);

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, OBJ_PRODUCT,    FIELD_LEGALFORM,    OPER_IN,     VAL_FCPSICAV, ORIGIN_USERDEFINED),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, OBJ_SHARECLASS, FIELD_TYPE,         OPER_EQUALS, VAL_E,        ORIGIN_USERDEFINED),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 3, OBJ_PRODUCT,    FIELD_INTSHORTNAME, OPER_IN,     VAL_CCPCGB,   ORIGIN_USERDEFINED)
        };
        Test.stopTest();
    }

    // ─── Test 2: OR ───────────────────────────────────────────────────────────
    @IsTest
    static void testOrLogic() {
        GridCriteria__c criteria = insertCriteria(FLTRLOGIC_OR, null);

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, OBJ_SHARECLASS, FIELD_TYPE, OPER_EQUALS,    VAL_A, ORIGIN_USERDEFINED),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, OBJ_SHARECLASS, FIELD_TYPE, OPER_NOTEQUALS, VAL_E, ORIGIN_USERDEFINED)
        };
        Test.stopTest();
    }

    // ─── Test 3: Custom Logic ────────────────────────────────────────────────
    @IsTest
    static void testCustomLogic() {
        GridCriteria__c criteria = insertCriteria(FLTRLOGIC_CUSTOM, '1 AND (2 OR 3)');

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, OBJ_PRODUCT,    FIELD_LEGALFORM, OPER_IN,      VAL_FCPSICAV,  ORIGIN_USERDEFINED),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, OBJ_SHARECLASS, FIELD_TYPE,      OPER_EQUALS,  VAL_A,         ORIGIN_USERDEFINED),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 3, OBJ_SHARECLASS, FIELD_TYPE,      OPER_EQUALS,  VAL_E,         ORIGIN_USERDEFINED)
        };
        Test.stopTest();
    }

    // ─── Test 4: Update ───────────────────────────────────────────────────────
    @IsTest
    static void testUpdate() {
        GridCriteria__c criteria = insertCriteria(FLTRLOGIC_AND, null);
        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, OBJ_SHARECLASS, FIELD_TYPE, OPER_EQUALS, VAL_A, ORIGIN_USERDEFINED);

        GridCriteriaDetail__c detail = [SELECT Id FROM GridCriteriaDetail__c WHERE GridCriteria__c = :criteria.Id LIMIT 1];

        Test.startTest();
        detail.Value__c = VAL_E;
        detail.Logic__c = OPER_NOTEQUALS;
        update detail;
        Test.stopTest();
    }

    // ─── Test 5: NOT IN operator ─────────────────────────────────────────────
    @IsTest
    static void testNotInOperator() {
        GridCriteria__c criteria = insertCriteria(FLTRLOGIC_AND, null);

        Test.startTest();
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, OBJ_SHARECLASS, FIELD_TYPE,     OPER_NOTIN, VAL_AE,  ORIGIN_USERDEFINED),
            GridTestSetupHelper.createCriteriaDetail(criteria.Id, 2, OBJ_SHARECLASS, FIELD_CURRENCY, OPER_NOTIN, VAL_USD, ORIGIN_USERDEFINED)
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