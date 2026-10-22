/** ──────────────────────────────────────
 * @description Tests of the PMT matrix: invariants of the deployed configuration (sort order, every line field exists on the
 *                  stage objects, conditions compile and read only what their field level allows, ISIN__c owned by Legal or OPS),
 *                  then a test matrix (rules, owner rules by condition, conditional lines at project and share class level), and the
 *                  error of an invalid condition (custom label PMT_InvalidCondition).
 *              US-20194 V1.2: Conditional lines (RequiredCondition__c), the fields of a team's screen, and the fund's real values read by the
 *                  conditions of a modification project.
 * @covers PMTMatrix   98%   [23-10-26]
 * @lastModifiedBy Charles EID   [23-10-26]
 ────────────────────────────────────── */
@isTest
private class PMTMatrixTest {

    @isTest
    static void test_matrix() {
        // 1. Configuration loaded from the PMT custom metadata records, once per transaction
        PMTMatrix matrix = PMTMatrix.get();
        PMTMatrix sameMatrix = PMTMatrix.get();
        System.assert(matrix === sameMatrix, 'The matrix is loaded once per transaction');

        for (Integer i = 1; i < matrix.stages.size(); i++) {
            System.assert(matrix.stages[i - 1].sortOrder <= matrix.stages[i].sortOrder, 'Stages are sorted by order');
        }
        for (Integer i = 1; i < matrix.teams.size(); i++) {
            System.assert(matrix.teams[i - 1].sortOrder <= matrix.teams[i].sortOrder, 'Teams are sorted by order');
        }
        for (PMTMatrix.FieldRule rule : matrix.rules) {
            System.assertNotEquals(null, matrix.getTeam(rule.team), 'Every rule belongs to a team of the matrix');
            System.assertNotEquals(null, matrix.getStage(rule.stage), 'Every rule belongs to a stage of the matrix');
            System.assert(rule === matrix.getRule(rule.team, rule.stage), 'getRule() returns the configured rule');
            System.assert(!rule.isEmpty(), 'Only teams and stages with fields have a rule');
        }
        System.assert(matrix.getRule('Unknown Team', 'Unknown Stage').isEmpty(), 'getRule() returns an empty rule, never null');

        Map<String, String> teamByField = matrix.getTeamByField();
        Map<String, String> stageByField = matrix.getStageByField();
        Set<String> requiredFundFields = new Set<String>(matrix.getRequiredFields(true));
        for (PMTMatrix.FieldRule rule : matrix.rules) {
            Map<String, String> stageByTeamField = matrix.getStageByField(rule.team);
            for (String field : rule.getAllFields()) {
                System.assert(teamByField.containsKey(field) && stageByField.containsKey(field), 'Every field has a team and a stage');
                System.assert(stageByTeamField.containsKey(field), 'Every field of a team has a stage for that team');
            }
            System.assert(requiredFundFields.containsAll(rule.requiredFund), 'getRequiredFields() holds every required Fund field');
        }
        System.assertEquals(matrix.stages.size(), matrix.getRequiredFieldsByStage(false).size(), 'Every stage is a key of getRequiredFieldsByStage()');
        System.assertEquals(matrix.stages.size(), matrix.getTeamsWithoutFieldsByStage().size(), 'Every stage is a key of getTeamsWithoutFieldsByStage()');

        PMTMatrix isMatrix = matrix.forScope('IS');
        System.assert(isMatrix === matrix.forScope('IS'), 'forScope() is computed once per scope');
        for (PMTMatrix.Team team : isMatrix.teams) {
            System.assert(String.isBlank(team.scope) || team.scope == 'IS', 'forScope() keeps the teams of every scope and of the given scope');
        }
        for (PMTMatrix.FieldRule rule : isMatrix.rules) {
            System.assertNotEquals(null, isMatrix.getTeam(rule.team), 'forScope() keeps only the rules of its teams');
        }

        // US-20194: every field of a line exists on the stage object of its level, every condition reads only what its level allows
        Map<String, Schema.SObjectField> fundFields = Schema.SObjectType.ProjectProductChild__c.fields.getMap();
        Map<String, Schema.SObjectField> shareClassFields = Schema.SObjectType.ProjectShareclassChild__c.fields.getMap();
        List<String> missingFields = new List<String>();
        List<PMTFieldRuleLine__mdt> lines = [SELECT DeveloperName, Field__r.Object__c, Field__r.FieldApiName__c, Condition__c, Requirement__c, RequiredCondition__c
                                             FROM PMTFieldRuleLine__mdt];
        for (PMTFieldRuleLine__mdt line : lines) {
            Boolean fund = line.Field__r.Object__c == 'Product__c';
            if (!(fund ? fundFields : shareClassFields).containsKey(line.Field__r.FieldApiName__c)) missingFields.add(line.DeveloperName + ' ' + line.Field__r.FieldApiName__c);
            PMTCondition condition = PMTCondition.compile(line.Condition__c);
            if (fund && condition != null) System.assert(!condition.readsShareClass(), line.DeveloperName + ': a Fund field condition reads only ProjectProduct__c fields');
            // US-20194 V1.2: a Conditional line has a RequiredCondition__c, which compiles and reads only what its level allows
            PMTCondition requiredCondition = PMTCondition.compile(line.RequiredCondition__c);
            System.assertEquals(line.Requirement__c == 'Conditional', requiredCondition != null, line.DeveloperName + ': RequiredCondition__c is set exactly on Conditional lines');
            if (fund && requiredCondition != null) System.assert(!requiredCondition.readsShareClass(), line.DeveloperName + ': a Fund field required condition reads only ProjectProduct__c fields');
        }
        System.assert(missingFields.isEmpty(), 'Line fields missing on the stage objects: ' + missingFields);
        for (PMTOwnerRule__mdt ownerRule : [SELECT DeveloperName, Condition__c FROM PMTOwnerRule__mdt]) {
            PMTCondition condition = PMTCondition.compile(ownerRule.Condition__c);
            if (condition != null) System.assert(!condition.readsShareClass(), ownerRule.DeveloperName + ': an owner rule condition reads only ProjectProduct__c fields');
        }

        // US-20194: an invalid condition stops the PMT with a message naming its record (custom label PMT_InvalidCondition); the screens get the matrix through getForScreen()
        String invalidMessage;
        try {
            PMTMatrix.compileCondition(PMTFieldRuleLine__mdt.SObjectType, 'LEGFSISIN', 'ISPICKVAL(ProjectProduct__c.UnknownField__c, \'FCP\')');
        }
        catch (PMTCondition.PMTConditionException e) {
            invalidMessage = e.getMessage();
        }
        System.assert(invalidMessage != null && invalidMessage.contains('LEGFSISIN') && invalidMessage.contains(Schema.PMTFieldRuleLine__mdt.SObjectType.getDescribe().getLabel()), 'The error names the record to fix: ' + invalidMessage);
        PMTMatrix screenMatrix = PMTMatrix.getForScreen();
        System.assert(screenMatrix === matrix, 'getForScreen() returns the matrix of the transaction');

        // US-20194 V1.2: a line whose field is missing in the org is not used, and the PMT screens report it (custom label PMT_MissingFields)
        String noWarning = PMTMatrix.getMissingFieldsMessage();
        PMTMatrix.missingFieldLines = new List<String>{ 'RSKPFLiquidityManagementToolLMT (ProjectProductChild__c.LiquidityManagementToolLMT__c)' };
        String missingFieldWarning = PMTMatrix.getMissingFieldsMessage();
        System.assertEquals(null, noWarning, 'Every line field exists in this org: no warning');
        System.assert(missingFieldWarning.contains('RSKPFLiquidityManagementToolLMT (ProjectProductChild__c.LiquidityManagementToolLMT__c)'), 'The warning names the line and its missing field: ' + missingFieldWarning);
        PMTMatrix.missingFieldLines = new List<String>();

        // US-20194: ISIN__c is used by Legal (FR/IE + FCP/ICAV/FCPR/FCPE), by OPS (GB/LU + OEIC/SICAV), by nobody otherwise
        PMTMatrix frFcpMatrix = PMTMatrix.forProject(new ProjectProduct__c(DomiciledIn__c = 'FR', LegalForm__c = 'FCP'));
        PMTMatrix luSicavMatrix = PMTMatrix.forProject(new ProjectProduct__c(DomiciledIn__c = 'LU', LegalForm__c = 'SICAV'));
        PMTMatrix luFcpMatrix = PMTMatrix.forProject(new ProjectProduct__c(DomiciledIn__c = 'LU', LegalForm__c = 'FCP'));
        System.assertEquals('Legal', frFcpMatrix.getTeamByField().get('ISIN__c'), 'FR FCP fund: ISIN__c is a Legal field');
        System.assertEquals('OPS', luSicavMatrix.getTeamByField().get('ISIN__c'), 'LU SICAV fund: ISIN__c is an OPS field');
        System.assertEquals(null, luFcpMatrix.getTeamByField().get('ISIN__c'), 'LU FCP fund: nobody uses ISIN__c');

        // Project with two share classes (created with the deployed matrix), read in part 3
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        ProjectShareclass__c withPerfFees = PMTTestFactoryData.createProjectShareclass(project.Id, null);
        ProjectShareclass__c withoutPerfFees = PMTTestFactoryData.createProjectShareclass(project.Id, null);
        withPerfFees.HasPerfFees__c = 'True';
        withoutPerfFees.HasPerfFees__c = 'False';
        update new List<ProjectShareclass__c>{ withPerfFees, withoutPerfFees };
        Product__c liveFund = PMTTestFactoryData.getProduct(Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId(), 'LiveFund', 'Live Fund', true);
        liveFund.LegalForm__c = 'FCP';
        update liveFund;

        // 2. Test matrix: rules, validation teams and owner rules
        String suffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User fcpOwner = newUser('pmtfcp', suffix);
        User defaultOwner = newUser('pmtdef', suffix);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ fcpOwner, defaultOwner }; // Setup object: inserted apart from the project DML (mixed DML)
        }

        PMTTestFactoryData.clearMatrix();
        PMTMatrix emptyMatrix = PMTMatrix.get();
        System.assert(emptyMatrix.stages.isEmpty() && emptyMatrix.rules.isEmpty(), 'clearMatrix() empties the matrix');

        PMTTestFactoryData.createMatrice('Proposal', 'Legal', 'LegalForm__c', 'Type__c');
        PMTTestFactoryData.createMatrice('Proposal', 'Legal', 'DomiciledIn__c;LegalForm__c', null);
        PMTTestFactoryData.createMatrice('Filing', 'Risk', null, null);
        PMTTestFactoryData.createOwnerRule('Legal', null, defaultOwner.FederationIdentifier);
        PMTTestFactoryData.createOwnerRule('Legal', 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\')', fcpOwner.FederationIdentifier);
        PMTMatrix testMatrix = PMTMatrix.get();

        PMTMatrix.FieldRule legalProposal = testMatrix.getRule('Legal', 'Proposal');
        System.assertEquals(new List<String>{ 'LegalForm__c', 'DomiciledIn__c' }, legalProposal.requiredFund, 'Lines of the same team and stage are merged without duplicates');
        System.assertEquals(new List<String>{ 'LegalForm__c', 'DomiciledIn__c' }, testMatrix.getRequiredFieldsByStage(true).get('Proposal'), 'Required Fund fields of the stage');
        System.assertEquals(new List<String>{ 'Type__c' }, testMatrix.getRequiredFieldsByStage(false).get('Proposal'), 'Required Share Class fields of the stage');
        System.assertEquals('Legal', testMatrix.getTeamByField().get('Type__c'), 'Owning team of a Share Class field');
        System.assertEquals('Proposal', testMatrix.getStageByField('Legal').get('DomiciledIn__c'), 'Stage of a field for its team');
        System.assertEquals(new List<String>{ 'Legal', 'Risk' }, testMatrix.getTeamsWithoutFieldsByStage().get('Filing'), 'Validation teams without fields at the stage');
        System.assertEquals(2, testMatrix.getValidationTeams().size(), 'Teams added for tests are validation teams');
        System.assertEquals(new Set<String>{ 'LegalForm__c' }, testMatrix.getOwnerRuleFields(), 'Fields read by the owner rules');
        System.assertEquals(new Set<String>{ 'LegalForm__c' }, testMatrix.getOwnerRuleFields('Legal'), 'Fields read by the owner rules of a team');
        System.assert(testMatrix.getOwnerRuleFields('Risk').isEmpty(), 'A team without owner rule reads no field');

        System.assertEquals(fcpOwner.Id, testMatrix.getOwnerIdByTeam(new ProjectProduct__c(LegalForm__c = 'FCP')).get('Legal'), 'The first rule whose condition is true wins');
        System.assertEquals(defaultOwner.Id, testMatrix.getOwnerIdByTeam(new ProjectProduct__c(LegalForm__c = 'SICAV')).get('Legal'), 'A rule without condition always applies');
        System.assertEquals(fcpOwner.Id, testMatrix.getRuleOwnerIdByTeam(new ProjectProduct__c(LegalForm__c = 'FCP')).get('Legal'), 'Owner of an applicable rule');
        System.assert(!testMatrix.getRuleOwnerIdByTeam(new ProjectProduct__c()).containsKey('Risk'), 'No owner rule for a team without rule');

        // 3. US-20194: conditional lines - ISIN__c used by Legal for an FCP fund, MaxPerfFees__c by Risk on the share classes with performance fees
        PMTTestFactoryData.createMatrixLine('Filing', 'Legal', 'Share_Class__c', 'ISIN__c', 'Required', 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\')');
        PMTTestFactoryData.createMatrixLine('Filing', 'Risk', 'Share_Class__c', 'MaxPerfFees__c', 'Optional', 'ISPICKVAL(ProjectShareclass__c.HasPerfFees__c, \'True\')');
        PMTMatrix conditionalMatrix = PMTMatrix.get();
        System.assertEquals(new Set<String>{ 'LegalForm__c' }, conditionalMatrix.getConditionFields(), 'Project fields read by the conditions');
        System.assertEquals(new Set<String>{ 'HasPerfFees__c' }, conditionalMatrix.getShareClassConditionFields(), 'Share class fields read by the conditions');

        PMTMatrix fcpMatrix = conditionalMatrix.forConditions(new ProjectProduct__c(LegalForm__c = 'FCP'));
        PMTMatrix sicavMatrix = conditionalMatrix.forConditions(new ProjectProduct__c(LegalForm__c = 'SICAV'));
        System.assert(fcpMatrix === conditionalMatrix.forConditions(new ProjectProduct__c(LegalForm__c = 'FCP')), 'Projects with the same condition results share one matrix');
        System.assertEquals(new List<String>{ 'ISIN__c' }, fcpMatrix.getRule('Legal', 'Filing').requiredShareClass, 'The condition is true for an FCP fund: Legal uses ISIN__c');
        System.assert(sicavMatrix.getRule('Legal', 'Filing').isEmpty(), 'The condition is false for a SICAV: Legal has no field at Filing');
        System.assert(sicavMatrix.getTeamsWithoutFieldsByStage().get('Filing').contains('Legal'), 'Without field at Filing, Legal is validated automatically');
        System.assertEquals(new List<String>{ 'MaxPerfFees__c' }, sicavMatrix.getRule('Risk', 'Filing').optionalShareClass, 'A share class condition is kept at project level (it may apply to one of its share classes)');
        PMTMatrix psFcpMatrix = PMTMatrix.forProject(new ProjectProduct__c(Scope__c = 'PS', LegalForm__c = 'FCP'));
        System.assertEquals(new List<String>{ 'ISIN__c' }, psFcpMatrix.getRule('Legal', 'Filing').requiredShareClass, 'forProject(): Scope then conditions');

        // US-20194 V1.2: modification project whose LegalForm__c is selected (blanked until refilled): the conditions read the fund's real value
        Id modificationRtId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');
        PMTMatrix modificationMatrix = conditionalMatrix.forConditions(new ProjectProduct__c(RecordTypeId = modificationRtId, Product__c = liveFund.Id, TECH_FieldsToModify__c = 'LegalForm__c'));
        PMTMatrix blankCreationMatrix = conditionalMatrix.forConditions(new ProjectProduct__c(Product__c = liveFund.Id, TECH_FieldsToModify__c = 'LegalForm__c'));
        System.assertEquals(new List<String>{ 'ISIN__c' }, modificationMatrix.getRule('Legal', 'Filing').requiredShareClass, 'Modification: LegalForm__c read on the live fund (FCP), Legal keeps ISIN__c');
        System.assert(blankCreationMatrix.getRule('Legal', 'Filing').isEmpty(), 'Creation project: its own (blank) LegalForm__c is read');

        // US-20194 V1.2: Conditional lines are optional until resolved, then required when their RequiredCondition__c is true (only once their Condition__c applies)
        PMTTestFactoryData.createMatrixLine('Filing', 'Legal', 'Product__c', 'SFDRcategory__c', 'Conditional', null, 'NOT(ISPICKVAL(ProjectProduct__c.LegalForm__c, \'OEIC\'))');
        PMTTestFactoryData.createMatrixLine('Filing', 'Risk', 'Share_Class__c', 'PerformanceFeeEPTKID__c', 'Conditional', 'ISPICKVAL(ProjectShareclass__c.HasPerfFees__c, \'True\')', 'NOT(ISPICKVAL(ProjectProduct__c.LegalForm__c, \'OEIC\'))');
        PMTMatrix requirementMatrix = PMTMatrix.get();
        PMTMatrix oeicMatrix = requirementMatrix.forConditions(new ProjectProduct__c(LegalForm__c = 'OEIC'));
        PMTMatrix fcpRequirementMatrix = requirementMatrix.forConditions(new ProjectProduct__c(LegalForm__c = 'FCP'));
        System.assert(requirementMatrix.getRule('Legal', 'Filing').optionalFund.contains('SFDRcategory__c'), 'A Conditional line not evaluated yet is optional');
        System.assert(requirementMatrix.getRequirableFields(true).contains('SFDRcategory__c') && !requirementMatrix.getRequiredFields(true).contains('SFDRcategory__c'), 'A query built before evaluating the conditions selects the Conditional fields too');
        System.assert(fcpRequirementMatrix.getRule('Legal', 'Filing').requiredFund.contains('SFDRcategory__c'), 'Required condition true: required');
        System.assert(oeicMatrix.getRule('Legal', 'Filing').optionalFund.contains('SFDRcategory__c'), 'Required condition false: optional');
        System.assertEquals(new Map<String, Boolean>{ 'SFDRcategory__c' => true }, fcpRequirementMatrix.getTeamFieldStates('Legal', new Set<String>{ 'Filing' }, true), 'Fund fields of the Legal screen at Filing');
        System.assert(fcpRequirementMatrix.getTeamFieldStates('OPS', new Set<String>{ 'Filing' }, true).isEmpty(), 'A team without line has an empty screen');

        Test.startTest();

        Map<Id, ProjectProduct__c> projectById = PMTMatrix.loadProjects(new Set<Id>{ project.Id, null });

        Test.stopTest();

        System.assertEquals(2, projectById.get(project.Id).ProjectShareclasses__r.size(), 'loadProjects() reads the projects with their share classes');
        PMTMatrix projectMatrix = conditionalMatrix.forConditions(projectById.get(project.Id));
        System.assertEquals(new List<String>{ 'MaxPerfFees__c' }, projectMatrix.forShareClass(withPerfFees.Id).getRule('Risk', 'Filing').optionalShareClass, 'Share class with performance fees: Risk uses MaxPerfFees__c');
        System.assert(projectMatrix.forShareClass(withoutPerfFees.Id).getRule('Risk', 'Filing').isEmpty(), 'Share class without performance fees: Risk has no field');
        PMTMatrix requirementProjectMatrix = requirementMatrix.forConditions(projectById.get(project.Id));
        Map<String, Boolean> riskScreen = requirementProjectMatrix.forShareClass(withPerfFees.Id).getTeamFieldStates('Risk', new Set<String>{ 'Filing' }, false);
        Map<String, Boolean> riskScreenWithoutPerfFees = requirementProjectMatrix.forShareClass(withoutPerfFees.Id).getTeamFieldStates('Risk', new Set<String>{ 'Filing' }, false);
        System.assertEquals(new Map<String, Boolean>{ 'MaxPerfFees__c' => false, 'PerformanceFeeEPTKID__c' => true }, riskScreen, 'Share class with performance fees of a non-OEIC fund: PerformanceFeeEPTKID__c shown and required');
        System.assert(riskScreenWithoutPerfFees.isEmpty(), 'Condition__c false: the line counts nowhere, whatever its RequiredCondition__c');
        System.assert(projectMatrix.forShareClass(project.Id) === projectMatrix, 'An unknown share class keeps the project matrix');
        Map<Id, ProjectProduct__c> noProjectById = PMTMatrix.loadProjects(new Set<Id>());
        System.assert(noProjectById.isEmpty(), 'No project to read');
    }

    private static User newUser(String alias, String suffix) {
        Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String username = alias + suffix + '@pmtmatrix.test';
        return new User(Alias = alias, Email = username, Username = username, LastName = 'PMTMatrix', ProfileId = standardUser.Id,
                        FederationIdentifier = username, EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
                        LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Paris');
    }
}