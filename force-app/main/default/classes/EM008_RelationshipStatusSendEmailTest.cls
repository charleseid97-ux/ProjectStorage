/** 
* @author Adolphe SONKO
* @date Creation 
* @date Modification 21/04/2017
* @description : EM008_RelationshipStatusSendEmail Unit Test Class 
*/

@isTest
public with sharing class EM008_RelationshipStatusSendEmailTest {
    
    
    public static final string TECH_ContactTechSUNID   = '4569872';
    public static final string TECH_WebSiteID       = '5483465';
    public static final string PROFESSIONAL_EMAIL     = 'ProfessionalEmailTU@carmignac.com';
    public static final string PERSONAL_EMAIL       = 'PersonalEmailTU@carmignac.com';
    public static final string TEAM_EMAIL         = 'TeamEmailTU@carmignac.com';
    
    public static final string TECH_ContactTechSUNID2   = '4569890';
    public static final string TECH_WebSiteID2       = '5483464';
    public static final string PROFESSIONAL_EMAIL2     = 'ProfessionalEmailTU2@carmignac.com';
    public static final string PERSONAL_EMAIL2       = 'PersonalEmailTU2@carmignac.com';
    public static final string TEAM_EMAIL2         = 'TeamEmailTU2@carmignac.com';
    
    // Test User creation
    public static User userTest = TestFactory.getCarmignacUserTestApex();
    
    
    static testMethod void testRelationshipStatusSendEmail(){
        
        
        system.runAs(userTest){                    
            
            TestFactory.createCustomSettings();
            //Data Preparation
            
            Account accountTest = TestFactory.getSimpleAccount();
            insert accountTest;
            Account accountTest2 = TestFactory.getSimpleGlobalAccount(); 
            insert accountTest2;
            Account account2 = TestFactory.getSimpleAccount();
            account2.GAM__c = accountTest2.id;
            insert account2;
            
            Contact contactTest = TestFactory.getSimpleNoProfileContact(accountTest.Id,'FirstNameTU', 'LastName1', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            insert contactTest;
            Contact contactTest2 = TestFactory.getSimpleNoProfileContact(accountTest.Id,'FirstNameTU2', 'LastName12', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
            
            RelationshipStatus__c rs = new RelationshipStatus__c(Company__c=accountTest.Id, Pricing__c = 'Good', Product__c='Very Good');
            RelationshipStatus__c rs2 = new RelationshipStatus__c(Company__c=account2.Id, GlobalAccount__c=accountTest2.Id, Pricing__c = 'Very Good', Product__c='Very Good');
            //     StrategicNews__c sn3 = new StrategicNews__c(Company__c=account2.Id, GlobalAccount__c=accountTest2.Id, Pricing__c = 'Very Good', Product__c='Very Good');
            
            // Test User creation
            User u = TestFactory.getStandardCarmignacUser();
            //   insert u;
            
            // Test Begin
            System.test.startTest();                  
            
            EM008_RelationshipStatusSendEmail.RelationshipStatus_EmailAlert1();
            EM008_RelationshipStatusSendEmail.RelationshipStatus_EmailAlert2(new Set<String>{accountTest2.Id});	 
            //      EM010_StrategicNewsSendEmail.StrategicNews_EmailAlert3(String.valueOf(accountTest.Id));
            
            List<Account> found_listAccounts =  EM010_StrategicNewsSendEmail.getListOfAccounts(new Set<String>{accountTest2.Id});
            //  List<Account> found_listAccounts2 =  EM010_StrategicNewsSendEmail.getAccountsByIds(new Set<String>{String.valueOf(accountTest.Id)});
            
            // Results verifications
            System.assertEquals(found_listAccounts.size(), 1);
            //	System.assertEquals(found_listAccounts2.size(), 1);
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            System.test.stopTest();
            
        }
        
        
    }
}