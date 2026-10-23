/** ──────────────────────────────────────
 * @description Tests of the PMT Matrix Explorer controller: the model read from the deployed PMT custom metadata (every stage, team,
 *                  owner rule, field and line, a sharing status per field, the modifiable fields), then the rules on in-memory records:
 *                  sharing status of a field by team scope and conditions, and the errors of Condition__c and RequiredCondition__c.
 * @author Charles EID
 * @covers PMTMatrixExplorerController   99%   [23-10-26]
 ────────────────────────────────────── */
@isTest
private class PMTMatrixExplorerControllerTest {

    private static final String PROJECT_CONDITION = 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\')';
    private static final String SHARE_CLASS_CONDITION = 'ISPICKVAL(ProjectShareclass__c.HasPerfFees__c, \'True\')';

    @isTest
    static void test_getModel() {

        Test.startTest();

        PMTMatrixExplorerController.Model model = PMTMatrixExplorerController.getModel();

        Test.stopTest();

        System.assertEquals(PMTStage__mdt.getAll().size(), model.stages.size(), 'Every stage is read');
        System.assertEquals(PMTTeam__mdt.getAll().size(), model.teams.size(), 'Every team is read');
        System.assertEquals(PMTOwnerRule__mdt.getAll().size(), model.ownerRules.size(), 'Every owner rule is read');
        System.assertEquals(PMTField__mdt.getAll().size(), model.fields.size(), 'Every field is read, with or without lines');

        Integer lineCount = 0;
        Integer modifiableCount = 0;
        for (PMTMatrixExplorerController.Field field : model.fields) {
            System.assertNotEquals(null, field.sharingStatus, field.developerName + ': every field has a sharing status');
            System.assertEquals(field.lines.isEmpty(), field.sharingStatus == PMTMatrixExplorerController.UNUSED, field.developerName + ': only a field without lines is unused');
            lineCount += field.lines.size();
            if (field.isModifiable) modifiableCount++;
        }
        Integer expectedModifiableCount = 0;
        for (PMTField__mdt record : PMTField__mdt.getAll().values()) {
            if (record.IsModifiable__c) expectedModifiableCount++;
        }
        System.assertEquals(PMTFieldRuleLine__mdt.getAll().size(), lineCount, 'Every line is read under its field');
        System.assertEquals(expectedModifiableCount, modifiableCount, 'IsModifiable__c is read on every field');
    }

    @isTest
    static void test_rules() {
        // 1. Sharing status: teams of different scopes never apply together, teams whose lines all have a condition may exclude each other
        Map<String, PMTMatrixExplorerController.Team> teamByName = new Map<String, PMTMatrixExplorerController.Team>();
        for (PMTTeam__mdt record : new List<PMTTeam__mdt>{ new PMTTeam__mdt(MasterLabel = 'IS', Scope__c = 'IS'), new PMTTeam__mdt(MasterLabel = 'PS', Scope__c = 'PS'),
                                                           new PMTTeam__mdt(MasterLabel = 'Legal'), new PMTTeam__mdt(MasterLabel = 'OPS') }) {
            teamByName.put(record.MasterLabel, new PMTMatrixExplorerController.Team(record, null));
        }
        PMTMatrixExplorerController.Line isLine = buildLine('IS', 'Required', null, null);
        PMTMatrixExplorerController.Line psLine = buildLine('PS', 'Optional', null, null);
        PMTMatrixExplorerController.Line legalConditionalLine = buildLine('Legal', 'Required', PROJECT_CONDITION, null);
        PMTMatrixExplorerController.Line opsConditionalLine = buildLine('OPS', 'Required', 'NOT(' + PROJECT_CONDITION + ')', null);
        PMTMatrixExplorerController.Line opsLine = buildLine('OPS', 'Optional', null, null);
        System.assertEquals(PMTMatrixExplorerController.UNUSED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>(), teamByName), 'No line: unused');
        System.assertEquals(PMTMatrixExplorerController.SINGLE, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ isLine }, teamByName), 'One team: single');
        System.assertEquals(PMTMatrixExplorerController.SCOPE_SPLIT, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ isLine, psLine }, teamByName), 'IS and PS never apply to the same project');
        System.assertEquals(PMTMatrixExplorerController.CONDITION_SPLIT, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ legalConditionalLine, opsConditionalLine }, teamByName), 'Every line has a condition: condition split');
        System.assertEquals(PMTMatrixExplorerController.SHARED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ legalConditionalLine, opsLine }, teamByName), 'OPS always uses the field: shared');
        System.assertEquals(PMTMatrixExplorerController.SHARED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ isLine, psLine, opsLine }, teamByName), 'The most constraining pair of teams wins');

        // 2. Condition__c errors on a Fund line: compilation error, share class field read at project level
        System.assertEquals(null, legalConditionalLine.conditionError, 'A valid condition has no error');
        System.assertEquals(null, isLine.conditionError, 'An empty condition has no error');
        System.assertNotEquals(null, buildLine('OPS', 'Optional', 'NOT_A_FUNCTION(', null).conditionError, 'A condition that does not compile shows its error');
        System.assertEquals(PMTMatrixExplorerController.PROJECT_ONLY_ERROR, buildLine('OPS', 'Optional', SHARE_CLASS_CONDITION, null).conditionError, 'A Fund line condition reads only ProjectProduct__c fields');

        // 3. RequiredCondition__c: set exactly on the Conditional lines, then checked like a condition
        PMTMatrixExplorerController.Line conditionalLine = buildLine('Legal', 'Conditional', null, PROJECT_CONDITION);
        System.assert(conditionalLine.isConditional && !conditionalLine.isRequired && conditionalLine.requiredConditionError == null, 'A Conditional line with a valid RequiredCondition__c has no error');
        System.assertEquals(PMTMatrixExplorerController.MISSING_REQUIRED_CONDITION_ERROR, buildLine('Legal', 'Conditional', null, null).requiredConditionError, 'A Conditional line needs a RequiredCondition__c');
        System.assertEquals(PMTMatrixExplorerController.IGNORED_REQUIRED_CONDITION_ERROR, buildLine('Legal', 'Required', null, PROJECT_CONDITION).requiredConditionError, 'RequiredCondition__c is ignored on a line that is not Conditional');
        System.assertEquals(PMTMatrixExplorerController.PROJECT_ONLY_ERROR, buildLine('Legal', 'Conditional', null, SHARE_CLASS_CONDITION).requiredConditionError, 'A Fund line RequiredCondition__c reads only ProjectProduct__c fields');
    }

    // Fund line of a team at the Proposal stage, from an in-memory PMTFieldRuleLine__mdt record
    private static PMTMatrixExplorerController.Line buildLine(String team, String requirement, String condition, String requiredCondition) {
        PMTFieldRuleLine__mdt record = new PMTFieldRuleLine__mdt(DeveloperName = team + requirement, Requirement__c = requirement, Condition__c = condition, RequiredCondition__c = requiredCondition);
        return new PMTMatrixExplorerController.Line(record, team, 'Proposal', true);
    }
}
