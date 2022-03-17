/** 
* @author Adolphe SONKO
* @date Creation 08/04/2017
* @date Modification 08/04/2017
* @description : EM012_eTouchesAuthWS Test Unit Test Class 
*/

@isTest
public class EM012_eTouchesAuthWSTest {
    
    static testMethod void getCreateAuthRequest(){
        /***************** ETOUCHES custom Settings *****************/
        
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
            HttpRequest testRequest = EM012_eTouchesAuthWS.getCreateAuthRequest(param);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c +  '/global/authorize.format?' + '' + '');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing Reset Password 
            
            HttpResponse testResponse = EM012_eTouchesAuthWS.createAuth(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('{"accesstoken":"123456789ABCDEFGH"}');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');
            
            // Testing Results
            
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
    
    static testMethod void getToken(){
        /***************** ETOUCHES custom Settings *****************/
        
        
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
            EM012_eTouchesAuthWS.getToken();
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        // Test End 
        System.test.stopTest();
        
    }
}