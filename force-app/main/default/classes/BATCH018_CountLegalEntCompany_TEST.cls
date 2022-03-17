@IsTest
public with sharing class BATCH018_CountLegalEntCompany_TEST
{
    @TestSetup
    private static void setup()
    {
        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            SingleRequestMock fakeUMEResp = new SingleRequestMock(200, 'OK', 'jsonUMEStr', null);
            Test.setMock(HttpCalloutMock.class, fakeUMEResp);
            
            Account testAcc = TestFactory.getSimpleAccount();
            testAcc.BillingPostalCode = '439955';
            testAcc.BillingStreet = 'Road 12344';
            testAcc.BillingCity = 'Paris';
            testAcc.recordtypeId = ObjectUtil.getRecordTypeId('Account', 'Distributor');
            insert testAcc;
            
            List<Legal_Entity__c> lgs = new List<Legal_Entity__c>{TestFactory.getLegalEntity(testAcc.Id), TestFactory.getLegalEntity(testAcc.Id)};
            insert lgs;


        }
    }

    @IsTest
    public static void testBehavior()
    {

        BATCH018_CountLegalEntCompany batch = new BATCH018_CountLegalEntCompany();

        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        System.assertNotEquals(0, [SELECT Id, Number_Of_Legal_Entities__c FROM Account where Number_Of_Legal_Entities__c != NULL].size());
    }
}