@isTest
private class BATCH020_AccountAddLegalEntityTest {

    @testSetup
    static void setup() {
        List<Account> accounts = new List<Account>();
        for (Integer i=0;i<10;i++) {
            accounts.add(new Account(name = 'Account ' + i, billingCity = 'Paris', billingCountry = 'France'));
        }
        insert accounts;
        
        List<Legal_Entity__c> legalEntities = new List<Legal_Entity__c>();
        for (Integer i=0;i<10;i++) {
            legalEntities.add(new Legal_Entity__c(Name='Legal Entity ' + i, Company__c = accounts[i].id));
        }
        insert legalEntities;
    }
    
    @isTest
    static void test() {
        Test.startTest();
        BATCH020_AccountAddLegalEntity batch020 = new BATCH020_AccountAddLegalEntity();
        Database.executeBatch(batch020);
        Test.stopTest();
        System.assertEquals(10, [SELECT count() from account where LegalEntity__c != null]);
    }
}