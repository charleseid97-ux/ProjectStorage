/**
* @author BGU
* @date Creation 21/04/2017
* @date Modification 21/04/2017
* @description : SM004_ContactTriggerHandlerTest Unit Test Class 
*/


@isTest
public class SM004_ContactTriggerHandlerTest {
    
    private static User userTest = TestFactory.getStandardCarmignacUser();
    
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
    
    static testMethod void onBeforeInsert(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //   insert u;
            Id_Tech_Sun_Legacy__c setting = new Id_Tech_Sun_Legacy__c (
                Sun_ID__c =250 
                ,Name='Sun_ID'
                
            );
            
            Account accountTest = TestFactory.getSimpleAccount();
            insert accountTest;
            Contact contactTest = TestFactory.getSimpleNoProfileContact(accountTest.Id,'FirstNameTU', 'LastName1', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            contactTest.WebsiteCountry__c = 'FR';
            contactTest.WebsiteLanguage__c = 'French';
            insert contactTest;
            //Lead leadtest = TestFactory.getSimpleLead();
            Contact contactTest2 = TestFactory.getSimpleNoProfileContact(accountTest.Id,'FirstNameTU2', 'LastName12', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
            
            insert setting;
            
            // contactTest2.Technical_ID__c = null;
            contactTest2.WebsiteRole__c = '5';
            contactTest2.TrialStatus__c = '5';
            contactTest2.WebsiteCountry__c = 'FR';
            contactTest2.WebsiteLanguage__c = 'French';
            insert contactTest2;
            
            contactTest.PostalCode__c = '75010';
            update contactTest;
            
            /*
List<Lead> tempList = new List<Lead>();

tempList.add(leadtest);

SM017_LeadTriggerHandler.onBeforeInsert(tempList);

// test
System.assertEquals(251,leadtest.Technical_ID__c);
// Governer limits tests
System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
*/
            
        }
        
        System.test.stopTest();
        
    }
    
    static testMethod void onBeforeUpdate(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            
            TestFactory.createCustomSettings();
            //Status code != 200
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact1.WebsiteRole__c = '5';
            testContact1.TrialStatus__c = '5';
            testContact1.WebsiteCountry__c = 'FR';
            testContact1.WebsiteLanguage__c = 'French';
            insert testContact1;
            
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234567');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            
            testContact1.TrialStatus__c = '1';
            update testContact1;
            
           
        }
        
        
        // Test End 
        
        System.test.stopTest(); 
        
        
        //repeat the same for the rest of classes.
    }  
    
    static testMethod void onBeforeUpdate_forList_Condition1(){
        
        List<Contact> listContact = new List<Contact>();
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            
            TestFactory.createCustomSettings();
            //Status code != 200
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact1.Email = 'fabien.Aurelien@jlconsulting.fr';
            testContact1.LastName = 'FranchiTEST';
            testContact1.Firstname = 'Aurélien';
            testContact1.WebsiteRole__c = '1';
            //testContact1.TrialStatus__c = '5';
            testContact1.TECH_WhichWebService__c = '';
            testContact1.WebsiteCountry__c = 'FR';
            testContact1.WebsiteLanguage__c = 'French';
            listContact.add(testContact1);
            
            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName2','LastNameTestCarmignac2','654323452','TechwbesiteId2','mail@mail2.com','mail@mail2.com','mail@mail2.com');
            testContact2.LastName = 'BraconnierTEST';
            testContact2.Firstname = 'Fabien';
            testContact2.WebsiteRole__c = '1';
            //testContact2.TrialStatus__c = '5';
            testContact2.WebsiteCountry__c = 'FR';
            testContact2.WebsiteLanguage__c = 'French';
            testContact2.TECH_WhichWebService__c = '';
            
            listContact.add(testContact2);
            
            insert listContact;
            
            List<Contact> contactsToBeSync = new List<Contact>();
            Contact SyncContact = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName62','LastNameTestCarmignac6','654383452','TechwbesiteId254','mail4@mail2.com','mail4@mail2.com','mail4@mail2.com');
            SyncContact.LastName = 'SyncTEST';
            SyncContact.Firstname = 'Sync';
            SyncContact.WebsiteRole__c = '1';
            SyncContact.TECH_WhichWebService__c = '';
            SyncContact.Synchrostatus__c='To be synced';
            SyncContact.WebsiteCountry__c = 'FR';
            SyncContact.WebsiteLanguage__c = 'French';
            contactsToBeSync.add(SyncContact);
            insert contactsToBeSync;
             
         //  SM007_ContactTriggerHandler.onBeforeInsert(contactsToBeSync); 
         //  
            SM026_SendSelectedContactsAsync contAsync = new SM026_SendSelectedContactsAsync(contactsToBeSync, 0 , 1);
            contAsync.executeNext(contactsToBeSync, 0 , 1);
        
            SM026_DeleteWebsiteContactsAsync contDelAsync = new SM026_DeleteWebsiteContactsAsync(contactsToBeSync, 0 , 1);
            contDelAsync.executeNext(contactsToBeSync, 0 , 1);
                

            
          
            
           
            
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234567');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            
            List<Contact> listContactupdated = [SELECT id, TECH_WhichWebService__c, WebsiteRole__c, WebsiteJobTitle__c from contact where lastname in ('BraconnierTEST','FranchiTEST')];
			for(Contact c : listContactupdated){
    			c.WebsiteRole__c = '5';
    
    			c.ContactStatus__c = 'false';
			}

			update listContactupdated;
            //Id batchJobId = Database.executeBatch(new Batch_WSCreateContact(), 2);
        }
        // Test End 
        System.test.stopTest(); 
        
        
        
