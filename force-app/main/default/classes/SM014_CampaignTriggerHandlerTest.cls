@isTest
public class SM014_CampaignTriggerHandlerTest {
    static testMethod void onAfterInsert(){
        
        
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
            camp1.Etouches_invitation__c  = true;
            List<Campaign> listCamp = new List<Campaign>();
            listCamp.add(camp1) ;	
            
            Template_Etouches__c template = new Template_Etouches__c();
            template.Name = 'Template Test';
            template.FolderID__c = '43168';
            template.Sales_Team__c = 'FR';  
            template.Type__c = 'Survey';
            template.TemplateID__c = '184765';
            insert template;
            insert listCamp;
            
            //     camp1.Event_code_Etouches__c = '188118';
            
            //     update listCamp;
            //         SM014_CampaignTriggerHandler.callCloneEvent(camp1.Id, param.Token__c);
            CallCreateCampaignEtouchesAsync camCallCreate = new CallCreateCampaignEtouchesAsync(listCamp, 0 , 1);
            camCallCreate.executeNext(listCamp, 0 , 1);

            CallUpdateCampaignEtouchesAsync camCallupdate = new CallUpdateCampaignEtouchesAsync(listCamp, 0 , 1);
            camCallupdate.executeNext(listCamp, 0 , 1);
        }

        SM014_CampaignTriggerHandler handler = new SM014_CampaignTriggerHandler();
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
    
    
    static testMethod void onAfterUpdate(){
        
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
            camp1.Etouches_invitation__c  = true;
            camp1.Event_code_Etouches__c = '188118';  
            
            List<Campaign> listCamp = new List<Campaign>();
            listCamp.add(camp1) ;	
            Insert listCamp;	
            
            Category_Event__c categ = new Category_Event__c(Name='Category Test 1', Campaign__c=camp1.Id, Tech_Category_Event_ID_Etouches__c='1234'); 	
            camp1.Name = 'Test Campaign';
            List<Campaign> listCamp2 = new List<Campaign>();
            listCamp2.add(camp1);
            update listCamp2;
            
            
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
}