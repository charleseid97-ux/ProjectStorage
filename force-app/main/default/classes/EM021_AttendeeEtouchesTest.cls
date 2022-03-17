/** 
* @author Adolphe Sonko
* @date Creation 12/04/2017
* @date Modification 12/04/2017
* @description : EM021_AttendeeEtouches Unit Test Class 
*/

@isTest
public   class EM021_AttendeeEtouchesTest {
    
    // Test User creation
    public static User userTest = TestFactory.getCarmignacUserTestApex();
    
    static testMethod void getAllAttendees(){
        /***************** ETOUCHES custom Settings *****************/                
        
        System.runAs(userTest){
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
            
            //User u = TestFactory.getStandardCarmignacUser();	
            //insert u;
            
            
            //Test Begin
            System.test.startTest();       
            
            
            datetime myDateTime = datetime.now();
            HttpRequest testRequest = EM021_AttendeeEtouches.getAllAttendees(param, param.Token__c, myDateTime, camp1.Event_code_Etouches__c, '1000');
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c +  '/ereg/listAttendees.json' +'?accesstoken='+param.Token__c+ '&eventid='+camp1.Event_code_Etouches__c+
                                        '&limit='+'1000');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET All Attendees
            
            HttpResponse testResponse = EM021_AttendeeEtouches.getListAttendee(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('{"error":{"data":"No attendees found.","help":"http:\\developer.etouches.com\\ehome\\50138\\get-list-attendees\"}}');
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
    
    
    static testMethod void getAllAttendeesX(){
        /***************** ETOUCHES custom Settings *****************/
        
        System.runAs(userTest){
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
            
            //Test Begin
            System.test.startTest();       
            
            datetime myDateTime = datetime.now();
            datetime myDateTime2 = null;
            HttpRequest testRequest = EM021_AttendeeEtouches.getAllAttendeesX(param, param.Token__c, myDateTime, '123456', '1000', '700');
            HttpRequest testRequest2 = EM021_AttendeeEtouches.getAllAttendeesX(param, param.Token__c, myDateTime2, '123456', '1000', '700');
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c +  '/ereg/listAttendees.json' +
                                        '?accesstoken='+param.Token__c+
                                        '&eventid='+'123456'+
                                        '&limit='+'1000'+
                                        '&offset='+'700'+
                                        '&modifiedfrom='+myDateTime);
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET All Attendees
            
            HttpResponse testResponse = EM021_AttendeeEtouches.getListAttendee(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('{"error":{"data":"No attendees found.","help":"http:\\developer.etouches.com\\ehome\\50138\\get-list-attendees\"}}');
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
            
            System.test.stopTest();
        }
        // Test End 
        
        //repeat the same for the rest of classes.
    } 
    
    
    static testMethod void getAttendees(){
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
            
            //Test Begin
            System.test.startTest();       
            
            datetime myDateTime = datetime.now();
            HttpRequest testRequest = EM021_AttendeeEtouches.getAttendees(param, param.Token__c, '123456', '1000');
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c +  '/ereg/getAttendee.json' +
                                        '?accesstoken='+param.Token__c+
                                        '&eventid='+'123456'+
                                        '&attendeeid='+'1000'+
                                        '&responseArray='+'1');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET All Attendees
            
            HttpResponse testResponse = EM021_AttendeeEtouches.getAttendee(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('{"attendeeid":"1234","categoryid":"1","name":"Category Test 1","registrationstatus":"Confirmed","lastmodified":"2014-10-06 14:10:31","responses":[{"fieldname":"email","response":"mail@mail1.com"},{"fieldname":"fname","response":"TestFName"},{"fieldname":"lname","response":"LastNameTestCarmignac"}]}');
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