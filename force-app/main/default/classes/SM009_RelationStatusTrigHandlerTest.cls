/** 
* @author Adolphe SONKO
* @date Creation 
* @date Modification 17/09/2016
* @description : EM008_RelationshipStatusSendEmail Unit Test Class 
*/

@isTest
public class SM009_RelationStatusTrigHandlerTest {
    
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
    
    
    static testMethod void testRelationshipStatusSendEmail(){
        
        //Data Preparation
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
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
            Insert rs;
            RelationshipStatus__c rs2 = new RelationshipStatus__c(Company__c=account2.Id, GlobalAccount__c=accountTest2.Id, Pricing__c = 'Very Good', Product__c='Very Good');
            //	Insert rs2;
            RelationshipStatus__c rs3 = new RelationshipStatus__c(Company__c=account2.Id, Pricing__c = 'Critical', Product__c='Critical');
            Insert rs3;
            Insert rs2; 
            rs.Product__c = 'Good';
            Update rs;
            
            rs3.GlobalAccount__c = accountTest2.Id;
            Update rs3;
            
            // Results verifications
            System.assertEquals(rs3.GlobalAccount__c, accountTest2.Id);
            System.assertEquals(rs.Product__c, 'Good');
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        
        System.test.stopTest();
    }
}