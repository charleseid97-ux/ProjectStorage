/** 
* @author Adolphe SONKO
* @date Creation 
* @date Modification 21/04/2017
* @description : EM003_Communication Unit Test Class 
*/

@isTest
public class SM010_StrategicNewsTriggerHandlerTest {
    
    public static final string TECH_ContactTechSUNID    = '4569872';
    public static final string TECH_WebSiteID           = '5483465';
    public static final string PROFESSIONAL_EMAIL       = 'ProfessionalEmailTU@carmignac.com';
    public static final string PERSONAL_EMAIL           = 'PersonalEmailTU@carmignac.com';
    public static final string TEAM_EMAIL               = 'TeamEmailTU@carmignac.com';
    
    public static final string TECH_ContactTechSUNID2   = '4569890';
    public static final string TECH_WebSiteID2          = '5483464';
    public static final string PROFESSIONAL_EMAIL2      = 'ProfessionalEmailTU2@carmignac.com';
    public static final string PERSONAL_EMAIL2          = 'PersonalEmailTU2@carmignac.com';
    public static final string TEAM_EMAIL2              = 'TeamEmailTU2@carmignac.com';
    
    
    static testMethod void testStrategicNewsAfterInsert(){
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //Data Preparation
            
            
            
            Account accountTest = TestFactory.getSimpleAccount();
            insert accountTest;
            Account accountTest2 = TestFactory.getSimpleGlobalAccount(); 
            insert accountTest2;
            Account account2 = TestFactory.getSimpleAccount();
            //   account2.GAM__c = accountTest2.id;
            insert account2;
            
            Contact contactTest = TestFactory.getSimpleNoProfileContact(accountTest.Id,'FirstNameTU', 'LastName1', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            insert contactTest;
            Contact contactTest2 = TestFactory.getSimpleNoProfileContact(accountTest.Id,'FirstNameTU2', 'LastName12', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
            
            StrategicNews__c sn = new StrategicNews__c(Company__c=accountTest.Id, Type__c = 'AGREEMENT & NEGOTIATION', ShortSubjectDescription__c='SN1 Test');
            StrategicNews__c sn2 = new StrategicNews__c(Company__c=account2.Id, GlobalAccount__c=accountTest2.Id, Type__c = 'AGREEMENT & NEGOTIATION', ShortSubjectDescription__c='SN2 Test');
            StrategicNews__c sn3 = new StrategicNews__c(Company__c=account2.Id, GlobalAccount__c=accountTest2.Id, Type__c = 'PRODUCT/ BUY LIST', ShortSubjectDescription__c='SN3 Test');
            
            insert sn;
            insert sn2;
            insert sn3;
            
            // test
            //  System.assertEquals(251,leadtest.Technical_ID__c);
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        
        System.test.stopTest();
        
    }
}