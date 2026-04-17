/** 
* @author Adolphe SONKO
* @date Creation 08/04/2017
* @date Modification 08/04/2017
* @description : EM018_SubscriberEtouchesTest Test Unit Test Class 
*/

@isTest
public class EM018_SubscriberEtouchesTest {
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    static testMethod void getListByCampaignIds() {
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            Insert camp1;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            // Methods Calls        	
            List<Id> listCamptoTest = new List<Id>();
            listCamptoTest.add(camp1.Id);
            
            List<CampaignMember> found_CampaignMemberList =  EM018_SubscriberEtouches.getListByCampaignIds(listCamptoTest);
            List<CampaignMember> found_CampaignMemberList2 = EM018_SubscriberEtouches.getListByCampaignMemberByMail(new List<String>{'mail@mail1.com'});
            
            // Results verification
            System.assertEquals(found_CampaignMemberList.size(), 1);
            System.assertEquals(found_CampaignMemberList2.size(), 1);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void getListBySubscriberIds() {
        try
        {
            
            
            // Test User creation 
            User u = TestFactory.getCarmignacUserTestApex();
            
            System.runAs(u){
                // Test Begin
                System.test.startTest(); 
                TestFactory.createCustomSettings();
                // Data Preparation
                Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
                Insert camp1;
                
                Account accTest = TestFactory.getSimpleAccount();
                insert accTest;
                
                Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
                insert testContact1;
                
                Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
                insert categ;
                
                CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '785142');
                insert campMember;
                // Methods Calls
                WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
                updateSubscriber.Email = 'mail@mail1.com';
                updateSubscriber.FirstName = 'TestFName';
                updateSubscriber.LastName = 'LastNameTestCarmignac'; 
                
                List<CampaignMember> found_CampaignMemberList =  EM018_SubscriberEtouches.getListBySubscriberIds(new Set<String>{'785142'});
                
                // Results verification
                System.assertEquals(found_CampaignMemberList.size(), 1);       
                
                // Governer limits tests
                System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            }
            
            // Test End 
            System.test.stopTest();
        }
        catch (Exception e) 
        {
            EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
            newErroException.dateCreate = Datetime.now();
            newErroException.interfaceName = 'getListBySubscriberIds Catch Exception';
            newErroException.Data = e.getMessage();
            newErroException.error = e.getStackTraceString();
            
            listLogError.add(newErroException);  
        }
        
        EM023_Log.insertLogError(listLogError);     
    }
    
    static testMethod void getAllSubscribers(){
        
        /***************** Etouches custom Settings *****************/
        
        
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
            
            //Request        	
            datetime myDateTime = datetime.now();
            datetime myDateTime2 = null;
            
            HttpRequest testRequest = EM018_SubscriberEtouches.getAllSubscribers(param, param.Token__c, myDateTime, '123456','1000');
            HttpRequest testRequest2 = EM018_SubscriberEtouches.getAllSubscribers(param, param.Token__c, myDateTime2, '123456','1000');
            HttpRequest testRequestCTRL =  new HttpRequest();        
            
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/emarketing/listSubscribers.json' +	
                                        '?accesstoken='+param.Token__c+
                                        '&listid='+'123456'+
                                        //'&limit='+limits+
                                        '&fields=subscriberid,email,fname,lname,status'
                                        +
                                        '&search=lastmodified>='+myDateTime);
            
            
            testRequestCTRL.setMethod('GET');       
            
            //Response testing Create Subscriber        		
            HttpResponse testResponse = EM018_SubscriberEtouches.getListSubscriber(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('[{"subscriberid":"72320736","email":"test@test-carmignac.com","fname":"Adolphe","lname":"SONKO"}]');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');
            
            // Testing Result
            System.assertEquals(testRequest.getBody(), testRequestCTRL.getBody());      	        	
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());        	
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());        	
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());	
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        // Test End 
        System.test.stopTest();	
    }
    
    static testMethod void getAllSubscribersX(){
        
        /***************** Etouches custom Settings *****************/
        
        
        
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
            //Request        	
            datetime myDateTime = datetime.now();
            HttpRequest testRequest = EM018_SubscriberEtouches.getAllSubscribersX(param, param.Token__c, myDateTime, '87246','1200', '2000');
            
            HttpRequest testRequestCTRL =  new HttpRequest();   
            
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/emarketing/listSubscribers.json' +	
                                        '?accesstoken='+param.Token__c+
                                        '&listid='+'87246'+
                                        //'&limit='+limits+
                                        '&fields=subscriberid,email,fname,lname,status'+
                                        '&search=status!=Subscribed'+
                                        '&offset='+'2000');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing Create Subscriber        		
            HttpResponse testResponse = EM018_SubscriberEtouches.getListSubscriber(testRequest,null);        	
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('[{"subscriberid":"72320736","email":"test@test-carmignac.com","fname":"Adolphe","lname":"SONKO"}]');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');        	
            
            // Testing Result
            System.assertEquals(testRequest.getBody(), testRequestCTRL.getBody());        	        	
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));        	
            System.assertEquals(testRequest.getEndpoint(), testRequestCTRL.getEndpoint());
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());  
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());        	
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());        	
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());	
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());           	
        }
        // Test End 
        System.test.stopTest();	
    }	
}