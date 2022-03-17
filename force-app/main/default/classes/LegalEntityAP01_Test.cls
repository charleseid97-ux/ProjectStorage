@isTest
public class LegalEntityAP01_Test {

    @testSetup static void setup() {
        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            SingleRequestMock fakeUMEResp = new SingleRequestMock(200, 'OK', 'jsonUMEStr', null);
            Test.setMock(HttpCalloutMock.class, fakeUMEResp);

            // Create Legal Entity
            Legal_Entity__c le = new Legal_Entity__c(Name = 'Test', LEI__c = '5067007V6269EHSP3295', TECH_brid__c = '5063007V6269EHOP329522');
            insert le;

            // Create Related Party Contact
            Related_Party_Contact__c kyc = new Related_Party_Contact__c (Name = 'testFirstname' + ' ' + 'testlastname', First_Name__c = 'testFirstname', Last_Name__c = 'testlastname', DateofBirth__c = date.newInstance(2016, 02, 20));
            Insert kyc;

            // Create Related Party Contact And Role
            Related_Party_Contact_Role__c contactRole = new Related_Party_Contact_Role__c(Legal_Entity__c = le.Id, Related_Party_Contact__c = kyc.id, Role__c = 'Board of directors');
            Insert contactRole;

        }
    }

    @isTest
    public static void createNewRoleOnly() {
        Test.startTest();

        Legal_Entity__c le = [SELECT Id FROM Legal_Entity__c LIMIT 1];

        Related_Party_Contact__c kyc = [SELECT Id, First_Name__c, Last_Name__c FROM Related_Party_Contact__c LIMIT 1];

        LegalEntityAP01.createRelatedPartyContactAndRole(le.id, kyc.First_Name__c, kyc.Last_Name__c, date.newInstance(2016, 02, 20), 'Board Member;Director;Ultimate Beneficial Own');

        Test.stopTest();
    }

    @isTest
    public static void createNewRoleAndContact() {
        Test.startTest();
        Legal_Entity__c le = [SELECT Id FROM Legal_Entity__c LIMIT 1];

        LegalEntityAP01.createRelatedPartyContactAndRole(le.id, 'Existing Name', 'Existing Last Name', date.newInstance(2016, 02, 20), 'Board of directors');

        Test.stopTest();
    }

}