/** ──────────────────────────────────────
 * @description Tests of PMTCondition: compilation of a condition (object prefixes, fields read, cache), evaluation at project and
 *                  share class level, rejected conditions (unknown field, picklist without ISPICKVAL, parent relationship), the projects
 *                  query, and the evaluation by a user with minimum access (PMT conditions are evaluated for every team).
 * @covers PMTCondition   100%   [21-10-26]
 * @author Charles EID
 ────────────────────────────────────── */
@isTest
private class PMTConditionTest {

    @isTest
    static void test_condition() {
        String text = 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\') && ISPICKVAL(ProjectShareclass__c.HasPerfFees__c, \'True\')';
        ProjectProduct__c fcpFund = new ProjectProduct__c(LegalForm__c = 'FCP');
        Profile minimumAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String username = 'pmtcondition' + System.currentTimeMillis() + '@pmtcondition.test';
        User minimumAccessUser = new User(Alias = 'pmtcond', Email = username, Username = username, LastName = 'PMT Condition', ProfileId = minimumAccess.Id,
                                          EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Paris');
        insert minimumAccessUser;

        Test.startTest();

        PMTCondition condition = PMTCondition.compile(text);
        PMTCondition projectCondition = PMTCondition.compile('ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\')');
        Boolean evaluatedWithMinimumAccess;
        System.runAs(minimumAccessUser) {
            evaluatedWithMinimumAccess = PMTCondition.compile('ISPICKVAL(ProjectProduct__c.DomiciledIn__c, \'LU\')').evaluate(new ProjectProduct__c(DomiciledIn__c = 'LU'), null);
        }

        Test.stopTest();

        System.assert(condition === PMTCondition.compile(text), 'A condition is compiled once per transaction');
        System.assertEquals(null, PMTCondition.compile(' '), 'An empty condition always applies (no condition)');
        System.assertEquals(new Set<String>{ 'LegalForm__c' }, condition.projectFields, 'Project fields read');
        System.assertEquals(new Set<String>{ 'HasPerfFees__c' }, condition.shareClassFields, 'Share class fields read');
        System.assert(condition.readsShareClass() && !projectCondition.readsShareClass(), 'A condition reading a share class field is evaluated per share class');

        System.assert(condition.evaluate(fcpFund, new ProjectShareclass__c(HasPerfFees__c = 'True')), 'FCP fund, share class with performance fees');
        System.assert(!condition.evaluate(fcpFund, new ProjectShareclass__c(HasPerfFees__c = 'False')), 'FCP fund, share class without performance fees');
        System.assert(!condition.evaluate(fcpFund, null), 'Project level: the share class fields are blank');
        System.assert(projectCondition.evaluate(fcpFund, null) && !projectCondition.evaluate(new ProjectProduct__c(LegalForm__c = 'SICAV'), null), 'Project condition');
        System.assert(evaluatedWithMinimumAccess, 'A user with minimum access evaluates the conditions');

        for (String invalid : new List<String>{ 'ISPICKVAL(ProjectProduct__c.UnknownField__c, \'FCP\')', 'ProjectProduct__c.LegalForm__c == \'FCP\'', 'ProjectProduct__c.RecordType.DeveloperName = \'FundCreation\'' }) {
            Boolean rejected = false;
            try {
                PMTCondition.compile(invalid);
            }
            catch (PMTCondition.PMTConditionException e) {
                rejected = e.getMessage().contains(invalid);
            }
            System.assert(rejected, 'Rejected with its text: ' + invalid);
        }

        System.assert(PMTCondition.queryProjects(new Set<Id>(), new Set<String>{ 'LegalForm__c', 'legalform__c', 'Scope__c' }, new Set<String>{ 'HasPerfFees__c' }).isEmpty(), 'Projects query without duplicate field');
    }
}