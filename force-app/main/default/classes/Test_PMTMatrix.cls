@isTest
private class Test_PMTMatrix {

    @isTest
    static void test_matrix() {
        // 1. Configuration loaded from the PMT custom metadata records, once per transaction
        PMTMatrix matrix = PMTMatrix.get();
        System.assert(matrix === PMTMatrix.get(), 'The matrix is loaded once per transaction');

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

        // 2. Test matrix: rules, validation teams and owner rules
        String suffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User fcpOwner = newUser('pmtfcp', suffix);
        User defaultOwner = newUser('pmtdef', suffix);
        insert new List<User>{ fcpOwner, defaultOwner };

        PMTMatrix.clearForTest();
        System.assert(PMTMatrix.get().stages.isEmpty() && PMTMatrix.get().rules.isEmpty(), 'clearForTest() empties the matrix');

        PMTMatrix.addRuleForTest('Proposal', 'Legal', new List<String>{ 'LegalForm__c' }, new List<String>{ 'Type__c' });
        PMTMatrix.addRuleForTest('Proposal', 'Legal', new List<String>{ 'DomiciledIn__c', 'LegalForm__c' }, null);
        PMTMatrix.addRuleForTest('Filing', 'Risk', null, null);
        PMTMatrix.addOwnerRuleForTest('Legal', 'LegalForm__c', new List<String>{ 'FCP' }, fcpOwner.FederationIdentifier);
        PMTMatrix.addOwnerRuleForTest('Legal', 'LegalForm__c', null, defaultOwner.FederationIdentifier);
        PMTMatrix testMatrix = PMTMatrix.get();

        PMTMatrix.FieldRule legalProposal = testMatrix.getRule('Legal', 'Proposal');
        System.assertEquals(new List<String>{ 'LegalForm__c', 'DomiciledIn__c' }, legalProposal.requiredFund, 'Rules of the same team and stage are merged without duplicates');
        System.assertEquals(new List<String>{ 'LegalForm__c', 'DomiciledIn__c' }, testMatrix.getRequiredFieldsByStage(true).get('Proposal'), 'Required Fund fields of the stage');
        System.assertEquals(new List<String>{ 'Type__c' }, testMatrix.getRequiredFieldsByStage(false).get('Proposal'), 'Required Share Class fields of the stage');
        System.assertEquals('Legal', testMatrix.getTeamByField().get('Type__c'), 'Owning team of a Share Class field');
        System.assertEquals('Proposal', testMatrix.getStageByField('Legal').get('DomiciledIn__c'), 'Stage of a field for its team');
        System.assertEquals(new List<String>{ 'Legal', 'Risk' }, testMatrix.getTeamsWithoutFieldsByStage().get('Filing'), 'Validation teams without fields at the stage');
        System.assertEquals(2, testMatrix.getValidationTeams().size(), 'Teams added for tests are validation teams');
        System.assertEquals(new Set<String>{ 'LegalForm__c' }, testMatrix.getOwnerRuleFields(), 'Fields read by the owner rules');
        System.assertEquals(new Set<String>{ 'LegalForm__c' }, testMatrix.getOwnerRuleFields('Legal'), 'Fields read by the owner rules of a team');
        System.assert(testMatrix.getOwnerRuleFields('Risk').isEmpty(), 'A team without owner rule reads no field');

        System.assertEquals(fcpOwner.Id, testMatrix.getOwnerIdByTeam(new ProjectProduct__c(LegalForm__c = 'FCP')).get('Legal'), 'The rule matching the value wins');
        System.assertEquals(defaultOwner.Id, testMatrix.getOwnerIdByTeam(new ProjectProduct__c(LegalForm__c = 'SICAV')).get('Legal'), 'Any other value takes the fallback rule');
        System.assertEquals(null, testMatrix.getOwnerIdByTeam(new ProjectProduct__c()).get('Legal'), 'An empty field keeps the team default owner (none here)');
        System.assertEquals(fcpOwner.Id, testMatrix.getRuleOwnerIdByTeam(new ProjectProduct__c(LegalForm__c = 'FCP')).get('Legal'), 'Owner of an applicable rule');
        System.assert(!testMatrix.getRuleOwnerIdByTeam(new ProjectProduct__c()).containsKey('Legal'), 'No applicable rule when the field is empty');
    }

    private static User newUser(String alias, String suffix) {
        Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String username = alias + suffix + '@pmtmatrix.test';
        return new User(Alias = alias, Email = username, Username = username, LastName = 'PMTMatrix', ProfileId = standardUser.Id,
                        FederationIdentifier = username, EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
                        LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Paris');
    }
}
