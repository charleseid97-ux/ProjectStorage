@isTest
public class SM007_ContactTriggerHandlerTest {
    
    @isTest
    static void testBehavior() {
        Account a = new Account(Name='CompanyTest',
                               BusinessDevelopmentRegion__c='BP_FR',
                               Phone='+33111111111',
                               BillingCountry='France');
        insert a;
        
        Contact c = new Contact(LastName='Dupont',
                               AccountId=a.id,
                               JobFunction__c='Advisory',
                               CorporateTitle__c='Assistant',
                               Language__c='French',
                               Source__c='DOOR',
                               Phone='+33111111111',
                               Email='test@example.com',
                               TECH_WebSiteID__c='A');
        insert c;
        List<Contact> contactList = new List<Contact>{c};
        SM007_ContactTriggerHandler.onBeforeUpdateStatus(contactList);
        
        c.Source__c = 'Referral';
        update c;
        
        delete c;
    }
}