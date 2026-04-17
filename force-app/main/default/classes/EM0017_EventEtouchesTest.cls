/** 
* @author: Adolphe SONKO
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : EM0017_EventEtouches Unit Test Class  .
*/
@isTest
public class EM0017_EventEtouchesTest {
    
    // Test User creation
    public static User userTest = TestFactory.getCarmignacUserTestApex();
    
    static testMethod void getAllEventEtouches(){
        /***************** ETOUCHES custom Settings *****************/
        
        system.runAs(userTest){                    
            
            TestFactory.createCustomSettings();
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;	
            
            Category_Event__c categ = new Category_Event__c(Name='Category Test 1', Campaign__c=camp1.Id, Tech_Category_Event_ID_Etouches__c='1234');        
            
            User u = TestFactory.getStandardCarmignacUser();
            //insert u;
            
            
            //Test Begin
            System.test.startTest();       
            
            Datetime dateTosearch = Datetime.now();
            HttpRequest testRequest = EM0017_EventEtouches.getAllEventEtouches(param, param.Token__c, dateTosearch);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/global/listEvents.json' +	
                                        '?accesstoken='+param.Token__c+
                                        '&fields=name,eventid,status,lastmodified'
                                        +
                                        '&search=lastmodified>='+dateTosearch);
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET All Events
            
            HttpResponse testResponse = EM0017_EventEtouches.getListEvent(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('[{"eventid":"73997","name":"Anniversaire Julie"},{"eventid":"95108","name":"Old Template_Quarterly Meeting"},{"eventid":"96359","name":"Lily Webinar_Summer Funds Celebration"}]');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');  
            
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());
            
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());
            
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries()) ;
            
            // Test End 
            System.test.stopTest();
        }
        
        //repeat the same for the rest of classes.
    } 
    
    
    
    static testMethod void getLivePreEventtEtouches(){
        /***************** ETOUCHES custom Settings *****************/
        
        system.runAs(userTest){                    
            
            TestFactory.createCustomSettings();
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;	
            
            Category_Event__c categ = new Category_Event__c(Name='Category Test 1', Campaign__c=camp1.Id, Tech_Category_Event_ID_Etouches__c='1234');        
            
            User u = TestFactory.getStandardCarmignacUser();
            //insert u;
            
            
            //Test Begin
            System.test.startTest();       
            
            HttpRequest testRequest = EM0017_EventEtouches.getLivePreEventtEtouches(param, param.Token__c);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/global/listEvents.json' +	
                                        '?accesstoken='+param.Token__c+
                                        '&fields=name,eventid,status&search=status=Pre-Event||Live');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET Live Event 
            
            HttpResponse testResponse = EM0017_EventEtouches.getListEvent(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('[{"eventid":"73997","name":"Anniversaire Julie"},{"eventid":"95108","name":"Old Template_Quarterly Meeting"},{"eventid":"96359","name":"Lily Webinar_Summer Funds Celebration"}]');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');  
            
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());
            
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());
            
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries()) ;
            
            // Test End 
            System.test.stopTest();	
        }        	
        
        
        //repeat the same for the rest of classes.
    } 
    
    
    static testMethod void getAllEventEtouchesOne(){
        /***************** ETOUCHES custom Settings *****************/
        
        system.runAs(userTest){                    
            
            TestFactory.createCustomSettings();
            
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;	
            
            Category_Event__c categ = new Category_Event__c(Name='Category Test 1', Campaign__c=camp1.Id, Tech_Category_Event_ID_Etouches__c='1234');        
            
            User u = TestFactory.getStandardCarmignacUser();
            //insert u;
            
            
            //Test Begin
            System.test.startTest();       
            
            Datetime dateTosearch =  Datetime.now();
            HttpRequest testRequest = EM0017_EventEtouches.getAllEventEtouchesOne(param, param.Token__c, '95108');
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/ereg/getEvent.json'+	
                                        '?accesstoken='+param.Token__c+
                                        '&eventid='+'95108');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET Event
            
            HttpResponse testResponse = EM0017_EventEtouches.getEvent(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('{"eventid":"187895","accountid":"4740","folderid":"43168","name":"Campaign Test Button ASONKO 10h50","city":"PAris","startdate":"2017-05-09","enddate":"2017-05-09","timezoneid":"30","status":"Pre-Event","event_type":null,"description":null,"programmanager":"Etouches Interface","country":"France","modifiedby":"etouchesapi","locationname":"3eme etage","state":"","url":"https:qa.eiseverywhere.com/187895","max_reg":"0"}')  ;  	
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');  
            
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());
            
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());
            
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries()) ;
            
            // Test End 
            System.test.stopTest();	
        }
        
        //repeat the same for the rest of classes.
    } 
    
    
    static testMethod void getAllMailingListEtouches(){
        /***************** ETOUCHES custom Settings *****************/
        
        system.runAs(userTest){                    
            
            TestFactory.createCustomSettings();
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                Name ='EtouchesAPI', 
                Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
                accountid__c='4740');
            
            insert param;
            
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;	
            
            Category_Event__c categ = new Category_Event__c(Name='Category Test 1', Campaign__c=camp1.Id, Tech_Category_Event_ID_Etouches__c='1234');        
            
            User u = TestFactory.getStandardCarmignacUser();
            //insert u;
            
            
            //Test Begin
            System.test.startTest();       
            
            Datetime dateTosearch =  Datetime.now();
            HttpRequest testRequest = EM0017_EventEtouches.getAllMailingListEtouches(param, param.Token__c, dateTosearch);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/emarketing/listMailinglists.json'+	
                                        '?accesstoken='+param.Token__c+
                                        '&fields=listid,name,eventid,status,folderid,lastmodified'
                                        +
                                        '&search=lastmodified>='+dateTosearch);
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET Event
            
            HttpResponse testResponse = EM0017_EventEtouches.getListMailingList(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('[{"listid":"85467","name":"Campaign Test Button ASONKO 10h50","status":"Active","folderid":"0","eventid":"187895"}]');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');  
            
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());
            
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());
            
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries()) ;
            
            // Test End 
            System.test.stopTest();	
        }
        
        
        //repeat the same for the rest of classes.
    } 
    
}