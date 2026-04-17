/** 
* @author: Adolphe SONKO
* @date : Creation 08/04/2017
* @date : Modification 08/04/2017
* @description : EM016_Category Unit Test Class  .
*/

@isTest
public class EM016_CategoryTest {
    
    static testMethod void getAllCategoryEvent(){
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
            
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;	
            
            Category_Event__c categ = new Category_Event__c(Name='Category Test 1', Campaign__c=camp1.Id, Tech_Category_Event_ID_Etouches__c='1234');      
            HttpRequest testRequest = EM016_Category.getAllCategoryEvent(param, param.Token__c, '187855', camp1);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/xml');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c +  '/ereg/listCategories.xml' +'?accesstoken='+param.Token__c+ '&eventid='+'187855');
            
            testRequestCTRL.setMethod('GET');
            
            //Response testing GET All Category
            
            HttpResponse testResponse = EM016_Category.createAllCategory(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('<etouches><item><categoryid>201</categoryid><parentid>0</parentid><name>Event Exhibitor</name></item><item><categoryid>202</categoryid><parentid>0</parentid><name>Event Staff</name></item></etouches>');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');  
            
            //Insert Category
            EM016_Category.insertCategoryEvent(camp1, testResponse);
            //getListCategoryToInsert
            List<Category_Event__c> ListCategory = EM016_Category.getListCategoryToInsert(testResponse, camp1);
            
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());
            
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());
            
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries()) ;
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
    
    
}