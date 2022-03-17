/** 
* @author Adolphe SONKO
* @date Creation 12/04/2017
* @date Modification 12/04/2017
* @description : SM012_TaskTriggerHandler Test Unit Test Class 
*/

@isTest
public class SM013_EventTriggerHandlerTest {
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
    
    static testMethod void getOnBeforeInsert() {
        
        
        
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
            Event event = new Event(ActivityDateTime=DateTime.valueOf('2016-04-17 10:12:01'), WhoId=contact.Id, Subject='Test the OnAfterInsert Trigger', Type='Call', DurationInMinutes=15);
            insert event;
            
            System.debug('ASO Task '+event.WhatId);
            // Results verification
            //    System.assertEquals(event.WhatId, account.Id);
            
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
            Event event = new Event(ActivityDateTime=DateTime.valueOf('2016-04-17 10:12:01'), WhoId=contact.Id, Subject='Test the OnAfterInsert Trigger', Type='Call', DurationInMinutes=15);
            insert event;
            event.WhatId=null;
            update event;
            
            event.WhoId = contact2.Id;
            event.WhatId=account.Id;
            update event;
            
            
            System.debug('ASO Task '+event.WhatId);
            // Results verification
            //   System.assertEquals(event.WhatId, account.Id);
            
            // Governer limits tests
            //System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
}