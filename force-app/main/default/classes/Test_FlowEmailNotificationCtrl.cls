/** ──────────────────────────────────────
 * @description Tests of FlowEmailNotificationCtrl.getUsers (flow FL_PMT_EmailNotifications): teams to notify for the fields modified on
 *                  a project and its share class, from the PMT matrix.
 * @covers FlowEmailNotificationCtrl   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_FlowEmailNotificationCtrl {

    @isTest
    static void test_getUsers() {
        // FIX-20178: OPS owns the modified fields in the PMT matrix of this test
        PMTTestFactoryData.createMatrice('Proposal', 'OPS', 'ComplexityPS__c;NAVFrequency__c', 'DividendPolicy__c;MaxServiceFees__c');

        Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User opsUser = new User(
            FirstName = 'Test',
            LastName = 'OPS',
            Alias = 'tops',
            Email = 'testops@example.com',
            Username = 'testops' + DateTime.now().getTime() + '@example.com',
            ProfileId = standardUser.Id,
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert opsUser;

        // FIX-20178: the PMT stages always exist now (custom metadata), so the project structure is created and needs a start date
        ProjectProduct__c product = new ProjectProduct__c(ProjectStartDate__c = Date.today(), TECH_FieldsToModify__c = 'ComplexityPS__c;RecommendedHoldingPeriod__c', OPS__c = opsUser.Id);
        insert product;
        insert new ProjectShareclass__c(ProjectProduct__c = product.Id, TECH_FieldsToModify__c = 'DividendPolicy__c;DecimalsMaxAmount__c');
        FlowEmailNotificationCtrl.InputWrapper input = new FlowEmailNotificationCtrl.InputWrapper();
        input.recordId = product.Id;

        Test.startTest();

        List<FlowEmailNotificationCtrl.OutputWrapper> results = FlowEmailNotificationCtrl.getUsers(new List<FlowEmailNotificationCtrl.InputWrapper>{ input });

        Test.stopTest();

        System.assertEquals(1, results.size(), 'Une seule sortie attendue');
        System.assertNotEquals(null, results[0].teamNames, 'La liste teamNames ne doit pas être nulle');
        System.assert(results[0].teamNames.contains('OPS'), 'OPS devrait être dans les teams retournées');
    }
}