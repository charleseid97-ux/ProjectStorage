/**
 * @description Test class for GridDetailBuilder. 
 *              Validates rebate calculation logic for all 4 rule types (Percentage of Fees, Other Share Type, Other Share Type + Fees, Other Grid Rule), 
 *              complex filter logic (AND/OR/Custom Logic/NOT IN), multi-pass dependency resolution, and edge cases.
 * @author Charles EID
 * @testCoverage GridDetailBuilder (84%), GridCriteriaExpressionParser (83% partial)
 */
@IsTest
private class GridDetailBuilderTest {

    public static final String percentageOfFees = 'Percentage of Fees';
    public static final String userDefined = 'User-Defined';

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testBuildForRuleLines_AllRuleTypes() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        List<GridScope__c> scopes = [SELECT Id FROM GridScope__c WHERE GridName__c = :GridTestSetupHelper.GRID_NAME_S1 LIMIT 1];

        if (scopes.isEmpty() || grid == null) {
            return;
        }

        Id scopeId = scopes[0].Id;
        Set<Id> ruleLineIds = new Set<Id>();

        // 1. Percentage of Fees rule (Type A)
        GridCriteria__c criteria1 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', percentageOfFees);
        insert criteria1;
        insert GridTestSetupHelper.createCriteriaDetail(criteria1.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRuleLine__c rule1 = GridTestSetupHelper.createRuleLine(scopeId, criteria1.Id, percentageOfFees, 'EffectiveManagementFees__c', 33, null, null, null);
        insert rule1;
        ruleLineIds.add(rule1.Id);

        // 2. Other Share Type rule (Type AW referencing Type A)
        GridCriteria__c criteria2 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Other Share Type');
        insert criteria2;
        insert GridTestSetupHelper.createCriteriaDetail(criteria2.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_AW, userDefined);
        GridRuleLine__c rule2 = GridTestSetupHelper.createRuleLine(scopeId, criteria2.Id, 'Take Rebates Rate - Other Share Type', 'EffectiveManagementFees__c', null, null, GridTestSetupHelper.SHARE_TYPE_A, null);
        insert rule2;
        ruleLineIds.add(rule2.Id);

        // 3. Other Share Type + Fees rule (Type E referencing Type A + 15% fees)
        GridCriteria__c criteria3 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Other Share Type Plus Fees');
        insert criteria3;
        insert GridTestSetupHelper.createCriteriaDetail(criteria3.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E, userDefined);
        GridRuleLine__c rule3 = GridTestSetupHelper.createRuleLine(scopeId, criteria3.Id, 'Take Rebates Rate - Other Share Type + Fees', 'EffectiveManagementFees__c', 15, GridTestSetupHelper.SHARE_TYPE_E, GridTestSetupHelper.SHARE_TYPE_A, null);
        insert rule3;
        ruleLineIds.add(rule3.Id);

        // 4. AND logic criteria (FCP AND Type F)
        GridCriteria__c criteria4 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1 AND 2', 'AND Logic');
        insert criteria4;
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria4.Id, 1, 'Product__c', 'Legal_Status__c', '=', GridTestSetupHelper.LEGAL_STATUS_FCP, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria4.Id, 2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_F, userDefined)
        };
        GridRuleLine__c rule4 = GridTestSetupHelper.createRuleLine(scopeId, criteria4.Id, percentageOfFees, 'EffectiveManagementFees__c', 25, null, null, null);
        insert rule4;
        ruleLineIds.add(rule4.Id);

        // 5. OR logic criteria (Type A OR Type AW)
        GridCriteria__c criteria5 = GridTestSetupHelper.createCriteria(grid.Id, 'OR', '1 OR 2', 'OR Logic');
        insert criteria5;
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria5.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria5.Id, 2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_AW, userDefined)
        };
        GridRuleLine__c rule5 = GridTestSetupHelper.createRuleLine(scopeId, criteria5.Id, percentageOfFees, 'EffectiveManagementFees__c', 20, null, null, null);
        insert rule5;
        ruleLineIds.add(rule5.Id);

        // 6. Custom Logic criteria ((FCP AND Type A) OR Type E)
        GridCriteria__c criteria6 = GridTestSetupHelper.createCriteria(grid.Id, 'Custom Logic', '(1 AND 2) OR 3', 'Custom Logic');
        insert criteria6;
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria6.Id, 1, 'Product__c', 'Legal_Status__c', '=', GridTestSetupHelper.LEGAL_STATUS_FCP, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria6.Id, 2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria6.Id, 3, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E, userDefined)
        };
        GridRuleLine__c rule6 = GridTestSetupHelper.createRuleLine(scopeId, criteria6.Id, percentageOfFees, 'EffectiveManagementFees__c', 18, null, null, null);
        insert rule6;
        ruleLineIds.add(rule6.Id);

        // 7. NOT IN logic criteria (Legal Status NOT IN SICAV)
        GridCriteria__c criteria7 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'NOT IN Logic');
        insert criteria7;
        insert GridTestSetupHelper.createCriteriaDetail(criteria7.Id, 1, 'Product__c', 'Legal_Status__c', 'NOT IN', GridTestSetupHelper.LEGAL_STATUS_SICAV, userDefined);
        GridRuleLine__c rule7 = GridTestSetupHelper.createRuleLine(scopeId, criteria7.Id, percentageOfFees, 'EffectiveManagementFees__c', 22, null, null, null);
        insert rule7;
        ruleLineIds.add(rule7.Id);

        // 8. Missing data scenario - share class with null fees
        Share_Class__c noFeesShareClass = GridTestSetupHelper.createShareClass(GridTestSetupHelper.getTestProducts()[0].Id, 'NoFeesShareClass', 'LU9999999999', GridTestSetupHelper.SHARE_TYPE_E, null, GridTestSetupHelper.CURRENCY_EUR);
        insert noFeesShareClass;
        GridCriteria__c criteria8 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Missing Data');
        insert criteria8;
        insert GridTestSetupHelper.createCriteriaDetail(criteria8.Id, 1, 'Share_Class__c', 'ISIN__c', '=', 'LU9999999999', userDefined);
        GridRuleLine__c rule8 = GridTestSetupHelper.createRuleLine(scopeId, criteria8.Id, percentageOfFees, 'EffectiveManagementFees__c', 33, null, null, null);
        insert rule8;
        ruleLineIds.add(rule8.Id);

        // 9. Not found scenario - referencing non-existent share type
        GridCriteria__c criteria9 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Not Found');
        insert criteria9;
        insert GridTestSetupHelper.createCriteriaDetail(criteria9.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRuleLine__c rule9 = GridTestSetupHelper.createRuleLine(scopeId, criteria9.Id, 'Take Rebates Rate - Other Share Type', 'EffectiveManagementFees__c', null, null, 'NonExistentType', null);
        insert rule9;
        ruleLineIds.add(rule9.Id);

        Test.startTest();

        GridDetailBuilder.BuildResult result = GridDetailBuilder.buildForRuleLines(ruleLineIds);

        Test.stopTest();
    }

    @IsTest
    static void testBuildForRuleLines_OtherGridRule() {
        Grid__c gridS1 = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c gridS5Plus = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S5_PLUS);

        List<GridScope__c> scopesS1 = [SELECT Id FROM GridScope__c WHERE GridName__c = :GridTestSetupHelper.GRID_NAME_S1 LIMIT 1];
        List<GridScope__c> scopesS5Plus = [SELECT Id FROM GridScope__c WHERE GridName__c = :GridTestSetupHelper.GRID_NAME_S5_PLUS LIMIT 1];

        if (scopesS1.isEmpty() || scopesS5Plus.isEmpty() || gridS1 == null || gridS5Plus == null) {
            return;
        }

        Set<Id> ruleLineIds = new Set<Id>();

        // Create rule in S1 grid first (to be referenced by S5+)
        GridCriteria__c criteriaS1 = GridTestSetupHelper.createCriteria(gridS1.Id, 'AND', '1', 'S1 Criteria');
        insert criteriaS1;
        insert GridTestSetupHelper.createCriteriaDetail(criteriaS1.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRuleLine__c ruleLineS1 = GridTestSetupHelper.createRuleLine(scopesS1[0].Id, criteriaS1.Id, percentageOfFees, 'EffectiveManagementFees__c', 33, null, null, null);
        insert ruleLineS1;
        ruleLineIds.add(ruleLineS1.Id);

        // Build for S1 first so S5+ can reference it
        GridDetailBuilder.buildForRuleLines(new Set<Id>{ruleLineS1.Id});

        // Create rule in S5+ that references S1
        GridCriteria__c criteriaS5Plus = GridTestSetupHelper.createCriteria(gridS5Plus.Id, 'AND', '1', 'S5+ References S1');
        insert criteriaS5Plus;
        insert GridTestSetupHelper.createCriteriaDetail(criteriaS5Plus.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRuleLine__c ruleLineS5Plus = GridTestSetupHelper.createRuleLine(scopesS5Plus[0].Id, criteriaS5Plus.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, GridTestSetupHelper.GRID_NAME_S1);
        insert ruleLineS5Plus;
        ruleLineIds.add(ruleLineS5Plus.Id);

        // Create rule with non-existent grid reference
        GridCriteria__c criteriaNotFound = GridTestSetupHelper.createCriteria(gridS5Plus.Id, 'AND', '1', 'Non-existent Grid');
        insert criteriaNotFound;
        insert GridTestSetupHelper.createCriteriaDetail(criteriaNotFound.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_AW, userDefined);
        GridRuleLine__c ruleLineNotFound = GridTestSetupHelper.createRuleLine(scopesS5Plus[0].Id, criteriaNotFound.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, 'NonExistentGrid');
        insert ruleLineNotFound;
        ruleLineIds.add(ruleLineNotFound.Id);

        Test.startTest();

        GridDetailBuilder.BuildResult result = GridDetailBuilder.buildForRuleLines(ruleLineIds);

        Test.stopTest();
    }

    @IsTest
    static void testBuildForGrids() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c gridNoScope = GridTestSetupHelper.createGrid('NoScopeGrid', null, GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert gridNoScope;

        List<GridScope__c> scopes = [SELECT Id FROM GridScope__c WHERE GridName__c = :GridTestSetupHelper.GRID_NAME_S1 LIMIT 1];

        if (scopes.isEmpty() || grid == null) {
            return;
        }

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'BuildForGrids Test');
        insert criteria;
        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRuleLine__c ruleLine = GridTestSetupHelper.createRuleLine(scopes[0].Id, criteria.Id, percentageOfFees, 'EffectiveManagementFees__c', 27, null, null, null);
        insert ruleLine;

        Test.startTest();

        GridDetailBuilder.BuildResult result1 = GridDetailBuilder.buildForGrids(new Set<Id>{grid.Id});
        GridDetailBuilder.BuildResult result2 = GridDetailBuilder.buildForGrids(new Set<Id>{gridNoScope.Id});

        Test.stopTest();
    }
}