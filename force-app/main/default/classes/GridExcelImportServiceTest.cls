@IsTest
private class GridExcelImportServiceTest {
    @IsTest
    static void testImportFromJson() {
        insert new Grid__c(Name = 'S1');

        GridExcelImportService.Payload payload = new GridExcelImportService.Payload();
        payload.scopes = new List<GridExcelImportService.ScopeRow>();
        payload.rules = new List<GridExcelImportService.RuleRow>();

        GridExcelImportService.ScopeRow scope1 = new GridExcelImportService.ScopeRow();
        scope1.rowNumber = 2;
        scope1.Grid = 'S1';
        scope1.Agreement = 'AGR1';
        scope1.Country = 'FR';
        scope1.PtfCode = 'FCP';
        payload.scopes.add(scope1);

        GridExcelImportService.ScopeRow scope2 = new GridExcelImportService.ScopeRow();
        scope2.rowNumber = 3;
        scope2.Grid = 'S5+';
        scope2.Agreement = null;
        scope2.Country = 'ALL';
        scope2.PtfCode = 'SICAV';
        payload.scopes.add(scope2);

        GridExcelImportService.RuleRow rule1 = new GridExcelImportService.RuleRow();
        rule1.rowNumber = 2;
        rule1.Grid = 'S1';
        rule1.Include = 'PtfCode IN (FCP,SICAV) AND ShcType = A';
        rule1.Exclude = 'ShcType = AW';
        rule1.Comment = 'Rule 1';
        rule1.RuleToApply = 'Percentage of Fees';
        rule1.FeesType = 'EffectiveManagementFees';
        rule1.RuleValue = '33,00%';
        rule1.ShareType = null;
        rule1.OtherShareType = null;
        payload.rules.add(rule1);

        GridExcelImportService.RuleRow rule2 = new GridExcelImportService.RuleRow();
        rule2.rowNumber = 3;
        rule2.Grid = 'S1';
        rule2.Include = 'PtfCode = FCP';
        rule2.Exclude = '';
        rule2.Comment = 'Rule 2';
        rule2.RuleToApply = 'Take Rebates Rate - Other Share Type + Fees';
        rule2.FeesType = 'EffectiveManagementFees';
        rule2.RuleValue = '15%';
        rule2.ShareType = 'AW';
        rule2.OtherShareType = 'AW';
        payload.rules.add(rule2);

        GridExcelImportService.RuleRow rule3 = new GridExcelImportService.RuleRow();
        rule3.rowNumber = 4;
        rule3.Grid = 'S5+';
        rule3.Include = 'ShcType IN (A,AW)';
        rule3.Exclude = 'PtfCode IN (SICAV)';
        rule3.Comment = 'Rule 3';
        rule3.RuleToApply = 'Take Rebates Rate - Other Grid Rule';
        rule3.FeesType = 'EffectiveManagementFees';
        rule3.RuleValue = 'S1-Rule-A';
        rule3.ShareType = null;
        rule3.OtherShareType = null;
        payload.rules.add(rule3);

        String payloadJson = JSON.serialize(payload);

        Test.startTest();
        GridExcelImportService.ImportResult result = GridExcelImportService.importFromJson(payloadJson);
        Test.stopTest();

        System.assertEquals(0, result.errors.size(), 'Expected no import errors.');
        System.assertEquals(2, result.scopesUpserted, 'Expected two scopes upserted.');
        System.assertEquals(3, result.criteriaCreated, 'Expected three criteria created.');
        System.assertEquals(6, result.criteriaDetailsCreated, 'Expected six criteria details created.');
        System.assertEquals(3, result.ruleLinesCreated, 'Expected three rule lines created.');

        List<GridScope__c> scopes = [SELECT Id, GridName__c, Name FROM GridScope__c WHERE GridName__c IN ('S1', 'S5+')];
        System.assertEquals(2, scopes.size(), 'Expected scopes to be inserted.');

        String expectedDate = Date.today().format();
        Map<String, Id> scopeIdsByName = new Map<String, Id>();
        for (GridScope__c scope : scopes) {
            scopeIdsByName.put(scope.GridName__c, scope.Id);
            System.assertEquals(
                'Grid Scope for ' + scope.GridName__c + ' - ' + expectedDate,
                scope.Name,
                'GridScope name should match the required format.'
            );
        }

        List<Grid__c> grids = [SELECT Id, Name, GridScope__c FROM Grid__c WHERE Name IN ('S1', 'S5+')];
        System.assertEquals(2, grids.size(), 'Expected grids to be present.');
        for (Grid__c grid : grids) {
            System.assertEquals(scopeIdsByName.get(grid.Name), grid.GridScope__c, 'Grid should reference matching GridScope__c.');
        }

        List<GridRuleLine__c> ruleLines = [
            SELECT Id, GridScope__c, GridCriteria__c, RuleToApply__c, FeesType__c,
                   PercentageOfFees__c, ShareType__c, OtherShareType__c, OtherGridRule__c
            FROM GridRuleLine__c
        ];
        System.assertEquals(3, ruleLines.size(), 'Expected rule lines to be inserted.');

        Boolean percentRuleFound = false;
        Boolean otherShareTypeFeesFound = false;
        for (GridRuleLine__c line : ruleLines) {
            System.assertNotEquals(null, line.GridScope__c, 'Rule line must reference GridScope__c.');
            System.assertNotEquals(null, line.GridCriteria__c, 'Rule line must reference GridCriteria__c.');
            System.assertEquals('EffectiveManagementFees__c', line.FeesType__c, 'FeesType should be API value.');
            if (line.RuleToApply__c == 'Percentage of Fees') {
                percentRuleFound = true;
                System.assertEquals(33, line.PercentageOfFees__c, 'Percent parsing should keep 33,00% as 33.');
                System.assertEquals(null, line.ShareType__c, 'ShareType should be blank for Percentage of Fees.');
            }
            if (line.RuleToApply__c == 'Take Rebates Rate - Other Share Type + Fees') {
                otherShareTypeFeesFound = true;
                System.assertEquals('AW', line.ShareType__c, 'ShareType should be populated from column.');
                System.assertEquals('AW', line.OtherShareType__c, 'OtherShareType should be populated from column.');
                System.assertEquals(15, line.PercentageOfFees__c, 'RuleValue should populate PercentageOfFees__c.');
            }
        }
        System.assertEquals(true, percentRuleFound, 'Expected a Percentage of Fees rule.');
        System.assertEquals(true, otherShareTypeFeesFound, 'Expected a Share Type + Fees rule.');

        List<GridCriteriaDetail__c> details = [SELECT Logic__c, Value__c FROM GridCriteriaDetail__c];
        Boolean inFound = false;
        Boolean notInFound = false;
        for (GridCriteriaDetail__c detail : details) {
            if (detail.Logic__c == 'IN' && detail.Value__c == 'FCP;SICAV') {
                inFound = true;
            }
            if (detail.Logic__c == 'NOT IN' && detail.Value__c == 'SICAV') {
                notInFound = true;
            }
        }
        System.assertEquals(true, inFound, 'Expected IN detail with value list.');
        System.assertEquals(true, notInFound, 'Expected NOT IN detail from Exclude.');
    }
}