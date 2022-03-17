/** 
* @author Briag Guemard
* @date Creation 10/04/2017
* @date Modification 10/04/2017
* @description : EM011_Campaign Unit Test Class 
*/
@isTest
public class EM011_CampaignTest {
    
    static testMethod void getAllListByIds() {
        
        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();
        
        // Test Begin
        
        System.runAs(u){
            System.test.startTest(); 
            
            TestFactory.createCustomSettings();
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;
            // Methods Calls
            
            List<Id> listCamptoTest = new List<Id>();
            listCamptoTest.add(camp1.Id);
            
            List<Campaign> found_CampaignList =  EM011_Campaign.getAllListByIds(listCamptoTest);
            List<Campaign> found_CampaignList2 = EM011_Campaign.getListByIds(new Set<id>{camp1.Id});
            
            
            // Results verification
            System.assertEquals(found_CampaignList.size(), 1);
            System.assertEquals(found_CampaignList2.size(), 1);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void getListCampaign() {
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Methods Calls
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            camp1.Event_code_Etouches__c = '186867';
            Insert camp1;
            
            Campaign camp2 = TestFactory.getSimpleCampaignEvents();
            camp2.Event_code_Etouches__c = '186863';
            camp2.TECH_Mailing_List_ID_Etouches__c = '123456';
            Insert camp2;
            List<Campaign> listCamp1 = EM011_Campaign.ListEvent(new Set<String>{camp1.Event_code_Etouches__c});
            List<Campaign> listCamp2 = EM011_Campaign.ListCampaign(new List<String>{camp1.Event_code_Etouches__c});
            Campaign camp3 = EM011_Campaign.campaignByEtouchesEventID('186867', new List<Campaign>{camp1,camp2});
            List<String> mailingList = EM011_Campaign.ListMailingListID(new List<String>{'186863','0987654'});
            
            
            // Results verification
            System.assertEquals(listCamp1.size(), 1);
            System.assertEquals(listCamp2.size(), 1);
            System.assertEquals(camp3.Id, camp1.Id);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void  getCreatePutCLONE()
    {
        /***************** Etouches custom Settings *****************/
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
            insert param;
            
            
            String tempToken = EM013_Token.getToken();
            
            
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            
            Insert camp1;
            
            HttpRequest testRequest = EM011_Campaign.getCreatePutCLONE(param,tempToken,'250','500',camp1.Name);
            
            String testEndpoin = 'https://qa.eiseverywhere.com/api/v2' +'/global/cloneEvent.xml';
            
            String requesttestBody = 'accesstoken=' + tempToken + '&eventid='+'250' + '&folderid=' + '500' + '&name='+camp1.Name;
            
            String methodTest = 'PUT';
            
            
            //Response testing Update Event 
            
            HttpResponse testResponse = EM011_Campaign.cloneEvent(testRequest,null);
            
            
            // Results verification
            System.assertEquals(testRequest.getEndpoint(),testEndpoin);
            
            System.assertEquals(testRequest.getBody(),requesttestBody);
            
            System.assertEquals(testRequest.getMethod(),methodTest);
            
            
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
            
        }
        // Test End 
        System.test.stopTest();  
        
    }
    
    
    static testMethod void getPutUpateEvent(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
            insert param;
            
            
            String tempToken = EM013_Token.getToken();
            
            
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.Registration_Closed_Date__c = datetime.now();
            Insert camp1;
            HttpRequest testRequest = EM011_Campaign.getPutUpateEvent(param,tempToken,camp1,'500',u,u);
            
            String testEndpoin = 'https://qa.eiseverywhere.com/api/v2' +'/ereg/updateEvent.xml' + '?' +'accesstoken=' + tempToken ;
            String methodTest = 'PUT';
            
            
            datetime myStartDate = camp1.Start_Date_Time__c;
            
            datetime myEndDate = camp1.End_Date_Time__c;
            
            String stringStartDate;
            String stringStartTime;
            String stringEndDate;
            String stringEndTime;
            
            if (myEndDate != null){
                stringEndDate = myEndDate.format('yyyy-MM-dd');
                stringEndTime = myEndDate.format('kk:mm');
            }
            
            if(myStartDate != null){
                stringStartDate = myStartDate.format('yyyy-MM-dd');
                stringStartTime = myStartDate.format('kk:mm');
            }
            
            String etouchesStartDate = camp1.Event_Local_Start_Time__c.substringBefore(' ');
            String etouchesStartTime = camp1.Event_Local_Start_Time__c.substringAfter(' ');
            String etouchesEndDate = camp1.Event_Local_End_Time__c.substringBefore(' ');
            String etouchesEndTime = camp1.Event_Local_End_Time__c.substringAfter(' ');
            
            String ClosedDate_str;
            String ClosedTime_str;
            
            datetime ClosedDate = camp1.Registration_Closed_Date__c;
            if(ClosedDate != null){
                ClosedDate_str = ClosedDate.format('yyyy-MM-dd');
                ClosedTime_str = ClosedDate.format('kk:mm');
                
            }
            String requestTestBody = 'eventid='+'500'+
                '&name='+camp1.name+
                '&startdate='+etouchesStartDate+
                '&starttime='+etouchesStartTime+
                '&enddate='+etouchesEndDate+
                '&endtime='+etouchesEndTime+
                '&locationname='+camp1.Location_name__c+
                '&address1='+camp1.Address_1__c+
                '&address2='+camp1.Address_2__c+
                '&postcode='+camp1.Post_Code__c+
                '&city='+camp1.City__c+
                '&programmanager='+u.Name+
                '&clientcontact='+u.Name+
                '&country='+camp1.Country__c+
                '&map='+camp1.Map_to_Venue__c+
                '&max_reg='+camp1.Maximum_registration__c+
                '&timezone='+camp1.Local_zone__c+
                '&closedate='+ClosedDate_str+
                '&closetime='+ClosedTime_str;
            
            
            //Response testing Update Event 
            
            HttpResponse testResponse = EM011_Campaign.upateEvent(testRequest,null);
            
            //    EM011_Campaign.updateEtouhcheData(camp1, '153948', testResponse);
            
            // Results verification
            System.assertEquals(testRequest.getEndpoint(),testEndpoin);
            
            //	System.assertEquals(testRequest.getBody(),requestTestBody);
            
            System.assertEquals(testRequest.getMethod(),methodTest);
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        // Test End 
        System.test.stopTest();  
        
    }
    
    static testMethod void getPostCreateMailingList(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
            insert param;
            
            
            String tempToken = EM013_Token.getToken();
            
            
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            Insert camp1;
            
            HttpRequest testRequest = EM011_Campaign.getPostCreateMailingList(param,tempToken,'500',camp1);
            
            
            String testEndpoin = 'https://qa.eiseverywhere.com/api/v2' +'/emarketing/createMailinglist.xml';
            
            String requestTestBody = 'accesstoken='+tempToken+
                '&name='+camp1.Name+
                '&status='+'Active'+
                '&created='+camp1.CreatedDate+
                '&lastmodified='+camp1.LastModifiedDate+
                '&eventid='+'500';
            
            String methodTest = 'POST';
            
            
            //Response testing Create Mailing List  
            
            HttpResponse testResponse = EM011_Campaign.createMailinglist(testRequest,null);
            
            // Results verification
            System.assertEquals(testRequest.getEndpoint(),testEndpoin);
            
            System.assertEquals(testRequest.getBody(),requestTestBody);
            
            System.assertEquals(testRequest.getMethod(),methodTest);
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
            
        }
        // Test End 
        System.test.stopTest();    
        
        
    }
    
    static testMethod void getPutUpdateMailingList(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
            insert param;
            
            
            String tempToken = EM013_Token.getToken();
            
            
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            
            Insert camp1;
            
            HttpRequest testRequest = EM011_Campaign.getPutUpdateMailingList(param,tempToken,camp1);
            
            String testEndpoin = 'https://qa.eiseverywhere.com/api/v2' +'/emarketing/updateMailinglist.xml' + '?accesstoken='+tempToken;
            
            String requestTestBody = 'name='+camp1.Name+
                '&listid='+camp1.TECH_Mailing_List_ID_Etouches__c+
                '&status='+'Active'+
                '&created='+camp1.CreatedDate+
                '&lastmodified='+camp1.LastModifiedDate+
                '&eventid='+camp1.Event_code_Etouches__c;
            
            String methodTest = 'PUT';
            
            //Response testing Update Mailing List  
            
            HttpResponse testResponse = EM011_Campaign.updateMailinglist(testRequest,null);
            
            // Results verification
            System.assertEquals(testRequest.getEndpoint(),testEndpoin);
            
            System.assertEquals(testRequest.getBody(),requestTestBody);
            
            System.assertEquals(testRequest.getMethod(),methodTest);
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
            
        }
        // Test End 
        System.test.stopTest();         
    }
    
    
    
    
    static testMethod void getEventListsByScheduleId(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
            insert param;

            String tempToken = EM013_Token.getToken();

            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.TECH_ID_Schedule__c='555';
            //camp1.TECH_Mailing_List_ID_Etouches__c='666';*/	

            Insert camp1;
            List<String> ListEventID = new List<String>();
            ListEventID.add(camp1.TECH_ID_Schedule__c);
            
            system.debug('BGU TEST ' + camp1.TECH_ID_Schedule__c);
            
            List<Campaign> testList= EM011_Campaign.getEventListsByScheduleId(ListEventID);
            
            system.debug('BGU TEST ' + camp1.TECH_ID_Schedule__c);
            
            
            // Results verification
            System.assertEquals(testList.size(), 1);
            
            System.assertEquals(testList.get(0).Id, camp1.Id);  
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        // Test End 
        System.test.stopTest();
        
        
    }
    
    
    /*
static testMethod void ListMailingListID(){


WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
insert param;


String tempToken = EM013_Token.getToken();


// Data Preparation
Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesTOSend();
//camp1.Event_code_Etouches__c='555';
//camp1.TECH_Mailing_List_ID_Etouches__c='666';


Insert camp1;

// Test User creation

User u = TestFactory.getStandardCarmignacUser();
//insert u;

//Test Begin
System.test.startTest();       

System.runAs(u){

List<String> ListEventID = new List<String>();
ListEventID.add(camp1.Event_code_Etouches__c);

system.debug('BGU TEST ' + camp1.Event_code_Etouches__c);

system.debug('BGU TEST ' + camp1.TECH_Mailing_List_ID_Etouches__c);

List<String> testList= EM011_Campaign.ListMailingListID(ListEventID);


System.assertEquals(testList.size(), 1);

System.assertEquals(testList.get(0), camp1.TECH_Mailing_List_ID_Etouches__c);

System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());

}
// Test End 
System.test.stopTest();


}*/
    
    
    
    // BGU TODO LATER
    /* 
static testMethod void createMailinglist(){




}


static testMethod void  updateEtouhcheData(){
WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
insert param;


String tempToken = EM013_Token.getToken();


// Data Preparation
Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();

Insert camp1;

// Test User creation

User u = TestFactory.getStandardCarmignacUser();
//insert u;

//Test Begin
System.test.startTest();       

System.runAs(u){

//EM011_Campaign.updateEtouhcheData
//HttpRequest responseTest = EM011_Campaign.getPostCreateMailingList(param,tempToken,'500',camp1);


}
// Test End 
System.test.stopTest();

}*/
    
    /*
static testMethod void fakeTest(){

User u = TestFactory.getStandardCarmignacUser();
//insert u;


//Test Begin
System.test.startTest();       

System.runAs(u){
EM011_Campaign.fakeMethod();
}
// Test End 
System.test.stopTest();	



//repeat the same for the rest of classes.
} */
    
    
}