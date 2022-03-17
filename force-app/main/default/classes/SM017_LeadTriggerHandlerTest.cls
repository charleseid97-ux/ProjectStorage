/** 
* @author: Adolphe SONKO
* @date : Creation 13/04/2017
* @date : Modification 13/04/2017
* @description : SM020_EtouchesScanProcess Unit Test Class  .
*/
@isTest
public class SM017_LeadTriggerHandlerTest {
    static testMethod void SM017_LeadTriggerHandlerTest(){
        
        /***************** Web Site PROSPACE custom Settings *****************/
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            //Data preparation.
            
            
            Id_Tech_Sun_Legacy__c setting = new Id_Tech_Sun_Legacy__c(Name='Sun_ID', Sun_ID__c=1234567.0);
            insert setting;
            
            List<Lead> leadListToInsert1 = new List<Lead>();            
            Id RecordTypeIdLead = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Website Lead').getRecordTypeId();

            
            lead ld= Testfactory.getSimpleLead();
            ld.recordTypeId=RecordTypeIdLead;
            ld.TECH_WebSiteID__c='58263';
            ld.Technical_ID__c=null;
            ld.Technical_ID__c=setting.Sun_ID__c;
            leadListToInsert1.add(ld);
            
            
            //Insert lead
            Lead ld2 = TestFactory.getSimpleProSpaceLead();
            ld2.recordTypeId=RecordTypeIdLead;
            ld2.TECH_WebSiteID__c='85236';
            ld2.Status = 'Pending Qualification';
            ld2.LeadSource = 'Website';
            ld2.Lead_Sub_Source__c = 'Web self-registration';
            ld2.Prospace_Status__c = 'Pending';
            leadListToInsert1.add(ld2);
            
            Database.insert(leadListToInsert1, false);  
            
            List<Lead> leadListToUpdate1 = new List<Lead>();
            
            
            //Update Lead
            ld.Synchrostatus__c='To be synced';
            leadListToUpdate1.add(ld);
            ld2.Synchrostatus__c='To be synced';
            leadListToUpdate1.add(ld2);
            Database.update(leadListToUpdate1);
            
            
            List<Lead> leadListToUpdate2 = new List<Lead>();
            List<Lead> leadListToInsert2 = new List<Lead>();

            
            
            //converted Lead
            Lead ld3 = TestFactory.getSimpleProSpaceLead();
            ld3.recordTypeId=RecordTypeIdLead;
            ld3.TECH_WebSiteID__c='21661';
            ld3.Status = 'Validated Prospace';
            ld3.LeadSource = 'Website';
            ld3.Lead_Sub_Source__c = 'Web self-registration';
            ld3.Prospace_Status__c = 'Validated';
            leadListToInsert2.add(ld3);
            
            Account accTest1 = TestFactory.getSimpleAccount();
            insert accTest1;
            
            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accTest1.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
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
            
            Database.insert(leadListToInsert2, false);
            System.assert(ld3.Prospace_Status__c == 'Validated');
            
            AlertType__c theme1 = new AlertType__c();
            theme1.name = 'Video';
            theme1.TECH_WebSiteID__c = 'Video';
            theme1.site__c = 'FR.Italian;FR.French;FR.English';
			Database.insert(theme1, true);
            
            Web_Communication__c wb= new Web_Communication__c();
            wb.Contact__c = testContact2.Id;
            wb.AlertTypeRecord__c= theme1.Id;
            wb.Type_of_communication__c='Alert Website';
            insert wb;
            
            ld3.Synchrostatus__c='To be synced';
            leadListToUpdate2.add(ld3);
            
            
            SM026_SendSelectedLeadsAsync leadAsync = new SM026_SendSelectedLeadsAsync(leadListToUpdate2, 0 , 1);
            leadAsync.executeNext(leadListToUpdate2, 0 , 1);
            
            SM026_DeleteWebsiteLeadsAsync leadDelAsync = new SM026_DeleteWebsiteLeadsAsync(leadListToUpdate2, 0 , 1);
            leadDelAsync.executeNext(leadListToUpdate2, 0 , 1);
            
            AlertType__c theme2 = new AlertType__c();
            theme2.name = 'Report';
            theme2.TECH_WebSiteID__c = 'Report';
            theme2.site__c = 'FR.Italian;FR.French;FR.English';
			Database.insert(theme2, true);
            
            Web_Communication__c wb1= new Web_Communication__c();
            wb1.Contact__c= testContact2.Id;
            wb1.AlertTypeRecord__c= theme2.Id;
            wb1.Type_of_communication__c='Alert Website';
            insert wb1;
            
            wb1.AlertTypeRecord__c = theme1.Id;
            update wb1;
            
            Database.LeadConvert lc = new database.LeadConvert();
            lc.setLeadId(ld3.id);
            lc.setConvertedStatus('Qualified');
            Database.LeadConvertResult lcr = Database.convertLead(lc);
            System.assert(lcr.isSuccess());
            system.debug(lc);
            
            //delete Lead
            Lead ld4 = TestFactory.getSimpleProSpaceLead();
            ld4.recordTypeId=RecordTypeIdLead;
            ld4.Email = 'test@test1.com';
            ld4.TECH_WebSiteID__c='58953';
            ld4.Status = 'Validated Prospace';
            ld4.LeadSource = 'Website';
            ld4.Lead_Sub_Source__c = 'Web self-registration';
            
            insert ld4;
            Id testLeadUndeleteId = ld4.Id;
            delete ld4;
            Database.undelete(testLeadUndeleteId);
            
            List<Lead>ldList = new List<Lead>();
            ldList.add(ld3);
            
           SM026_Lead_Website ldWebsite = new SM026_Lead_Website();
           ldWebsite.processResetLeadPassword(ldList); 
            
            // Test End 
            System.test.stopTest();
        }
        
    }
}