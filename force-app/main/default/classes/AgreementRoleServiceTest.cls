/**
 * Created by noorgoolamnabee on 10/01/2022.
 */

@IsTest
private class AgreementRoleServiceTest {
    public static testMethod void testUniqueness() {
        List<KYD_Document__c> docList = new List<KYD_Document__c>();
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            //create test data
            SingleRequestMock fakeUMEResp = new SingleRequestMock(200, 'OK', 'jsonUMEStr', null);
            Test.setMock(HttpCalloutMock.class, fakeUMEResp);

            Legal_Entity__c testLegalEnity = TestFactory.getLegalEntity();
            insert testLegalEnity;
            
            Account testAcc = TestFactory.getSimpleAccount();
            testAcc.BillingPostalCode = '439955';
            testAcc.BillingStreet = 'Road 12344';
            testAcc.BillingCity = 'Paris';
            testAcc.recordtypeId = ObjectUtil.getRecordTypeId('Account', 'Distributor');
            testAcc.LegalEntity__c = testLegalEnity.id;
            insert testAcc;            

            Grid__c grid = TestFactory.getGrid();
            insert grid;

            Convention__c masterAgreement = TestFactory.getAgreement(testAcc.Id, grid.Id);
            insert masterAgreement;

            Test.startTest();
            try {

                Agreement_Role__c role = TestFactory.getAgreementRole(masterAgreement.id, testLegalEnity.Id);
                insert role;
            }catch (DmlException e){

                System.assert(e.getMessage().contains(Label.VR01_AGREEMENT_ROLE_UNIQUENESS));
            }

            Test.StopTest();
        }
    }

    public static testMethod void testOthers() {

        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            //create test data
            SingleRequestMock fakeUMEResp = new SingleRequestMock(200, 'OK', 'jsonUMEStr', null);
            Test.setMock(HttpCalloutMock.class, fakeUMEResp);

            Legal_Entity__c testLegalEnity = TestFactory.getLegalEntity();
            insert testLegalEnity;
            
            Account testAcc = TestFactory.getSimpleAccount();
            testAcc.BillingPostalCode = '439955';
            testAcc.BillingStreet = 'Road 12344';
            testAcc.BillingCity = 'Paris';
            testAcc.recordtypeId = ObjectUtil.getRecordTypeId('Account', 'Distributor');
            testAcc.LegalEntity__c = testLegalEnity.id;
            insert testAcc;

            Grid__c grid = TestFactory.getGrid();
            insert grid;

            Convention__c masterAgreement = TestFactory.getAgreement(testAcc.Id, grid.Id);
            insert masterAgreement;

            Test.startTest();
            try {

                List<Agreement_Role__c> roles = [SELECT Id FROM Agreement_Role__c];
                if (roles.size() > 0) {
                    roles[0].Role__c = 'Investment Advisor';
                	update roles[0];
                	delete roles[0];
                }
            }catch (DmlException e){

                System.assert(e.getMessage().contains(Label.VR01_AGREEMENT_ROLE_UNIQUENESS));
            }

            Test.StopTest();
        }
    }
}