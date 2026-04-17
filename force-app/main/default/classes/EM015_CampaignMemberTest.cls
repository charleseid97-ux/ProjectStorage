/** 
* @author: Adolphe SONKO
* @date : Creation 08/04/2017
* @date : Modification 08/04/2017
* @description : EM015_CampaignMember Unit Test Class  .
*/

@isTest
public class EM015_CampaignMemberTest {
    
    static testMethod void getAllCMFromCampaign() {
        
        
        
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
            
            lead ld = TestFactory.getSimpLeadTestSetProfile();
            insert ld;
            CampaignMember campMember2 = new CampaignMember(LeadId = ld.id,CampaignId = camp1.Id);
            insert campMember2;
            
            List<String> contactsIds = new  List<String>();
            contactsIds.add(testContact1.Id);
            List<String> leadsIds = new  List<String>();
            leadsIds.add(ld.Id);
            List<CampaignMember> listCampMember = new List<CampaignMember>();
            listCampMember.add(campMember);
            
            List<CampaignMember> found_CampaignMemberList =  EM015_CampaignMember.getAllCMFromCampaign(camp1,  listCampMember);
            List<CampaignMember> found_CampaignMemberList2 =  EM015_CampaignMember.getListByContactIds(contactsIds);
            List<CampaignMember> found_CampaignMemberList3 =  EM015_CampaignMember.getListByLeadIds(leadsIds);
            
            // Results verification
            System.assertEquals(found_CampaignMemberList.size(), 1);
            System.assertEquals(found_CampaignMemberList2.size(), 1);
            //System.assertEquals(found_CampaignMemberList3.size(), 1);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void getListCampaignMember() {
        
        
        
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
            List<Id> listCampMemberId = new List<Id>();
            listCampMemberId.add(campMember.Id);
            
            List<CampaignMember> found_CampaignMemberList =  EM015_CampaignMember.getListCampaignMember(listCampMemberId);
            
            // Results verification
            System.assertEquals(found_CampaignMemberList.size(), 1);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void getCreateSubscriber(){
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
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id, CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            HttpRequest testRequest = EM015_CampaignMember.getPostCreateSubscriber(param, param.Token__c,'187927', '85478', campMember, categ.Tech_Category_Event_ID_Etouches__c);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            String status = 'Invited';
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/emarketing/createSubscriber.json'+ 
                                        'accesstoken='+param.Token__c+
                                        '&email='+campMember.Event_Email__c+
                                        '&listid='+'85478'+
                                        //'&accountid='+campMember.CompanyOrAccount+
                                        '&prefix='+campMember.Salutation+
                                        '&fname='+campMember.FirstName+
                                        '&lname='+campMember.LastName+
                                        '&status='+status+
                                        /*'&addres1='+campMember.Street+
'&city='+campMember.City+
'&state='+campMember.State+
'&zip='+campMember.PostalCode+*/
                                        '&categoryid='+Categ+
                                        '&eventid='+'187927'+
                                        
                                        '&title='+campMember.Job_Title__c+
                                        '&company='+campMember.Company_T__c+
                                        '&address1='+campMember.Address_Line_1__c+
                                        '&city='+campMember.City__c+
                                        '&zip='+campMember.Zip__c+
                                        '&country='+campMember.Country__c+
                                        '&wphone='+campMember.Phone__c+
                                        '&mphone='+campMember.Mobile__c+
                                        '&account2='+campMember.Language__c+
                                        '&sendername='+campMember.Contact_Owner__c+
                                        '&senderemail='+campMember.Owner_email__c);
            
            testRequestCTRL.setMethod('POST');
            
            //Response testing Reset Password 
            
            HttpResponse testResponse = EM015_CampaignMember.createSubscriber(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('<etouches><subscriberid>72320755</subscriberid></etouches>');
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
        
        
        
        //repeat the same for the rest of classes.
    } 
    
    
    static testMethod void getPutUpdateSubscriber(){
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
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id, CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            HttpRequest testRequest = EM015_CampaignMember.getPutUpdateSubscriber(param, param.Token__c, campMember, categ.Tech_Category_Event_ID_Etouches__c);
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL.setEndpoint(param.Endpoint__c +  '/emarketing/updateSubscriber.json'+
                                        'accesstoken='+param.Token__c+
                                        'subscriberid='+campMember.TECH_ID_Subscriber__c+
                                        //'&listid='+campaign.TECH_Mailing_List_ID_Etouches__c+
                                        //'&accountid='+campMember.CompanyOrAccount+
                                        '&email='+campMember.Event_Email__c+
                                        '&prefix='+campMember.Salutation+
                                        '&fname='+campMember.FirstName+
                                        '&lname='+campMember.LastName+
                                        //'&title='+campMember.Title+
                                        //'&title='+campMember.Job_Title__c+
                                        '&status='+'Subscribed'+
                                        //'&addres1='+campMember.Street+
                                        '&categoryid='+Categ+
                                        //'&city='+campMember.City+
                                        //'&state='+campMember.State+
                                        //'&zip='+campMember.PostalCode+
                                        
                                        
                                        
                                        
                                        '&title='+campMember.Job_Title__c+
                                        '&company='+campMember.Company_T__c+
                                        '&address1='+campMember.Address_Line_1__c+
                                        '&city='+campMember.City__c+
                                        '&zip='+campMember.Zip__c+
                                        '&country='+campMember.Country__c+
                                        '&wphone='+campMember.Phone__c+
                                        '&mphone='+campMember.Mobile__c+
                                        '&account2='+campMember.Language__c+
                                        '&sendername='+campMember.Contact_Owner__c+
                                        '&senderemail='+campMember.Owner_email__c);
            
            testRequestCTRL.setMethod('PUT');
            
            /*******************************************/
            campMember.Status = 'Unsubscribed';
            update campMember;
            
            HttpRequest testRequest2 = EM015_CampaignMember.getPutUpdateSubscriber(param, param.Token__c, campMember, categ.Tech_Category_Event_ID_Etouches__c);
            
            HttpRequest testRequestCTRL2 =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL2.setEndpoint(param.Endpoint__c +  '/emarketing/updateSubscriber.json'+
                                         'accesstoken='+param.Token__c+
                                         'subscriberid='+campMember.TECH_ID_Subscriber__c+
                                         //'&listid='+campaign.TECH_Mailing_List_ID_Etouches__c+
                                         //'&accountid='+campMember.CompanyOrAccount+
                                         '&prefix='+campMember.Salutation+
                                         '&email='+campMember.Event_Email__c+
                                         '&fname='+campMember.FirstName+
                                         '&lname='+campMember.LastName+
                                         //'&title='+campMember.Title+
                                         ///'&title='+campMember.Job_Title__c+
                                         '&categoryid='+Categ+
                                         '&status='+'Unsubscribed'+
                                         //'&addres1='+campMember.Street+
                                         //'&city='+campMember.City+
                                         //'&state='+campMember.State+
                                         //'&zip='+campMember.PostalCode+
                                         
                                         
                                         '&title='+campMember.Job_Title__c+
                                         '&company='+campMember.Company_T__c+
                                         '&address1='+campMember.Address_Line_1__c+
                                         '&city='+campMember.City__c+
                                         '&zip='+campMember.Zip__c+
                                         '&country='+campMember.Country__c+
                                         '&wphone='+campMember.Phone__c+
                                         '&mphone='+campMember.Mobile__c+
                                         '&account2='+campMember.Language__c+
                                         '&sendername='+campMember.Contact_Owner__c+
                                         '&senderemail='+campMember.Owner_email__c);
            
            testRequestCTRL2.setMethod('PUT');
            
            /*******************************************/
            campMember.Status = 'Invited';
            update campMember;
            
            HttpRequest testRequest3 = EM015_CampaignMember.getPutUpdateSubscriber(param, param.Token__c, campMember, categ.Tech_Category_Event_ID_Etouches__c);
            
            HttpRequest testRequestCTRL3 =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            
            testRequestCTRL3.setEndpoint(param.Endpoint__c +  '/emarketing/updateSubscriber.json'+
                                         'accesstoken='+param.Token__c+
                                         'subscriberid='+campMember.TECH_ID_Subscriber__c+
                                         //'&listid='+campaign.TECH_Mailing_List_ID_Etouches__c+
                                         //'&accountid='+campMember.CompanyOrAccount+
                                         '&prefix='+campMember.Salutation+
                                         '&email='+campMember.Event_Email__c+
                                         '&fname='+campMember.FirstName+
                                         '&lname='+campMember.LastName+
                                         //'&title='+campMember.Title+
                                         ///'&title='+campMember.Job_Title__c+
                                         '&categoryid='+Categ+
                                         '&status='+'Invited'+
                                         //'&addres1='+campMember.Street+
                                         //'&city='+campMember.City+
                                         //'&state='+campMember.State+
                                         //'&zip='+campMember.PostalCode+
                                         
                                         
                                         '&title='+campMember.Job_Title__c+
                                         '&company='+campMember.Company_T__c+
                                         '&address1='+campMember.Address_Line_1__c+
                                         '&city='+campMember.City__c+
                                         '&zip='+campMember.Zip__c+
                                         '&country='+campMember.Country__c+
                                         '&wphone='+campMember.Phone__c+
                                         '&mphone='+campMember.Mobile__c+
                                         '&account2='+campMember.Language__c+
                                         '&sendername='+campMember.Contact_Owner__c+
                                         '&senderemail='+campMember.Owner_email__c);
            
            testRequestCTRL3.setMethod('PUT');
            
            
            //Response testing Reset Password 
            
            HttpResponse testResponse = EM015_CampaignMember.updateSubscriber(testRequest,null);
            
            HttpResponse testResponseValid =  new HttpResponse();
            
            testResponseValid.setBody('<etouches><subscriberid>72320755</subscriberid></etouches>');
            testResponseValid.setStatusCode(200);
            testResponseValid.setStatus('OK');
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            System.assertEquals(testRequest2.getHeader('Content-Type'), testRequestCTRL2.getHeader('Content-Type'));
            System.assertEquals(testRequest3.getHeader('Content-Type'), testRequestCTRL3.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            System.assertEquals(testRequest2.getMethod(), testRequestCTRL2.getMethod());
            System.assertEquals(testRequest3.getMethod(), testRequestCTRL3.getMethod());
            
            System.assertEquals(testResponseValid.getBody(), testResponse.getBody());
            
            System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());
            
            System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        // Test End 
        System.test.stopTest();	
        
        
        //repeat the same for the rest of classes.
    } 
    
    static testMethod void getPutUpdateDeleteSubscriber(){
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
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id, CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id);
            insert campMember;
            HttpRequest testRequest = EM015_CampaignMember.getPutUpdateDeleteSubscriber(param, param.Token__c,'72320755');
            
            HttpRequest testRequestCTRL =  new HttpRequest();
            
            //	testRequestCTRL.setHeader('Content-Type','application/json');
            String status = 'Invited';
            testRequestCTRL.setEndpoint(param.Endpoint__c + '/emarketing/createSubscriber.json'+ 
                                        'accesstoken='+param.Token__c+
                                        '&subscriberid='+'72320755'+
                                        '&deleted=1');
            
            testRequestCTRL.setMethod('PUT');
            
            //Response testing Reset Password 
            
            /*	HttpResponse testResponse = EM015_CampaignMember.createSubscriber(testRequest,null);

HttpResponse testResponseValid =  new HttpResponse();

testResponseValid.setBody('{"subscriberid":"72320755"}');
testResponseValid.setStatusCode(200);
testResponseValid.setStatus('OK'); */
            
            // Testing Results
            
            System.assertEquals(testRequest.getHeader('Content-Type'), testRequestCTRL.getHeader('Content-Type'));
            
            System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            /*   System.assertEquals(testResponseValid.getBody(), testResponse.getBody());

System.assertEquals(testResponseValid.getStatusCode(), testResponse.getStatusCode());

System.assertEquals(testResponseValid.getStatus(), testResponse.getStatus()); */
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
}