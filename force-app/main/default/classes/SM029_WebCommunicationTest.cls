@isTest
public class SM029_WebCommunicationTest {
    
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
        // Test Begin
        System.test.startTest(); 
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            
            Id_Tech_Sun_Legacy__c setting = new Id_Tech_Sun_Legacy__c (
                Sun_ID__c =250 
                ,Name='Sun_ID'
                
            );
            
            TestFactory.createCustomSettings();
            Product__c prd = new Product__c();
            prd.RecordTypeId = Product__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            prd.Name = 'Prod123';
            prd.Product_Name__c = 'Product Test';
            prd.Validity__c = true;
            Database.insert(prd, true);          
            
            Share_Class__c sC = new Share_Class__c();
            sC.Name = 'Test SC';
            sC.Fund__c = prd.Id;
            sC.ISIN_Code__c = 'FR0011100000';
            sc.Country__c = 'FR';
            sc.Validity__c = true;
            
            Database.insert(sC, true);
                
            Account accountTest = TestFactory.getSimpleAccount();
            insert accountTest;
            
            
            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accountTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact2.WebsiteRole__c = '5';
            testContact2.TrialStatus__c = '5';
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
            testContact2.Prospace_Status__c = 'Validated';    
            
            Database.insert(testContact2, true);
            
            //Insert lead
            Id RecordTypeIdLead = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Website Lead').getRecordTypeId();

            Lead ld2 = TestFactory.getSimpleProSpaceLead();
            ld2.recordTypeId=RecordTypeIdLead;
            ld2.TECH_WebSiteID__c='85236';
            ld2.Status = 'Pending Qualification';
            ld2.LeadSource = 'Website';
            ld2.Lead_Sub_Source__c = 'Web self-registration';
            ld2.Prospace_Status__c = 'Validated';
            ld2.WebsiteCountry__c = 'FR';
            
            Database.insert(ld2, true); 
            //ld2.Status = 'Validated Prospace';
            //Database.update(ld2, true); 
            	
            System.assert(ld2.Id != null);
            
            //testContact1.update
            AlertType__c theme1 = new AlertType__c();
            theme1.name = 'daily_nav';
            theme1.TECH_WebSiteID__c = 'daily_nav';
            theme1.site__c = 'FR.Italian;FR.French;FR.English';
            theme1.isPublication__c = false;
			Database.insert(theme1, true);
            System.assert(theme1.Id != null);
            
            List<Web_Communication__c> WebCommList = new List<Web_Communication__c>();
            Web_Communication__c web = new Web_Communication__c();
            web.TECH_ISINCode__c = 'FR0011100000';
            web.AlertTypeRecord__c = theme1.Id;
            web.Contact__c = testContact2.Id;
            web.TECH_CommunicationWebsiteId__c = '1111';
            web.ShareClass__c = sC.Id;
            web.Fund__c = prd.Id;
            WebCommList.add(web);
            
            Web_Communication__c web2 = new Web_Communication__c();
            web2.TECH_ISINCode__c = 'FR0011100011';
            web2.AlertTypeRecord__c = theme1.Id;
            web2.Lead__c = ld2.Id;
            web2.ShareClass__c = sC.Id;
            web2.Fund__c = prd.Id;
            web2.TECH_CommunicationWebsiteId__c = '22222';
            
            WebCommList.add(web2);
            
            Database.insert(WebCommList, true);
            
            List<Contact> conList = new List<Contact>();
            conList.add(testContact2);
            //VFC11_AddAllProSpaceAlerts
   			ApexPages.StandardSetController addAllAlerts = new ApexPages.StandardSetController(conList);
			VFC11_AddAllProSpaceAlerts ResetContact = new VFC11_AddAllProSpaceAlerts(addAllAlerts);
            VFC12_DeleteAllProspaceAlerts delAll = new VFC12_DeleteAllProspaceAlerts(addAllAlerts);
            
            List<String> selectedTypes = new List<String>();
            selectedTypes.add(theme1.Id);
			SM029_AddAllAlertsLTController.initializePicklistAlertType(testContact2.Id);
            SM029_AddAllAlertsLTController.addAllProspaceAlerts(testContact2.Id, selectedTypes);
            SM029_AddAllAlertsLTController.addAllProspaceAlerts(ld2.Id, selectedTypes);

            SM029_SendSelectedWebCommAsync webAsync = new SM029_SendSelectedWebCommAsync(WebCommList, 0 , 1);
            webAsync.executeNext(WebCommList, 0 , 1);
            
            SM029_DeleteWebsiteWebCommAsync leadDelAsync = new SM029_DeleteWebsiteWebCommAsync(WebCommList, 0 , 1);
            leadDelAsync.executeNext(WebCommList, 0 , 1);
            
            Web_Communication__c web3 = new Web_Communication__c();
            web3.TECH_ISINCode__c = 'FR0011100033';
            web3.Contact__c = testContact2.Id;
            web3.TECH_CommunicationWebsiteId__c = '3333';
            web3.ShareClass__c = sC.Id;
            web3.Fund__c = prd.Id;
            Database.insert(web3, true);
            SM029_WebCommunication.updateLookupAlertType(WebCommList);
            
            Database.delete(web3, true);
            
            SM029_DeleteAllAlertsLTController.initializePicklistAlertType(testContact2.Id);
            SM029_DeleteAllAlertsLTController.deleteAllProspaceAlerts(testContact2.Id, selectedTypes);
            SM029_DeleteAllAlertsLTController.deleteAllProspaceAlerts(ld2.Id, selectedTypes);
            
            // Test End 
            System.test.stopTest();  
            
        }
    }
    
}