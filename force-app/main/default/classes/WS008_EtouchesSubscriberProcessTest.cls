/** 
* @author : Youssef MISSAOUI
* @date : Creation 18/05/2017
* @date : Modification 18/05/2017
* @description : WS008_EtouchesSubscriberProcessTest Unit Test.
*/
@isTest
public class WS008_EtouchesSubscriberProcessTest {
    
    static testMethod void doPostTest(){
        
        string TECH_ContactTechSUNID    = '4569872';
        string TECH_WebSiteID           = '5483465';
        string PROFESSIONAL_EMAIL       = 'ProfessionalEmailTU@carmignac.com';
        string PERSONAL_EMAIL           = 'PersonalEmailTU@carmignac.com';
        string TEAM_EMAIL               = 'TeamEmailTU@carmignac.com';
        
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
            Insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;    
            
            
            WS008_EtouchesSubscriberProcess.EtouchesSubscriber wsEtouchesSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesSubscriber wsEtouchesSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesSubscriber wsEtouchesSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesSubscriber();
            
            wsEtouchesSubscriber1.EtouchesSubscriberId = '187895' ;
            wsEtouchesSubscriber2.EtouchesSubscriberId = '' ;
            wsEtouchesSubscriber2.Lastname = '';
            wsEtouchesSubscriber3.EtouchesSubscriberId = '187895' ; 
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();      
            //doPost   
            
            //Case 1
            String JSONMsg1= JSON.serialize(wsEtouchesSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'POST';               
            req1.requestBody = Blob.valueof(JSONMsg1);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPost(wsEtouchesSubscriber1);
            
            //Case 2            
            String JSONMsg2 = JSON.serialize(wsEtouchesSubscriber2);    
            
            RestRequest req2 = new RestRequest();
            RestResponse res2 = new RestResponse();
            
            req2.addHeader('Content-Type', 'application/json');
            req2.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req2.httpMethod = 'POST';               
            req2.requestBody = Blob.valueof(JSONMsg2);
            
            RestContext.request = req2;
            RestContext.response = res2;
            
            wsreturn2 = WS008_EtouchesSubscriberProcess.doPost(wsEtouchesSubscriber2);
            
            //Case 3
            String JSONMsg3 = JSON.serialize(wsEtouchesSubscriber3);    
            
            RestRequest req3 = new RestRequest();
            RestResponse res3 = new RestResponse();
            
            req3.addHeader('Content-Type', 'application/json');
            req3.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req3.httpMethod = 'POST';               
            req3.requestBody = Blob.valueof(JSONMsg3);
            
            RestContext.request = req3;
            RestContext.response = res3;
            
            wsreturn3 = WS008_EtouchesSubscriberProcess.doPost(wsEtouchesSubscriber3);
            
            
            //Case 4
            String JSONMsg4 = JSON.serialize(wsEtouchesSubscriber3);    
            
            RestRequest req4 = new RestRequest();
            RestResponse res4 = new RestResponse();
            
            req4.addHeader('Content-Type', 'application/json');
            req4.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req4.httpMethod = 'POST';               
            req4.requestBody = Blob.valueof(JSONMsg3);
            
            RestContext.request = req4;
            RestContext.response = res4;
            
            wsreturn3 = WS008_EtouchesSubscriberProcess.doPost(null);
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn1.Message, WSResponseWrapper.Message);
            
            //    System.assertEquals(wsreturn2.Status, WSResponseWrapper.WS_STATUS_ERROR);
            // System.assertEquals(wsreturn2.Message, WSResponseWrapper.Message);
            
            //    System.assertEquals(wsreturn3.Status, WSResponseWrapper.WS_STATUS_ERROR);
            // System.assertEquals(wsreturn3.Message, WSResponseWrapper.Message);  
            
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
            Insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                        
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='Missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId='';
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    static testMethod void doPutTestError(){
        
        
        
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
            Insert camp1;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='No value';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId='';
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    static testMethod void doPutTestNoSubscriberSFId(){
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
            Insert camp1;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'Youssef','missaoui','65432345','TechwbesiteId','youssef.missaoui.external@carmignac.com','youssef.missaoui.external@carmignac.com','youssef.missaoui.external@carmignac.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            //wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId=camp1.Id;
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    static testMethod void doPutTestNoSubscriberSFId2(){
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
            Insert camp1;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'Youssef','missaoui','65432345','TechwbesiteId','youssef.missaoui.external@carmignac.com','youssef.missaoui.external@carmignac.com','youssef.missaoui.external@carmignac.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            //wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId= '';
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
     static testMethod void doPutTestNoSubscriberSFId3(){
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
            Insert camp1;
            Campaign camp2 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            Insert camp2;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'Youssef','missaoui','65432345','TechwbesiteId','youssef.missaoui.external@carmignac.com','youssef.missaoui.external@carmignac.com','youssef.missaoui.external@carmignac.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            //wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId= camp2.Id;
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    static testMethod void LeadTest(){
        
        
        
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
            Insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Lead oLead = TestFactory.getSimpleProSpaceLead();
            insert oLead;
            Lead oLead2 = TestFactory.getSimpleProSpaceLead2();
            insert oLead2;
            
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember1 = new CampaignMember(LeadId = oLead.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember1;   
            
            CampaignMember campMember2 = new CampaignMember(LeadId = oLead2.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            campMember2.TECH_ID_Attendee__c = '41539995';
            insert campMember2; 
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            wsEtouchesUpdateSubscriber1.TECH_ID_Attendee = '41539994';
            wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember1.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='Missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId='';
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            wsEtouchesUpdateSubscriber2.TECH_ID_Attendee = '41539995';
            wsEtouchesUpdateSubscriber2.SubscriberSFId=campMember2.Id;
            wsEtouchesUpdateSubscriber2.Status='Created';
            wsEtouchesUpdateSubscriber2.FirstName='JLC';
            wsEtouchesUpdateSubscriber2.LastName='Conseil';
            wsEtouchesUpdateSubscriber2.Email='externalt@carmignac.com';
            wsEtouchesUpdateSubscriber2.CampaignId='';
            wsEtouchesUpdateSubscriber2.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber2.City='Paris';
            wsEtouchesUpdateSubscriber2.Company='Carmignac';
            wsEtouchesUpdateSubscriber2.Country='France';
            wsEtouchesUpdateSubscriber2.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber2.MobilePhone='+33629371000';
            wsEtouchesUpdateSubscriber2.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber2.Zip='75001';
            wsEtouchesUpdateSubscriber2.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber2.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber2.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber2.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber2.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber2.Responded=true;
            wsEtouchesUpdateSubscriber2.BounceMessage='';
            wsEtouchesUpdateSubscriber2.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);  
            
            String JSONMsg2= JSON.serialize(wsEtouchesUpdateSubscriber2);    
            
            RestRequest req2 = new RestRequest();
            RestResponse res2 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg2);
            
            RestContext.request = req2;
            RestContext.response = res2;
            
            wsreturn2 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber2);  
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
      static testMethod void LeadTestError(){
        
        
        
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
            Insert camp1;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Lead oLead = TestFactory.getSimpleProSpaceLead();
            insert oLead;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(LeadId = oLead.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='No value';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId='';
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    static testMethod void LeadTestNoSubscriberSFId(){
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
            Insert camp1;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Lead oLead = TestFactory.getSimpleProSpaceLead();
            insert oLead;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(LeadId = oLead.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            //wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId=camp1.Id;
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
    static testMethod void LeadTestNoSubscriberSFId2(){
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
            Insert camp1;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Lead oLead = TestFactory.getSimpleProSpaceLead();
            insert oLead;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(LeadId = oLead.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            //wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId= '';
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }
    
     static testMethod void LeadTestNoSubscriberSFId3(){
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
            Insert camp1;
            Campaign camp2 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            Insert camp2;
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Lead oLead = TestFactory.getSimpleProSpaceLead();
            oLead.FirstName='Youssef';
            oLead.LastName='missaoui';
            oLead.Email='youssef.missaoui.external@carmignac.com';
            insert oLead;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(LeadId = oLead.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c ='187895');
            insert campMember;                      
            
            
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber1 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber2 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsEtouchesUpdateSubscriber3 = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            
            //wsEtouchesUpdateSubscriber1.SubscriberSFId=campMember.Id;
            wsEtouchesUpdateSubscriber1.Status='Created';
            wsEtouchesUpdateSubscriber1.FirstName='Youssef';
            wsEtouchesUpdateSubscriber1.LastName='missaoui';
            wsEtouchesUpdateSubscriber1.Email='youssef.missaoui.external@carmignac.com';
            wsEtouchesUpdateSubscriber1.CampaignId= camp2.Id;
            wsEtouchesUpdateSubscriber1.AddressLine1='24 place Vendôme';
            wsEtouchesUpdateSubscriber1.City='Paris';
            wsEtouchesUpdateSubscriber1.Company='Carmignac';
            wsEtouchesUpdateSubscriber1.Country='France';
            wsEtouchesUpdateSubscriber1.JobTitle='Consultant';
            wsEtouchesUpdateSubscriber1.MobilePhone='+33629371410';
            wsEtouchesUpdateSubscriber1.WorkPhone='+33128317694';
            wsEtouchesUpdateSubscriber1.Zip='75001';
            wsEtouchesUpdateSubscriber1.ContactQuestion='Is this a test class?';
            wsEtouchesUpdateSubscriber1.RegistrationDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.LastEtouchesActionSynchronized='2019-03-01';
            wsEtouchesUpdateSubscriber1.SubscriberOptinOptout=false;
            wsEtouchesUpdateSubscriber1.LastActionDate='2019-03-01';
            wsEtouchesUpdateSubscriber1.Responded=true;
            wsEtouchesUpdateSubscriber1.BounceMessage='';
            wsEtouchesUpdateSubscriber1.BounceType='';
            
            
            WSResponseWrapper wsreturn1 = new WSResponseWrapper();
            WSResponseWrapper wsreturn2 = new WSResponseWrapper();
            WSResponseWrapper wsreturn3 = new WSResponseWrapper();    
            //doPut     
            String JSONMsg= JSON.serialize(wsEtouchesUpdateSubscriber1);    
            
            RestRequest req1 = new RestRequest();
            RestResponse res1 = new RestResponse();
            
            req1.addHeader('Content-Type', 'application/json');
            req1.requestURI = '/services/apexrest/EtouchesCampaignMember';    
            req1.httpMethod = 'PUT';               
            req1.requestBody = Blob.valueof(JSONMsg);
            
            RestContext.request = req1;
            RestContext.response = res1;
            
            wsreturn1 = WS008_EtouchesSubscriberProcess.doPut(wsEtouchesUpdateSubscriber1);   
            
            // Results verification
            //    System.assertEquals(wsreturn1.Status, WSResponseWrapper.WS_STATUS_SUCCESS);
            // System.assertEquals(wsreturn.Message, WSResponseWrapper.Message); 
            
            // Test End 
            System.test.stopTest();  
        }
    }

}