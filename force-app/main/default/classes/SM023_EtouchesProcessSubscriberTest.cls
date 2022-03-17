@isTest
public class SM023_EtouchesProcessSubscriberTest {
    static testMethod void SM023_EtouchesProcessSubscriber(){
        
        
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
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id, CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '72320755');
            insert campMember;
            
            //Process ID 
            Datetime Prcss = Datetime.now();
            String processId = Prcss.format('yyyyMMddkkmmss');
            
            Process_Id__c tempProcess = new Process_Id__c();
            tempProcess.Index__c = processId;
            
            tempProcess.Date_Process__c = Date.today();
            insert tempProcess;
            
            Map<String,String> mapMemberStatusBySubscriberId = new Map<String,String>();
            mapMemberStatusBySubscriberId.put('72320755','Sent'); 
            Map<String,String> mapMemberStatusBySubscriberIdTemp = new Map<String,String>();
            Map<String,String> mapEmailByAttendeeIdFinal  = new Map<String,String>();
            //    mapEmailByAttendeeIdFinal.put('12345','test@test.com');
            
            SM023_EtouchesProcessSubscriber newjobS = new SM023_EtouchesProcessSubscriber(tempProcess,Datetime.now(),camp1,1,mapMemberStatusBySubscriberId, null);
            ID jobIDS = System.enqueueJob(newjobS);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
    
}