        //repeat the same for the rest of classes.
    }  
    
        static testMethod void onBeforeUpdate_forList_Condition2_1(){
        
        List<Contact> listContact = new List<Contact>();
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            
            TestFactory.createCustomSettings();
            //Status code != 200
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact1.Email = 'fabien.Aurelien@jlconsulting.fr';
            testContact1.LastName = 'FranchiTEST';
            testContact1.Firstname = 'Aurélien';
            testContact1.WebsiteRole__c = '5';
            testContact1.WebsiteJobTitle__c = 'ANCIEN';
            testContact1.TrialStatus__c = '5';
            testContact1.TECH_WhichWebService__c = '';
            testContact1.WebsiteCountry__c = 'FR';
            testContact1.WebsiteLanguage__c = 'French';
            listContact.add(testContact1);
            
            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName2','LastNameTestCarmignac2','654323452','TechwbesiteId2','mail@mail2.com','mail@mail2.com','mail@mail2.com');
            testContact2.LastName = 'BraconnierTEST';
            testContact2.Firstname = 'Fabien';
            testContact2.WebsiteRole__c = '5';
            testContact2.WebsiteJobTitle__c = 'ANCIEN';
            testContact2.TrialStatus__c = '5';
            testContact2.TECH_WhichWebService__c = '';
            testContact2.WebsiteCountry__c = 'FR';
            testContact2.WebsiteLanguage__c = 'French';
            listContact.add(testContact2);
            
            insert listContact;
            
            
            
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234567');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            
            List<Contact> listContactupdated = [SELECT id, TECH_WhichWebService__c, WebsiteRole__c, WebsiteJobTitle__c from contact where lastname in ('BraconnierTEST','FranchiTEST')];
			for(Contact c : listContactupdated){
    			//c.WebsiteRole__c = '5';
    			c.WebsiteJobTitle__c = 'NOUVEAU';
    			//c.ContactStatus__c = 'false';
                c.TrialStatus__c = '1';
			}

			update listContactupdated;
            //Id batchJobId = Database.executeBatch(new Batch_WSCreateContact(), 2);
        }
        // Test End 
        System.test.stopTest(); 
        
        
        
        //repeat the same for the rest of classes.
    }
    
    
    static testMethod void onBeforeDelete(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //Data Preparation
            
            
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact1.WebsiteCountry__c = 'FR';
            testContact1.WebsiteLanguage__c = 'French';
            insert testContact1;
            
            //     update testContact1;
            
            delete testContact1;
            
           }
        // Test End 
        System.test.stopTest(); 
        
        
        
        //repeat the same for the rest of classes.
    }
  static testMethod void contactWebsiteFields(){
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            
            TestFactory.createCustomSettings();
            
            Account accTest1 = TestFactory.getSimpleAccount();
            insert accTest1;
            
            List<Contact> ContactFieldtoPopulate = new List<Contact>();

            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accTest1.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact2.WebsiteRole__c = '5';
            testContact2.TrialStatus__c = '5';
            testContact2.Synchrostatus__c='To be synced';
            testContact2.FirstNameWebsite__c='testWebsiteFirstname';
            testContact2.LastNameWebsite__c='testWebsitelastame';
            testContact2.WebsiteCompany__c='testWebsitecompany';
            testContact2.WebsiteSalutation__c='testWebsiteSalutation';
            testContact2.WebsiteJobTitle__c='testWebsiteJob';
            testContact2.WebsiteLogin__c='testWebsiteLogin@test.com';
            testContact2.PostalCode__c='25624';
            testContact2.PhoneNumber__c='0123456789';
            testContact2.MobileNumber__c='0123456787';
            testContact2.Address1__c='TestAddress';
            testContact2.City__c='TestCity';
            testContact2.Country__c='FR';
            testContact2.WebsiteCountry__c = 'FR';
            testContact2.WebsiteLanguage__c = 'French';

            ContactFieldtoPopulate.add(testContact2);

            insert ContactFieldtoPopulate;

        
        SM026_Contact_Website.processResetContactPassword(ContactFieldtoPopulate);
      
        }
        // Test End 
        
        System.test.stopTest();
        //repeat the same for the rest of classes.
    }  
 static testMethod void ContactWebsiteButtonController(){
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            
            TestFactory.createCustomSettings();
            Account accTest1 = TestFactory.getSimpleAccount();
            insert accTest1;
            
            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accTest1.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact2.WebsiteRole__c = '5';
            testContact2.TrialStatus__c = '5';
            testContact2.Synchrostatus__c='Success';
            testContact2.FirstNameWebsite__c='testWebsiteFirstname';
            testContact2.LastNameWebsite__c='testWebsitelastame';
            testContact2.WebsiteCompany__c='testWebsitecompany';
            testContact2.WebsiteSalutation__c='testWebsiteSalutation';
            testContact2.WebsiteJobTitle__c='testWebsiteJob';
            testContact2.WebsiteLogin__c='testWebsiteLogin@test.com';
            testContact2.PostalCode__c='25624';
            testContact2.PhoneNumber__c='0123456789';
            testContact2.MobileNumber__c='0123456787';
            testContact2.Address1__c='TestAddress';
            testContact2.City__c='TestCity';
            testContact2.Country__c='FR';
            testContact2.WebsiteCountry__c = 'FR';
            testContact2.WebsiteLanguage__c = 'French';
			testContact2.TECH_WebSiteID__c = '12312';
            Database.insert(testContact2, true);
            
            //VFC08_ResetContactWebsitePassword
            //PageReference pageRefPwd = Page.VFP08_ResetContactWebsitePassword;
   			//ApexPages.StandardController scReset = new ApexPages.StandardController(testContact2);
			//VFC08_ResetContactWebsitePassword ResetContact = new VFC08_ResetContactWebsitePassword(scReset);
 			//Test.setCurrentPage(pageRefPwd);
            //pageRefPwd.getParameters().put('id',testContact2.id);
			//ResetContact.resetUserPassword();
			
			//Insert lead
            Id RecordTypeIdLead = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Website Lead').getRecordTypeId();
            Lead ld2 = TestFactory.getSimpleProSpaceLead();
            ld2.recordTypeId=RecordTypeIdLead;
            ld2.TECH_WebSiteID__c='85236';
            ld2.Status = 'Pending Qualification';
            ld2.LeadSource = 'Website';
            ld2.Lead_Sub_Source__c = 'Web self-registration';
            ld2.Prospace_Status__c = 'Pending';
            
            Database.insert(ld2, true); 
            
            //ld2.Status = 'Validated Prospace';
            //Database.update(ld2, true); 

            
            SM026_ResetProSpacePasswordLTController.checkWebsiteId(testContact2.Id);
            SM026_ResetProSpacePasswordLTController.resetProspacePass(testContact2.Id);
            
            SM026_ResetProSpacePasswordLTController.checkWebsiteId(ld2.Id);
            SM026_ResetProSpacePasswordLTController.resetProspacePass(ld2.Id);
            
            SM026_SyncWebsiteContactLTController.syncProspaceDetails(testContact2.Id);
            SM026_SyncWebsiteContactLTController.syncProspaceDetails(ld2.Id);
             
            //Insert lead
            Lead ld3 = TestFactory.getSimpleProSpaceLead();
            ld3.recordTypeId=RecordTypeIdLead;
            ld3.TECH_WebSiteID__c='';
            ld3.Status = 'Pending Qualification';
            ld3.LeadSource = 'Website';
            ld3.Lead_Sub_Source__c = 'Web self-registration';
            ld3.Prospace_Status__c = 'Pending';
            
            Database.insert(ld3, true); 
            
            ld3.Status = 'Validated Prospace';
            Database.update(ld3, true); 
            
            SM026_ResetProSpacePasswordLTController.checkWebsiteId(ld3.Id);
            SM026_ResetProSpacePasswordLTController.resetProspacePass(ld3.Id);
            
           }
        // Test End 
        System.test.stopTest();  
    }  
   
}