@isTest
public class Test_FlowEmailNotificationCtrl {
 
    @isTest
    static void testGetUsers() {
        // FIX-20178: OPS owns the modified fields in the PMT matrix of this test
        PMTTestFactoryData.createMatrice('Proposal', 'OPS', 'ComplexityPS__c;NAVFrequency__c', 'DividendPolicy__c;MaxServiceFees__c');

        User opsUser = new User(
            FirstName = 'Test',
            LastName = 'OPS',
            Alias = 'tops',
            Email = 'testops@example.com',
            Username = 'testops' + DateTime.now().getTime() + '@example.com',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert opsUser;

        // FIX-20178: the PMT stages always exist now (custom metadata), so the project structure is created and needs a start date
        ProjectProduct__c product = new ProjectProduct__c(
            ProjectStartDate__c = Date.today(),
            TECH_FieldsToModify__c = 'ComplexityPS__c;RecommendedHoldingPeriod__c',
            OPS__c = opsUser.Id
        );
        insert product;

        ProjectShareclass__c shareClass = new ProjectShareclass__c(
            ProjectProduct__c = product.Id,
            TECH_FieldsToModify__c = 'DividendPolicy__c;DecimalsMaxAmount__c'
        );
        insert shareClass;

        FlowEmailNotificationCtrl.InputWrapper input = new FlowEmailNotificationCtrl.InputWrapper();
        input.recordId = product.Id;

        List<FlowEmailNotificationCtrl.InputWrapper> inputs = new List<FlowEmailNotificationCtrl.InputWrapper>{ input };
        Test.startTest();
        List<FlowEmailNotificationCtrl.OutputWrapper> results = FlowEmailNotificationCtrl.getUsers(inputs);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Une seule sortie attendue');
        FlowEmailNotificationCtrl.OutputWrapper output = results[0];

        System.assertNotEquals(null, output.teamNames, 'La liste teamNames ne doit pas être nulle');
        System.assert(output.teamNames.contains('OPS'), 'OPS devrait être dans les teams retournées');
    }

}