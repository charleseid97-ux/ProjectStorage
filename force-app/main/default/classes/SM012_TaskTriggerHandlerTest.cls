/** 
* @author Adolphe SONKO
* @date Creation 12/04/2017
* @date Modification 12/04/2017
* @description : SM012_TaskTriggerHandler Test Unit Test Class 
*/

@isTest
public class SM012_TaskTriggerHandlerTest {
    
    public static final String TECH_ContactTechSUNID = '4569872';
    public static final String TECH_WebSiteID = '5483465';
    public static final String PROFESSIONAL_EMAIL = 'ProfessionalEmailTU@carmignac.com';
    public static final String PERSONAL_EMAIL = 'PersonalEmailTU@carmignac.com';
    public static final String TEAM_EMAIL = 'TeamEmailTU@carmignac.com';
    
    public static final String TECH_ContactTechSUNID2 = '4569890';
    public static final String TECH_WebSiteID2 = '5483464';
    public static final String PROFESSIONAL_EMAIL2 = 'ProfessionalEmailTU2@carmignac.com';
    public static final String PERSONAL_EMAIL2 = 'PersonalEmailTU2@carmignac.com';
    public static final String TEAM_EMAIL2 = 'TeamEmailTU2@carmignac.com';
    
    static testMethod void getTaskTest() {
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            Account account = TestFactory.getSimpleAccount();
            Insert account;
            Contact contact = TestFactory.getSimpleNoProfileContact(account.Id,'FirstNameTU', 'LastNameTU', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            Insert contact;
            Task task = new Task(ActivityDate=Date.valueOf('2016-04-17'), WhoId=contact.Id, Subject='Test the OnAfterInsert Trigger', Type='Email');
            insert task;
            
            System.debug('ASO Task '+task.WhatId);
            // Results verification
            //  System.assertEquals(task.WhatId, account.Id);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void getOnBeforeUpdate() {
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            Account account = TestFactory.getSimpleAccount();
            Insert account;
            Contact contact = TestFactory.getSimpleNoProfileContact(account.Id,'FirstNameTU', 'LastNameTU', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            Insert contact;
            Contact contact2 = TestFactory.getSimpleContactToSetProfile(account.Id,'FirstNameTest', 'LastNameTest', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
            Insert contact2;
            Task task = new Task(ActivityDate=Date.valueOf('2016-04-18'),  WhoId=contact.Id, Subject='Test the OnBeforeUpdate Trigger', Type='Email');
            insert task;
            task.WhatId=null;
            update task;
            
            task.WhoId = contact2.Id;
            task.WhatId=account.Id;
            update task;
            
            
            System.debug('ASO Task '+task.WhatId);
            // Results verification
            //   System.assertEquals(task.WhatId, account.Id);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
}