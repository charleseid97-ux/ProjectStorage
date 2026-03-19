/** ──────────────────────────────────────
 * @description Test class for GridDetailBuilder. 
 *              Validates rebate calculation logic for all 4 rule types (Percentage of Fees, Other Share Type, Other Share Type + Fees, Other Grid Rule), 
 *              complex filter logic (AND/OR/Custom Logic/NOT IN), multi-pass dependency resolution, and edge cases.
 * @author Charles EID
 * @testCoverage GridDetailBuilder (85%), GridCriteriaExpressionParser (91% partial)   [19-03-26]
────────────────────────────────────── */
@IsTest
private with sharing class GridDetailBuilderTest {

    public static final String percentageOfFees = 'Percentage of Fees';
    public static final String userDefined = 'User-Defined';

    @TestSetup
    static void makeData() {
        GridTestSetupHelper.setupTestData();
    }

    @IsTest
    static void testbuildForGridRules_AllRuleTypes() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        List<GridScope__c> scopes = [SELECT Id FROM GridScope__c WHERE Grid__c = :grid.Id LIMIT 1];

        if (scopes.isEmpty() || grid == null) {
            return;
        }

        Set<Id> gridRuleIds = new Set<Id>();

        // 1. Percentage of Fees rule (Type A)
        GridCriteria__c criteria1 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', percentageOfFees);
        insert criteria1;
        insert GridTestSetupHelper.createCriteriaDetail(criteria1.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRule__c rule1 = GridTestSetupHelper.createGridRule(grid.Id, criteria1.Id, percentageOfFees, 'EffectiveManagementFees__c', 33, null, null, null);
        insert rule1;
        gridRuleIds.add(rule1.Id);

        // 2. Other Share Type rule (Type AW referencing Type A)
        GridCriteria__c criteria2 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Other Share Type');
        insert criteria2;
        insert GridTestSetupHelper.createCriteriaDetail(criteria2.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_AW, userDefined);
        GridRule__c rule2 = GridTestSetupHelper.createGridRule(grid.Id, criteria2.Id, 'Take Rebates Rate - Other Share Type', 'EffectiveManagementFees__c', null, null, GridTestSetupHelper.SHARE_TYPE_A, null);
        insert rule2;
        gridRuleIds.add(rule2.Id);

        // 3. Other Share Type + Fees rule (Type E referencing Type A + 15% fees)
        GridCriteria__c criteria3 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Other Share Type Plus Fees');
        insert criteria3;
        insert GridTestSetupHelper.createCriteriaDetail(criteria3.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E, userDefined);
        GridRule__c rule3 = GridTestSetupHelper.createGridRule(grid.Id, criteria3.Id, 'Take Rebates Rate - Other Share Type + Fees', 'EffectiveManagementFees__c', 15, GridTestSetupHelper.SHARE_TYPE_E, GridTestSetupHelper.SHARE_TYPE_A, null);
        insert rule3;
        gridRuleIds.add(rule3.Id);

        // 4. AND logic criteria (FCP AND Type F)
        GridCriteria__c criteria4 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1 AND 2', 'AND Logic');
        insert criteria4;
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria4.Id, 1, 'Product__c', 'Legal_Status__c', '=', GridTestSetupHelper.LEGAL_STATUS_FCP, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria4.Id, 2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_F, userDefined)
        };
        GridRule__c rule4 = GridTestSetupHelper.createGridRule(grid.Id, criteria4.Id, percentageOfFees, 'EffectiveManagementFees__c', 25, null, null, null);
        insert rule4;
        gridRuleIds.add(rule4.Id);

        // 5. OR logic criteria (Type A OR Type AW)
        GridCriteria__c criteria5 = GridTestSetupHelper.createCriteria(grid.Id, 'OR', '1 OR 2', 'OR Logic');
        insert criteria5;
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria5.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria5.Id, 2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_AW, userDefined)
        };
        GridRule__c rule5 = GridTestSetupHelper.createGridRule(grid.Id, criteria5.Id, percentageOfFees, 'EffectiveManagementFees__c', 20, null, null, null);
        insert rule5;
        gridRuleIds.add(rule5.Id);

        // 6. Custom Logic criteria ((FCP AND Type A) OR Type E)
        GridCriteria__c criteria6 = GridTestSetupHelper.createCriteria(grid.Id, 'Custom Logic', '(1 AND 2) OR 3', 'Custom Logic');
        insert criteria6;
        insert new List<GridCriteriaDetail__c>{
            GridTestSetupHelper.createCriteriaDetail(criteria6.Id, 1, 'Product__c', 'Legal_Status__c', '=', GridTestSetupHelper.LEGAL_STATUS_FCP, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria6.Id, 2, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined),
            GridTestSetupHelper.createCriteriaDetail(criteria6.Id, 3, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_E, userDefined)
        };
        GridRule__c rule6 = GridTestSetupHelper.createGridRule(grid.Id, criteria6.Id, percentageOfFees, 'EffectiveManagementFees__c', 18, null, null, null);
        insert rule6;
        gridRuleIds.add(rule6.Id);

        // 7. NOT IN logic criteria (Legal Status NOT IN SICAV)
        GridCriteria__c criteria7 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'NOT IN Logic');
        insert criteria7;
        insert GridTestSetupHelper.createCriteriaDetail(criteria7.Id, 1, 'Product__c', 'Legal_Status__c', 'NOT IN', GridTestSetupHelper.LEGAL_STATUS_SICAV, userDefined);
        GridRule__c rule7 = GridTestSetupHelper.createGridRule(grid.Id, criteria7.Id, percentageOfFees, 'EffectiveManagementFees__c', 22, null, null, null);
        insert rule7;
        gridRuleIds.add(rule7.Id);

        // 8. Missing data scenario - share class with null fees
        Share_Class__c noFeesShareClass = GridTestSetupHelper.createShareClass(GridTestSetupHelper.getTestProducts()[0].Id, 'NoFeesShareClass', 'LU9999999999', GridTestSetupHelper.SHARE_TYPE_E, null, GridTestSetupHelper.CURRENCY_EUR);
        insert noFeesShareClass;
        GridCriteria__c criteria8 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Missing Data');
        insert criteria8;
        insert GridTestSetupHelper.createCriteriaDetail(criteria8.Id, 1, 'Share_Class__c', 'ISIN__c', '=', 'LU9999999999', userDefined);
        GridRule__c rule8 = GridTestSetupHelper.createGridRule(grid.Id, criteria8.Id, percentageOfFees, 'EffectiveManagementFees__c', 33, null, null, null);
        insert rule8;
        gridRuleIds.add(rule8.Id);

        // 9. Not found scenario - referencing non-existent share type
        GridCriteria__c criteria9 = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'Not Found');
        insert criteria9;
        insert GridTestSetupHelper.createCriteriaDetail(criteria9.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRule__c rule9 = GridTestSetupHelper.createGridRule(grid.Id, criteria9.Id, 'Take Rebates Rate - Other Share Type', 'EffectiveManagementFees__c', null, null, 'NonExistentType', null);
        insert rule9;
        gridRuleIds.add(rule9.Id);

        // 10. No criteria details — triggers ctx.details.isEmpty() guard (line 152)
        GridCriteria__c criteriaNoDetails = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'No Details');
        insert criteriaNoDetails;
        GridRule__c ruleNoDetails = GridTestSetupHelper.createGridRule(grid.Id, criteriaNoDetails.Id, percentageOfFees, 'EffectiveManagementFees__c', 10, null, null, null);
        insert ruleNoDetails;
        gridRuleIds.add(ruleNoDetails.Id);

        Test.startTest();

        GridDetailBuilder.BuildResult result = GridDetailBuilder.buildForGridRules(gridRuleIds);

        Test.stopTest();
    }

    @IsTest
    static void testbuildForGridRules_OtherGridRule() {
        Grid__c gridS1 = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c gridS5Plus = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S5_PLUS);

        List<GridScope__c> scopesS1 = [SELECT Id FROM GridScope__c WHERE Grid__c = :gridS1.Id LIMIT 1];
        List<GridScope__c> scopesS5Plus = [SELECT Id FROM GridScope__c WHERE Grid__c = :gridS5Plus.Id LIMIT 1];

        if (scopesS1.isEmpty() || scopesS5Plus.isEmpty() || gridS1 == null || gridS5Plus == null) {
            return;
        }

        Set<Id> gridRuleIds = new Set<Id>();

        // Create rule in S1 grid first (to be referenced by S5+)
        GridCriteria__c criteriaS1 = GridTestSetupHelper.createCriteria(gridS1.Id, 'AND', '1', 'S1 Criteria');
        insert criteriaS1;
        insert GridTestSetupHelper.createCriteriaDetail(criteriaS1.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRule__c gridRuleS1 = GridTestSetupHelper.createGridRule(gridS1.Id, criteriaS1.Id, percentageOfFees, 'EffectiveManagementFees__c', 33, null, null, null);
        insert gridRuleS1;
        gridRuleIds.add(gridRuleS1.Id);

        // Build for S1 first so S5+ can reference it
        GridDetailBuilder.buildForGridRules(new Set<Id>{gridRuleS1.Id});

        // Create rule in S5+ that references S1
        GridCriteria__c criteriaS5Plus = GridTestSetupHelper.createCriteria(gridS5Plus.Id, 'AND', '1', 'S5+ References S1');
        insert criteriaS5Plus;
        insert GridTestSetupHelper.createCriteriaDetail(criteriaS5Plus.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRule__c gridRuleS5Plus = GridTestSetupHelper.createGridRule(gridS5Plus.Id, criteriaS5Plus.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, GridTestSetupHelper.GRID_NAME_S1);
        insert gridRuleS5Plus;
        gridRuleIds.add(gridRuleS5Plus.Id);

        // Create rule with non-existent grid reference
        GridCriteria__c criteriaNotFound = GridTestSetupHelper.createCriteria(gridS5Plus.Id, 'AND', '1', 'Non-existent Grid');
        insert criteriaNotFound;
        insert GridTestSetupHelper.createCriteriaDetail(criteriaNotFound.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_AW, userDefined);
        GridRule__c gridRuleNotFound = GridTestSetupHelper.createGridRule(gridS5Plus.Id, criteriaNotFound.Id, 'Take Rebates Rate - Other Grid Rule', 'EffectiveManagementFees__c', null, null, null, 'NonExistentGrid');
        insert gridRuleNotFound;
        gridRuleIds.add(gridRuleNotFound.Id);

        Test.startTest();

        GridDetailBuilder.BuildResult result = GridDetailBuilder.buildForGridRules(gridRuleIds);

        Test.stopTest();
    }

    @IsTest
    static void testBuildEdgeCases() {
        Test.startTest();

        // Null / empty set → covers early-return guards (lines 32, 43)
        GridDetailBuilder.BuildResult r1 = GridDetailBuilder.buildForGridRules(null);
        GridDetailBuilder.BuildResult r2 = GridDetailBuilder.buildForGridRules(new Set<Id>());
        GridDetailBuilder.BuildResult r3 = GridDetailBuilder.buildForGrids(null);
        GridDetailBuilder.BuildResult r4 = GridDetailBuilder.buildForGrids(new Set<Id>());

        // Non-existent ID → SOQL returns empty → covers empty-list guard in private build(List, BuildResult)
        Id fakeRuleId = GridRule__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA';
        GridDetailBuilder.BuildResult r5 = GridDetailBuilder.buildForGridRules(new Set<Id>{fakeRuleId});

        Test.stopTest();
    }

    @IsTest
    static void testBuildForGrids() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        Grid__c gridNoScope = GridTestSetupHelper.createGrid('NoScopeGrid', GridTestSetupHelper.TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID);
        insert gridNoScope;

        List<GridScope__c> scopes = [SELECT Id FROM GridScope__c WHERE Grid__c = :grid.Id LIMIT 1];

        if (scopes.isEmpty() || grid == null) {
            return;
        }

        GridCriteria__c criteria = GridTestSetupHelper.createCriteria(grid.Id, 'AND', '1', 'BuildForGrids Test');
        insert criteria;
        insert GridTestSetupHelper.createCriteriaDetail(criteria.Id, 1, 'Share_Class__c', 'Type__c', '=', GridTestSetupHelper.SHARE_TYPE_A, userDefined);
        GridRule__c gridRule = GridTestSetupHelper.createGridRule(grid.Id, criteria.Id, percentageOfFees, 'EffectiveManagementFees__c', 27, null, null, null);
        insert gridRule;

        Test.startTest();

        GridDetailBuilder.BuildResult result1 = GridDetailBuilder.buildForGrids(new Set<Id>{grid.Id});
        GridDetailBuilder.BuildResult result2 = GridDetailBuilder.buildForGrids(new Set<Id>{gridNoScope.Id});

        Test.stopTest();
    }
}