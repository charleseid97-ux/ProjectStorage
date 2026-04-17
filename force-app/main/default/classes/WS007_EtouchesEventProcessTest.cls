/** 
* @author : Adolphe Sonko
* @date : Creation 15/05/2017
* @date : Modification 15/05/2017
* @description : WS007_EtouchesEventProcess Unit Test.
*/
@isTest
public class WS007_EtouchesEventProcessTest {
    
    static testMethod void doPostTest(){
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.Event_code_Etouches__c ='187895';
            Insert camp1;
            
            
            WS007_EtouchesEventProcess.EtouchesEvent wsEtouchesEvent = new WS007_EtouchesEventProcess.EtouchesEvent();
            WS007_EtouchesEventProcess.EtouchesEvent wsEtouchesEvent2 = new WS007_EtouchesEventProcess.EtouchesEvent();
            WS007_EtouchesEventProcess.EtouchesEvent wsEtouchesEvent3 = new WS007_EtouchesEventProcess.EtouchesEvent();
            
            wsEtouchesEvent.EtouchesEventId = '187895' ;
            wsEtouchesEvent2.EtouchesEventId = '';
            
            wsEtouchesEvent3 = null ;
            
            
            WSResponseWrapper wsreturn = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();       
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesEvent);    
            
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            
            req.addHeader('Content-Type', 'application/json');
            req.requestURI = '/services/apexrest/EtouchesCampaign';    
            req.httpMethod = 'POST';               
            req.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req;
            RestContext.response = res;
            
            wsreturn = WS007_EtouchesEventProcess.doPost(wsEtouchesEvent);
            
            
            String JSONMsg2 = JSON.serialize(wsEtouchesEvent2);    
            
            RestRequest req2 = new RestRequest();
            RestResponse res2 = new RestResponse();
            
            req2.addHeader('Content-Type', 'application/json');
            req2.requestURI = '/services/apexrest/EtouchesCampaign';    
            req2.httpMethod = 'POST';               
            req2.requestBody = Blob.valueof(JSONMsg2);
            
            RestContext.request = req2;
            RestContext.response = res2;
            wsreturn2 = WS007_EtouchesEventProcess.doPost(wsEtouchesEvent2);
            
            
            String JSONMsg3 = JSON.serialize(wsEtouchesEvent3);    
            
            RestRequest req3 = new RestRequest();
            RestResponse res3 = new RestResponse();
            
            req3.addHeader('Content-Type', 'application/json');
            req3.requestURI = '/services/apexrest/EtouchesCampaign';    
            req3.httpMethod = 'POST';               
            req3.requestBody = Blob.valueof(JSONMsg3);
            
            RestContext.request = req3;
            RestContext.response = res3;
            wsreturn3 = WS007_EtouchesEventProcess.doPost(wsEtouchesEvent3);
            
            
            // Results verification
            System.assertEquals(wsreturn.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            //   System.assertEquals(wsreturn.Message, WSResponseWrapper.Message);
            
            System.assertEquals(wsreturn3.Status, WSResponseWrapper.WS_STATUS_ERROR);
            //	System.assertEquals(wsreturn3.Message, WSResponseWrapper.Message);
            
            System.assertEquals(wsreturn2.Status, WSResponseWrapper.WS_STATUS_ERROR);
            //    System.assertEquals(wsreturn2.Message, WSResponseWrapper.Message);  
            
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    
    static testMethod void doPutTest(){
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.Event_code_Etouches__c ='187895';
            Insert camp1;
            
            
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEtouchesupdateEvent = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEtouchesupdateEvent2 = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEtouchesupdateEvent3 = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            WS007_EtouchesEventProcess.EtouchesEventUpdate wsEtouchesupdateEvent4 = new WS007_EtouchesEventProcess.EtouchesEventUpdate();
            
            wsEtouchesupdateEvent.EventSFId = camp1.Id;
            wsEtouchesupdateEvent.Status = 'Closed';
            wsEtouchesupdateEvent.RegistrationCloseDate = '2017-05-09 11:10:00';
            wsEtouchesupdateEvent.Description = 'Just a quaterly meeting ';
            wsEtouchesupdateEvent.Max_regsitration = '12';
            
            wsEtouchesupdateEvent2.EventSFId = '0015800000l6zjA';
            
            wsEtouchesupdateEvent3 = null ;
            
            wsEtouchesupdateEvent4.EventSFId = '0015800000l6zjX';
            
            WSResponseWrapper wsreturn = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();
            WSResponseWrapper wsreturn4 = new WSResponseWrapper();     
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesupdateEvent);    
            
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            
            req.addHeader('Content-Type', 'application/json');
            req.requestURI = '/services/apexrest/EtouchesCampaign';    
            req.httpMethod = 'PUT';               
            req.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req;
            RestContext.response = res;
            
            wsreturn = WS007_EtouchesEventProcess.doPut(wsEtouchesupdateEvent);
            
            
            String JSONMsg2 = JSON.serialize(wsEtouchesupdateEvent2);    
            
            RestRequest req2 = new RestRequest();
            RestResponse res2 = new RestResponse();
            
            req2.addHeader('Content-Type', 'application/json');
            req2.requestURI = '/services/apexrest/EtouchesCampaign';    
            req2.httpMethod = 'PUT';               
            req2.requestBody = Blob.valueof(JSONMsg2);
            
            RestContext.request = req2;
            RestContext.response = res2;
            wsreturn2 = WS007_EtouchesEventProcess.doPut(wsEtouchesupdateEvent2);
            
            
            String JSONMsg3 = JSON.serialize(wsEtouchesupdateEvent3);    
            
            RestRequest req3 = new RestRequest();
            RestResponse res3 = new RestResponse();
            
            req3.addHeader('Content-Type', 'application/json');
            req3.requestURI = '/services/apexrest/EtouchesCampaign';    
            req3.httpMethod = 'PUT';               
            req3.requestBody = Blob.valueof(JSONMsg3);
            
            RestContext.request = req3;
            RestContext.response = res3;
            wsreturn3 = WS007_EtouchesEventProcess.doPut(wsEtouchesupdateEvent3);
            
            
            String JSONMsg4 = JSON.serialize(wsEtouchesupdateEvent4);    
            
            RestRequest req4 = new RestRequest();
            RestResponse res4 = new RestResponse();
            
            req4.addHeader('Content-Type', 'application/json');
            req4.requestURI = '/services/apexrest/EtouchesCampaign';    
            req4.httpMethod = 'PUT';               
            req4.requestBody = Blob.valueof(JSONMsg4);
            
            RestContext.request = req4;
            RestContext.response = res4;
            wsreturn4 = WS007_EtouchesEventProcess.doPut(wsEtouchesupdateEvent4);
            
            
            // Results verification
            System.assertEquals(wsreturn.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            //   System.assertEquals(wsreturn.Message, WSResponseWrapper.Message);
            
            System.assertEquals(wsreturn3.Status, WSResponseWrapper.WS_STATUS_ERROR);
            //	System.assertEquals(wsreturn3.Message, WSResponseWrapper.Message);
            
            System.assertEquals(wsreturn2.Status, WSResponseWrapper.WS_STATUS_ERROR);
            //    System.assertEquals(wsreturn2.Message, WSResponseWrapper.Message);  
            
            System.assertEquals(wsreturn4.Status, WSResponseWrapper.WS_STATUS_ERROR);
            //    System.assertEquals(wsreturn2.Message, WSResponseWrapper.Message);
            
            
            // Test End 
            System.test.stopTest();  
        }
    }
}