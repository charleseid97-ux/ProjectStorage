@isTest /*(SeeAllData=true) */
public class CPGN_AddToCampaignConMass_VFCE_test {
    
    //private static User userTest = TestFactory.getStandardCarmignacUser();
    public static User userTest = TestFactory.getCarmignacUserTestApex();
    
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
    
    public static final string STATUS_RESPONDED         = 'Responded';
    public static final string STATUS_SENT              = 'sent';
    
    
    static testMethod void test1(){
        system.runAs(userTest){
            TestFactory.createCustomSettings();
            // Data Preparation
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> A Creating Test Data');
            Account oAccount1 = TestFactory.getSimpleAccount();
            Insert oAccount1;
            
            list<Contact> listContact1  = new list<Contact>();
            Contact oContact1 = TestFactory.getSimpleNoProfileContact(oAccount1.Id,'FirstNameTU', 'LastName1', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
            Contact oContact2 = TestFactory.getSimpleContactToSetProfile(oAccount1.Id,'FirstNameTest', 'LastName2', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);

            insert oContact1;
            insert oContact2;
            oContact1 = [select id, LastName from Contact where LastName like 'LastName1%' ORDER BY createdDate DESC LIMIT 1];
            oContact2 = [select id, LastName from Contact where LastName like 'LastName2%' ORDER BY createdDate DESC LIMIT 1];
            
            listContact1.add(oContact1);
            listContact1.add(oContact2);
            
            Campaign oCampaign          = TestFactory.getSimpleCampaignEventsEtouhchesNotSend(); 
            insert oCampaign;
            oCampaign = [select id, name from Campaign where name like 'techTestCamp%' ORDER BY createdDate DESC LIMIT 1];
            
            CampaignMember oCampaignMember = new CampaignMember(
                contactId   = oContact1.id
                ,campaignId = oCampaign.id
            );
            insert oCampaignMember;
            oCampaignMember = [select id, name from CampaignMember where campaignId = :oCampaign.id ORDER BY createdDate DESC LIMIT 1];
            
            //Added back in to prevent failure
                Category_Event__c CategoryEvent = new Category_Event__c(Name='CategoryTest', Campaign__c = oCampaign.Id);
                insert CategoryEvent;
            
            Test.startTest();
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> B Starting Test...');
            ApexPages.StandardSetController setContact  = new ApexPages.StandardSetController(listContact1);
            setContact.setSelected(listContact1);
            
            CPGN_AddToCampaignConMass_VFCE oCtl         = new CPGN_AddToCampaignConMass_VFCE(setContact);
            Test.setCurrentPageReference(new PageReference('Page.CPGN_AddToCampaignConMass_VFP')); 
            
            
            integer iSelectedSize = oCtl.getSelectedListSize();
            system.assertEquals(2, oCtl.getSelectedListSize(), '=====> CPGN_AddToCampaignConMass_VFCE_test->Test1 ERROR getSelectedListSize should be 2 (number of contacts selected in list view)'); 
            
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> C Testing searchCampaign...');
            oCtl.sCampaignNameFilter = 'TestCam';
            PageReference pageRef = oCtl.searchCampaign();
            system.assertEquals(1, oCtl.getListCampaignName().size(), '=====> CPGN_AddToCampaignConMass_VFCE_test->Test1 ERROR getListCampaignName().size() should be 1'); 
            
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> D Testing getlistCategoryEvent...');
            oCtl.sCampaignId = oCampaign.id;
            List<SelectOption> oSelectOptionCategoryEvent = oCtl.getlistCategoryEvent();
            system.assertEquals(2, oCtl.getlistCategoryEvent().size(), '=====> CPGN_AddToCampaignConMass_VFCE_test->Test1 ERROR getlistCategoryEvent().size() should be 1'); 
            
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> E Testing getlistCampaignMemberStatus...');
            Category_Event__c oCategory_Event = [select id from Category_Event__c where Campaign__c = :oCampaign.id order by createdDate desc LIMIT 1];
            oCtl.sCategoryEventId = oCategory_Event.id;
            CampaignMember oCampaigMember = [select status from CampaignMember where campaignId = :oCampaign.id LIMIT 1]; //and isDefault = FALSE 
            oCtl.sCampaignMemberStatus = oCampaigMember.status;
            List<SelectOption> oSelectOptionCampaignMemberStatus = oCtl.getlistCampaignMemberStatus();
            system.assertEquals(1, oCtl.getlistCampaignMemberStatus().size(), '=====> CPGN_AddToCampaignConMass_VFCE_test->Test1 ERROR getlistCampaignMemberStatus().size() should be 1'); 
            
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> F Testing AddToCampaign with bKeepExistingStatus true...');
            oCtl.bKeepExistingStatus = true;
            oCtl.AddToCampaign();
            list<CampaignMember> listCampaignMember = new list<CampaignMember>();
            listCampaignMember = [select id,name,Category_Event__c,status from CampaignMember where campaignid = :oCampaign.id and status = :oCampaigMember.status LIMIT 99];
            system.assertEquals(2, listCampaignMember.size(), '=====> CPGN_AddToCampaignConMass_VFCE_test->Test1 ERROR listCampaignMember().size() with bKeepExistingStatus TRUE should be 1'); 
            
            
            system.debug('==CPGN_AddToCampaignConMass_VFCE_test===============> G Testing AddToCampaign with bKeepExistingStatus false...');
            oCtl.bKeepExistingStatus = false;
            oCtl.AddToCampaign();
            listCampaignMember = [select id,name,Category_Event__c,status from CampaignMember where campaignid = :oCampaign.id  LIMIT 99];
            system.assertEquals(2, listCampaignMember.size(), '=====> CPGN_AddToCampaignConMass_VFCE_test->Test1 ERROR listCampaignMember().size() with bKeepExistingStatus FALSE should be 1'); 
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> H Done, stopping test');
            
            Test.stopTest();
        }
    }
        
    
    
}