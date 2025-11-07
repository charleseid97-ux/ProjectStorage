/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
public class SM016_CampaignMemberTriggerHandlerTest {

    static testMethod void SM016_CampaignMemberTriggerHandlerTest(){
        
        
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
            camp1.Event_code_Etouches__c = '118819' ; 
            camp1.TECH_Mailing_List_ID_Etouches__c = '85265' ;
            Insert camp1;
            
            Campaign camp2 = TestFactory.getSimpleCampaignEvents();
            camp2.Event_code_Etouches__c = '113814' ;
            camp2.TECH_Mailing_List_ID_Etouches__c = '85279' ;
            Insert camp2;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '752809');
            
            CampaignMember campMember2 = new CampaignMember(ContactId = testContact1.id,CampaignId = camp2.Id, Category_Event_lookup__c=categ.Id); 
            campMember2.TECH_ID_Subscriber__c = '758124' ;
            insert campMember2;
            campMember2.Status = 'Invited';
            insert campMember;            	
            campMember2.Bounce__c = 'Test' ;
            campMember2.Status = 'Attended';
            update campMember2;
            
            List<CampaignMember> camList = new List<CampaignMember>();
            List<String> camIdList = new List<String>();

            camList.add(campMember2);
            camList.add(campMember);
            camIdList.add(campMember2.Id);
            camIdList.add(campMember.Id);
            
            Map<Id,String> mapEventIdByCampMem = new Map<Id,String>(); 
            mapEventIdByCampMem.put(campMember.Id,camp1.Event_code_Etouches__c);
            mapEventIdByCampMem.put(campMember2.Id,camp2.Event_code_Etouches__c);

            Map<Id,String> mapMailing_List_IDByCampMem = new Map<Id,String>();          
            mapMailing_List_IDByCampMem.put(campMember.Id,camp1.TECH_Mailing_List_ID_Etouches__c);                        
            mapMailing_List_IDByCampMem.put(campMember2.Id,camp2.TECH_Mailing_List_ID_Etouches__c);                        

            
            SM016_CallCreateSubscriberEtouchesAsync camCallCreate = new SM016_CallCreateSubscriberEtouchesAsync(camList, 0 , 1);
            camCallCreate.executeNext(camList, 0 , 1);
            
            SM016_CallUpdateSubscriberEtouchesAsync camCallupdate = new SM016_CallUpdateSubscriberEtouchesAsync(camList, 0 , 1);
            camCallupdate.executeNext(camList, 0 , 1);
            
