/** 
* @author Adolphe SONKO
* @date Creation 15/05/2017
* @date Modification 15/05/2017
* @description : SM024_EtouchesProcessEvent Test Unit Test Class 
*/


@isTest
public class SM024_EtouchesProcessEventTest {
    
    static testMethod void getCampaign() {
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.Event_code_Etouches__c = '187895';
            Insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            // Methods Calls
            
            WS007_EtouchesEventProcess.EtouchesEvent wsEvent = new WS007_EtouchesEventProcess.EtouchesEvent();
            WS007_EtouchesEventProcess.EtouchesEvent wsEvent2 = new WS007_EtouchesEventProcess.EtouchesEvent();
            WS007_EtouchesEventProcess.EtouchesEvent wsEvent3 = new WS007_EtouchesEventProcess.EtouchesEvent();
            
            wsEvent.EtouchesEventId = '187895';
            wsEvent2.EtouchesEventId = '187890';
            wsEvent3.EtouchesEventId = '';
            
            
            WSResponseWrapper wsReturn = new WSResponseWrapper();
            WSResponseWrapper wsReturn2 = new WSResponseWrapper();
            WSResponseWrapper wsReturn3 = new WSResponseWrapper();
            
            
            wsReturn =  SM024_EtouchesProcessEvent.getCampaign(wsEvent);
            wsReturn2 = SM024_EtouchesProcessEvent.getCampaign(wsEvent2);
            wsReturn3 = SM024_EtouchesProcessEvent.getCampaign(wsEvent3);
            
            // Results verification
            System.assertEquals(wsreturn.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            System.assertEquals(wsreturn.Message, 'Here the Campaign corresponding to this Etouches Event Id : 187895');
            
            System.assertEquals(wsreturn3.Status, WSResponseWrapper.WS_STATUS_ERROR);
            System.assertEquals(wsreturn3.Message, 'The Event Code Etouches is mandatory in order to retrieve the corresponding Campaign in Salesforce');
            
            System.assertEquals(wsreturn2.Status, WSResponseWrapper.WS_STATUS_ERROR);
            System.assertEquals(wsreturn2.Message, 'This Event Code Etouches does not correspond to any Campaign in Salesforce');  
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void updateCampaign() {
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.Event_code_Etouches__c = '187895';
            Insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            // Methods Calls
            
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEvent = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEvent2 = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEvent3 = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            
            wsEvent.EventSFId = camp1.Id;
            wsEvent.Status = 'Closed';
            wsEvent.RegistrationCloseDate = '2017-05-15 10:38:00';
            wsEvent.Description = 'Test of ws update on campaign with etouches data';
            wsEvent.Max_regsitration = '8';
            
            //   wsEvent2.EventSFId = '';
            //   wsEvent3.EventSFId = '';
            
            
            WSResponseWrapper wsReturn = new WSResponseWrapper();
            WSResponseWrapper wsReturn2 = new WSResponseWrapper();
            WSResponseWrapper wsReturn3 = new WSResponseWrapper();
            
            
            wsReturn =  SM024_EtouchesProcessEvent.updateCampaign(wsEvent);
            //     wsReturn2 = SM024_EtouchesProcessEvent.updateCampaign(wsEvent2);
            //      wsReturn3 = SM024_EtouchesProcessEvent.updateCampaign(wsEvent3);
            
            // Results verification
            System.assertEquals(wsreturn.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            System.assertEquals(wsreturn.Message, 'The Campaign Was Successfully updated ');
            
            /*     System.assertEquals(wsreturn2.Status, WSResponseWrapper.WS_STATUS_ERROR);
//System.assertEquals(wsreturn2.Message, 'There is no Campaign in Salesforce with this Id: 0015800000l6zjXAAQ');

System.assertEquals(wsreturn3.Status, WSResponseWrapper.WS_STATUS_ERROR);
System.assertEquals(wsreturn3.Message, 'The Campaign Id is mandatory !');   */
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
}