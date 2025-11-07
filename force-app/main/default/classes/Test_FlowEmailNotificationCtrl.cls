@isTest
public class Test_FlowEmailNotificationCtrl {
 
    @isTest
    static void testGetUsers() {
        ProductProjectSettings__c settings = new ProductProjectSettings__c(
            Team__c = 'OPS',
            RequiredFields__c = 'ComplexityPS__c;NAVFrequency__c',
            RequiredFieldsShareClass__c = 'DividendPolicy__c;MaxServiceFees__c',
            NonRequiredFieldsFund__c = 'RecommendedHoldingPeriod__c',
            NonRequiredFieldsShareClass__c = 'DecimalsMaxAmount__c'
        );
        insert settings;

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

        ProjectProduct__c product = new ProjectProduct__c(
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