            SM016_CallDeleteSubscriberEtouchesAsync camCallDelete = new SM016_CallDeleteSubscriberEtouchesAsync(camIdList, 0 , 1);
            camCallDelete.executeNext(camIdList, 0 , 1);
        }
        
        // Test End 
        System.test.stopTest();	
        
        //repeat the same for the rest of classes.
    }

    static testMethod void addBatch(){


        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();
        u.BypassProcessBuilders__c = true;
        u.BypassApexTriggers__c = 'UserAfterInsert;UserAfterUpdate';

        update u;
        System.runAs(u){
            // Test Begin

            TestFactory.createCustomSettings();
            integer batchsize = 40;
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                    Name ='EtouchesAPI',
                    Endpoint__c='https://qa.eiseverywhere.com/api/v2',
                    key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                    Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',
                    accountid__c='4740');

            insert param;


            Campaign camp2 = TestFactory.getSimpleCampaignEvents();
            camp2.Event_code_Etouches__c = '113814' ;
            camp2.TECH_Mailing_List_ID_Etouches__c = '85279' ;
            Insert camp2;

            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;


            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp2.Id ,Tech_Category_Event_ID_Etouches__c='1234');
            insert categ;

            List<contact> contacts = new List<Contact>();
            List<CampaignMember> campaignMembers = new List<CampaignMember>();
            List<Campaign> campaigns = new List<Campaign>();

            for (Integer i = 0; i < batchsize ; i++) {
                Campaign campaign = TestFactory.getSimpleCampaignEvents();
                campaign.Event_code_Etouches__c = '11381'+i ;
                campaign.TECH_Mailing_List_ID_Etouches__c = '85279'+i ;

                campaigns.add(campaign);
            }
            insert campaigns;

            for (Integer i = 0; i < batchsize ; i++) {

                contacts.add(TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName '+i,'LastNameTestCarmignac '+String.valueOf(Math.round(Math.random()*1000)),'6543234'+i,'TechwbesiteId'+i,
                        'mail@mail'+i+'.com','mail@mail'+i+'.com','mail@mail'+i+'.com'));
            }
            insert contacts;

            System.test.startTest();
            for (Integer i = 0; i < batchsize ; i++) {

                campaignMembers.add(new CampaignMember(
                        ContactId = contacts[i].id,
                        CampaignId = campaigns[i].Id,
                        Category_Event_lookup__c=categ.Id,
                        TECH_ID_Subscriber__c = 'aaaa'+i
                )
                );
            }

            insert campaignMembers;

            update  campaignMembers;

        }

        // Test End
        System.test.stopTest();

        //repeat the same for the rest of classes.
    }

    static testMethod void DeleteSubscriberTest(){
        
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
            camp1.Event_code_Etouches__c = '118819' ; 
            camp1.TECH_Mailing_List_ID_Etouches__c = '85265' ;
            Insert camp1;
            
            Campaign camp2 = TestFactory.getSimpleCampaignEvents();
            camp2.Event_code_Etouches__c = '113814' ;
            camp2.TECH_Mailing_List_ID_Etouches__c = '85279' ;
            Insert camp2;
            
            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;
            
            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');   
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '752809');
            insert campMember;	
            delete campMember;
        }
        // Test End 
        System.test.stopTest();	
        
        //repeat the same for the rest of classes.
    }

    static testMethod void intializeCampaignMemberTest(){

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
            camp1.Event_code_Etouches__c = '118819' ;
            camp1.TECH_Mailing_List_ID_Etouches__c = '85265' ;
            Insert camp1;

            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;

            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            testContact1.Subscriber__c = true;
            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '752809');
            insert campMember;

        }

        // Test End
        System.test.stopTest();

        //repeat the same for the rest of classes.
    }

    static testMethod void updateEventOptOutTest(){

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
            camp1.Event_code_Etouches__c = '118819' ;
            camp1.TECH_Mailing_List_ID_Etouches__c = '85265' ;
            Insert camp1;

            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;

            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
            Lead testLead1 = TestFactory.getSimpleLead();

            insert testContact1;
            insert testLead1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');
            insert categ;


            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '752809');
            CampaignMember campMember2 = new CampaignMember(LeadId = testLead1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '752810');
            insert new List<CampaignMember>{campMember, campMember2};

            campMember.Subscriber__c = true;
            campMember2.Subscriber__c = true;
            update new List<CampaignMember>{campMember, campMember2};
        }

        // Test End
        System.test.stopTest();

        //repeat the same for the rest of classes.
    }

    static testMethod void updateLastFieldEventTest(){

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
            camp1.Event_code_Etouches__c = '118819' ;
            camp1.TECH_Mailing_List_ID_Etouches__c = '85265' ;
            Insert camp1;


            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;

            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');

            insert testContact1;
            Category_Event__c categ = new Category_Event__c(Name='Category 1',Campaign__c =camp1.Id ,Tech_Category_Event_ID_Etouches__c='1234');
            insert categ;
            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id,CampaignId = camp1.Id, Category_Event_lookup__c=categ.Id, TECH_ID_Subscriber__c = '752809');
            campMember.Status = 'Invited';
            insert campMember;

            campMember.Subscriber__c = true;
            campMember.Status = 'Attended';
            update campMember;
        }

        // Test End
        System.test.stopTest();

        //repeat the same for the rest of classes.
    }

    static testMethod void TEST_UnUsedMethod(){

        SM016_CampaignMemberTriggerHandler handler = new SM016_CampaignMemberTriggerHandler();

        handler.BeforeUpdate(null, null);
        handler.BeforeDelete(null);
        //handler.AfterInsert(null);
        handler.AfterDelete(null);
        handler.AfterUndelete(null);

    }
}