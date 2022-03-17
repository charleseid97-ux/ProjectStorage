/*
----------------------------------------------------------------------
-- - Name          : VFC04_AddToEventController_TEST
-- - Author        : JL Consulting
-- - Description   : Test class for VFC04_AddToEventController
-- Maintenance History:
--
-- Date         Name  Version  Remarks
-- -----------  ----  -------  --------------------------------------
-- 23-NOV-2018  JLC    1.0      Initial version
----------------------------------------------------------------------
**********************************************************************
*/
@isTest /*(SeeAllData=true)*/ 
public class VFC04_AddToEventController_TEST {

    public static final string TECH_ContactTechSUNID 	= '4569872';
    public static final string TECH_WebSiteID 			= '5483465';
    public static final string PROFESSIONAL_EMAIL 		= 'ProfessionalEmailTU@carmignac.com';
    public static final string PERSONAL_EMAIL 			= 'PersonalEmailTU@carmignac.com';
    public static final string TEAM_EMAIL 				= 'TeamEmailTU@carmignac.com';
    
    public static final string TECH_ContactTechSUNID2 	= '4569890';
    public static final string TECH_WebSiteID2 			= '5483464';
    public static final string PROFESSIONAL_EMAIL2 		= 'ProfessionalEmailTU2@carmignac.com';
    public static final string PERSONAL_EMAIL2 			= 'PersonalEmailTU2@carmignac.com';
    public static final string TEAM_EMAIL2 				= 'TeamEmailTU2@carmignac.com';
    
