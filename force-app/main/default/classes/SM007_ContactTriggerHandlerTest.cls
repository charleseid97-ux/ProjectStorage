/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 04-05-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
public class SM007_ContactTriggerHandlerTest {
    
    @isTest
    static void testBehavior() {
        Account a = new Account(Name='CompanyTest',
                               BusinessDevelopmentRegion__c='BP_FR',
                               Phone='+33111111111',
                               BillingCountry='France');
        insert a;
        Test.startTest();
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
        c.HasOptedOutOfEmail = true;        
        c.EmailBouncedReason = ' 5.1.0 Test Pardot';
        c.Newsletter_Opt_Out__c = true;
        c.HardBounced_Mandrill_Reason__c = '5.1.0 Test Prospace';
        c.To_Delete__c = true;
        c.GDPR_external_request_for_data_deletion__c = true;
        c.ContactStatus__c = 'false';
        update c;
       
         
        delete c;
        Test.stopTest();
        
    }
    
    @isTest
    static void testBehavior2() {
        Account ab = new Account(Name='CompanyTestB',
                               BusinessDevelopmentRegion__c='BP_FR',
                               Phone='+331111123411',
                               BillingCountry='France');
        insert ab;
        Test.startTest();
          
        Contact b = new Contact(LastName='TestB',
                               AccountId=ab.id,
                               JobFunction__c='Advisory',
                               CorporateTitle__c='Assistant',
                               To_Delete__c = true,
                               Language__c='French',
                               Source__c='DOOR',
                               Phone='+331111113111',
                               Email='testB@exam3ple.com',
                               TECH_WebSiteID__c='AB');

        insert b;
        b.pi__pardot_hard_bounced__c = true;
        update b;
        Test.stopTest();
        
    }
     @isTest
    static void testBehavior3() {
        Account ab = new Account(Name='CompanyTestB',
                               BusinessDevelopmentRegion__c='BP_FR',
                               Phone='+331111123411',
                               BillingCountry='France');
        insert ab;
        Test.startTest();
          
        Contact b = new Contact(LastName='TestBB',
                               AccountId=ab.id,
                               JobFunction__c='Advisory',
                               CorporateTitle__c='Assistant',
                               Language__c='French',
                                HasOptedOutOfEmail= true,
                               Source__c='DOOR',
                               Phone='+3311111131112',
                               Email='testB@exam33ple.com',
                               TECH_WebSiteID__c='AB');

        insert b;
        b.HardBounced_Mandrill__c = true;
        
        update b;
        Test.stopTest();
        
    }
    
}