@isTest /*(SeeAllData=true) */
public class CPGN_AddToCampaignLeadMass_VFCE_Test {

	private static User userTest = TestFactory.getCarmignacUserTestApex();

    static testMethod void test1(){
        system.runAs(userTest){
            TestFactory.createCustomSettings();    
            // Data Preparation
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> A Creating Test Data');
            //Account oAccount1 = TestFactory.getSimpleAccount();
            //Insert oAccount1;
            
            list<Lead> listlead1 	= new list<Lead>();
            Lead oLead1 = TestFactory.getSimpleProSpaceLead ();
            Lead oLead2 = TestFactory.getSimpleProSpaceLead2 ();
            insert oLead1;
            insert oLead2;
            oLead1 = [select id, LastName from Lead where LastName = 'Test' ORDER BY createdDate DESC LIMIT 1];
            oLead2 = [select id, LastName from lead where LastName = 'Test2' ORDER BY createdDate DESC LIMIT 1];
            
            listLead1.add(oLead1);
            listLead1.add(oLead2);
            
            Campaign oCampaign			= TestFactory.getSimpleCampaignEventsEtouhchesNotSend(); 
            insert oCampaign;
            oCampaign = [select id, name from Campaign where name like 'techTestCamp%' ORDER BY createdDate DESC LIMIT 1];
            
            CampaignMember oCampaignMember = new CampaignMember(
                leadId 	= oLead1.id
                ,campaignId = oCampaign.id
            );
            insert oCampaignMember;
            oCampaignMember = [select id, name from CampaignMember where campaignId = :oCampaign.id ORDER BY createdDate DESC LIMIT 1];
            
            //Added back in to prevent failure
                Category_Event__c CategoryEvent = new Category_Event__c(Name='CategoryTest', Campaign__c = oCampaign.Id);
                insert CategoryEvent;

           
            Test.startTest();
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> B Starting Test...');
            ApexPages.StandardSetController setlead 	= new ApexPages.StandardSetController(listLead1);
            setlead.setSelected(listLead1);
            
            CPGN_AddToCampaignLeadMass_VFCE oCtl 		= new CPGN_AddToCampaignLeadMass_VFCE(setLead);
            Test.setCurrentPageReference(new PageReference('Page.CPGN_AddToCampaignLeadMass_VFP')); 
            
            
            integer iSelectedSize = oCtl.getSelectedListSize();
            system.assertEquals(2, oCtl.getSelectedListSize(), '=====> CPGN_AddToCampaignLeadMass_VFCE_test->Test1 ERROR getSelectedListSize should be 2 (number of leads selected in list view)'); 
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> C Testing searchCampaign...');
            oCtl.sCampaignNameFilter = 'TestCam';
            PageReference pageRef = oCtl.searchCampaign();
            system.assertEquals(1, oCtl.getListCampaignName().size(), '=====> CPGN_AddToCampaignLeadMass_VFCE_test->Test1 ERROR getListCampaignName().size() should be 1'); 
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> D Testing getlistCategoryEvent...');
            oCtl.sCampaignId = oCampaign.id;
            List<SelectOption> oSelectOptionCategoryEvent = oCtl.getlistCategoryEvent();
            system.assertEquals(2, oCtl.getlistCategoryEvent().size(), '=====> CPGN_AddToCampaignLeadMass_VFCE_test->Test1 ERROR getlistCategoryEvent().size() should be 1'); 
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> E Testing getlistCampaignMemberStatus...');
            Category_Event__c oCategory_Event = [select id from Category_Event__c where Campaign__c = :oCampaign.id order by createdDate desc LIMIT 1];
            oCtl.sCategoryEventId = oCategory_Event.id;
            CampaignMember oCampaigMember = [select status from CampaignMember where campaignId = :oCampaign.id LIMIT 1]; //and isDefault = FALSE 
            oCtl.sCampaignMemberStatus = oCampaigMember.status;
            List<SelectOption> oSelectOptionCampaignMemberStatus = oCtl.getlistCampaignMemberStatus();
            system.assertEquals(1, oCtl.getlistCampaignMemberStatus().size(), '=====> CPGN_AddToCampaignLeadMass_VFCE_test->Test1 ERROR getlistCampaignMemberStatus().size() should be 1'); 
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> F Testing AddToCampaign with bKeepExistingStatus true...');
            oCtl.bKeepExistingStatus = true;
            oCtl.AddToCampaign();
            list<CampaignMember> listCampaignMember = new list<CampaignMember>();
            listCampaignMember = [select id,name,Category_Event__c,status from CampaignMember where campaignid = :oCampaign.id and status = :oCampaigMember.status LIMIT 99];
            system.assertEquals(2, listCampaignMember.size(), '=====> CPGN_AddToCampaignLeadMass_VFCE_test->Test1 ERROR listCampaignMember().size() with bKeepExistingStatus TRUE should be 1'); 
            
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> G Testing AddToCampaign with bKeepExistingStatus false...');
            oCtl.bKeepExistingStatus = false;
            oCtl.AddToCampaign();
            listCampaignMember = [select id,name,Category_Event__c,status from CampaignMember where campaignid = :oCampaign.id  LIMIT 99];
            system.assertEquals(2, listCampaignMember.size(), '=====> CPGN_AddToCampaignLeadMass_VFCE_test->Test1 ERROR listCampaignMember().size() with bKeepExistingStatus FALSE should be 1'); 
            
            system.debug('==CPGN_AddToCampaignLeadMass_VFCE_test===============> H Done, stopping test');

            Test.stopTest();
        }
    }
   

}