    public static final string STATUS_RESPONDED 		= 'Responded';
    public static final string STATUS_SENT 				= 'sent';

    
    static testMethod void test1(){

        Id profileId = [SELECT Id, Name FROM Profile where Name = 'System Administrator' LIMIT 1000].Id;
        
        User userTest = new User();
        userTest.Username ='user@neoposttestclass.com';
        userTest.LastName = 'TDS2';
        userTest.Email = 'test@test.com';
        userTest.Alias = 'TDS2';
        userTest.CommunityNickname = 'TDS2';
        userTest.TimeZoneSidKey = 'Europe/Paris';
        userTest.LocaleSidKey = 'en_US';
        userTest.EmailEncodingKey = 'UTF-8';
        userTest.ProfileId = profileId;
        userTest.LanguageLocaleKey = 'en_US';  
        userTest.username = 'testmanager_PartVen@neopost.com';
        userTest.email = 'testmanager.PartVen@neopost.com';
        userTest.CommunityNickname = 'testManager';
        userTest.BypassValidationRules__c = true;
        userTest.BypassProcessBuilders__c = true;
        //userTest.BypassWorkflowRules__c = true;
        userTest.Bypass_Duplicate_Rules__c = true;
        insert userTest ; 
        
        system.runAs(userTest){
            WebserviceParameters__c param = new WebserviceParameters__c(
            Name ='CarmignacWebSite', 
            Endpoint__c='https://qa.eiseverywhere.com/api/v2',
            key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
            Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
            accountid__c='4740');
    
            insert param;
                
            // Data Preparation
            system.debug('== VFC04_AddToEventController_TEST===============> A Creating Test Data');
            Account oAccount1 = TestFactory.getSimpleAccount();
            Insert oAccount1;
            
            list<Contact> listContact1 	= new list<Contact>();
            Contact oContact1 = TestFactory.getSimpleNoProfileContact(oAccount1.Id,'FirstNameTU', 'LastName1', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            Contact oContact2 = TestFactory.getSimpleContactToSetProfile(oAccount1.Id,'FirstNameTest', 'LastName2', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
            insert oContact1;
            insert oContact2;
            oContact1 = [select id, LastName from Contact where LastName like 'LastName1%' ORDER BY createdDate DESC LIMIT 1];
            oContact2 = [select id, LastName from Contact where LastName like 'LastName2%' ORDER BY createdDate DESC LIMIT 1];
            
            listContact1.add(oContact1);
            listContact1.add(oContact2);
            
            /**** LEAD **/
            list<Lead> listLead 	= new list<Lead>();
            Lead oLead = TestFactory.getSimpleProSpaceLead();
            insert oLead;
            oLead = [select id, LastName from Lead where LastName like 'Test%' ORDER BY createdDate DESC LIMIT 1];
            
            listLead.add(oLead);
            
            Campaign oCampaign			= TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            oCampaign.name = 'TestCampaign 1';
            oCampaign.Type = 'Exclusive Event';
            insert oCampaign;
            oCampaign = [select id, name from Campaign where name = 'TestCampaign 1' ORDER BY createdDate DESC LIMIT 1];
            
            Campaign oCampaign2			= TestFactory.getSimpleCampaignEvents(); 
            oCampaign2.name = 'TestCampaign 2';
            oCampaign2.Type = 'Exclusive Event';
            insert oCampaign2;
            oCampaign2 = [select id, name from Campaign where name = 'TestCampaign 2' ORDER BY createdDate DESC LIMIT 1];
            
            CampaignMember oCampaignMember = new CampaignMember(
                contactId 	= oContact1.id
                ,campaignId = oCampaign.id
                ,status = 'Invited'
            );
            insert oCampaignMember;
            oCampaignMember = [select id, name from CampaignMember where campaignId = :oCampaign.id ORDER BY createdDate DESC LIMIT 1];                        
            
            /*CampaignMember oCampaignMember2 = new CampaignMember(
                leadId 	= oLead.id
                ,campaignId = oCampaign2.id
            );
            insert oCampaignMember2;
            oCampaignMember2 = [select id, name from CampaignMember where campaignId = :oCampaign2.id ORDER BY createdDate DESC LIMIT 1];*/


            List<Category_Event__c> events = new List<Category_Event__c>();
            events.add(new Category_Event__c(Name = 'TestName', Campaign__c = oCampaign.Id));
            events.add(new Category_Event__c(Name = 'TestName', Campaign__c = oCampaign2.Id));
            insert events;

            
        	CampaignMemberStatus campaignMemberStatus1 = new CampaignMemberStatus(CampaignId = oCampaign.ID, Label = 'Invited');

	        insert campaignMemberStatus1;
	        campaignMemberStatus1 = [select id, Label from CampaignMemberStatus where campaignId = :oCampaign.ID ORDER BY createdDate DESC LIMIT 1];  
	         
	        /**** Le test commence ici ********/
            
            Test.startTest();
            system.debug('== VFC04_AddToEventController_TEST ===============> B Starting Test...');
            ApexPages.StandardSetController setContact 	= new ApexPages.StandardSetController(listContact1);
            setContact.setSelected(listContact1);                        
            
            VFC04_AddToEventController addToEventController = new VFC04_AddToEventController(setContact);
	        Test.setCurrentPageReference(new PageReference('Page.VFP04_AddToEventController')); 
            
            String sContactIds = oContact1.Id;
	        List<Contact> oContactTest = new List<Contact>();
	        oContactTest = VFC04_AddToEventController.initializeMembers(sContactIds, 'Contact');
	        system.assertEquals('FirstNameTU LASTNAME1', oContactTest[0].Name , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR initializeContacts return an incorrect contact');
            
            sContactIds = oContact1.Id + ',' + oContact2.Id;
	        oContactTest = VFC04_AddToEventController.initializeMembers(sContactIds, 'Contact');
	        system.assertEquals(2, oContactTest.size() , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR initializeContacts should be 2 contacts according to size');
            
            sContactIds = oContact2.Id;
	        oContactTest = VFC04_AddToEventController.initializeMembers(sContactIds, 'Contact');
	        system.assertEquals(1, oContactTest.size() , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR initializeContacts should be 1 contacts according to size');
            
            List<Category_Event__c> listCategEvent = VFC04_AddToEventController.initializePicklist(oCampaign.ID);
	        system.assertEquals(1, listCategEvent.size() , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR initializePicklist should be 1 category event according to size');
	            
	        List<String> sLabelMemberStatus = VFC04_AddToEventController.initializePicklistMember(oCampaign.ID);
	        //system.assertEquals(1, sLabelMemberStatus.size() , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR initializePicklistMember should be 1 CampaignMember Status according to size');
            
            //public static boolean addToCampaign(Id iCampaignId, Id iCategory,String sMemberStatus,boolean bKeepExistingStatus, List<Contact> lContacts)
	        
	        boolean b1 = VFC04_AddToEventController.addToCampaign(oCampaign.ID, listCategEvent[0].ID,sLabelMemberStatus[0], listContact1, 'Contact');
	        system.assertEquals(true, b1 , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR addToCampaign should be true ');
            
            boolean b2 = VFC04_AddToEventController.addToCampaign(oCampaign2.ID, listCategEvent[0].ID,sLabelMemberStatus[0],listLead, 'Lead');
	        system.assertEquals(true, b1 , '=====> VFC04_AddToEventController_TEST -> Test1 ERROR addToCampaign should be true ');
            
            system.assertEquals(null, addToEventController.getSelectedValues()); 

            system.debug('== VFC04_AddToEventController_TEST ===============> H Done, stopping test');
            
            customLookUpController.fetchLookUpValues('Test', 'Campaign');
            
            
            Test.stopTest();
        }
    }
   

}