/** 
* @author Adolphe SONKO
* @date Creation 11/04/2017
* @date Modification 11/04/2017
* @description : SM018_SpeakerTriggerHandler Test Unit Test Class 
*/

@isTest
public class SM018_SpeakerTriggerHandlerTest {
    
    static testMethod void getSpeakerInsert(){
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            //Data preparation.
            //Events RecordTypeId = 0125E0000008YFf in DevProto
            //Events RecordTypeId = 0126E0000008XD9 in Partcopy
            //Events RecordTypeId = 01258000000cjmr in Partcopy
            Campaign camp = new Campaign(Name='Campaign to test Speakers', RecordTypeId ='01258000000cjmr',status='En cours', type='Autre',Start_Date_Time__c =DateTime.newInstance(2017, 3, 20, 16, 0, 0),End_Date_Time__c =DateTime.newInstance(2017, 3, 20, 19, 0, 0),Address_1__c='Musée du louvre',Address_2__c='Les Tuileries',Post_Code__c='75001',City__c='PAris',Country__c='France',Location_name__c= '3ème étage',Map_to_Venue__c='www.carmignac.com', TECH_ID_Schedule__c ='11041104');
            insert camp;
            Speaker__c sp = new Speaker__c(Name='Adolphe', Schedule_Key_Event__c='11041104', TECH_ID_Speaker_Schedule__c='567890', Schedule_Key_Session__c='1234');
            insert sp;
            System.debug('LId de la campagne rattachée au speaker avant insert'+sp);
            //  insert sp;
            System.debug('LId de la campagne rattachée au speaker after insert'+sp.Campaign__c);
            
            // Testing Result	
            // 	System.assertEquals(sp.Campaign__c, camp.Id);
            //	System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());        	
        }
        
        System.test.stopTest(); 
    }	
    
    
    static testMethod void getSpeakerUpdate(){
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //Data preparation.
            //Events RecordTypeId = 0125E0000008YFf in DevProto
            //Events RecordTypeId = 0126E0000008XD9 in Partcopy
            //Events RecordTypeId = 01258000000cjmr in Partcopy
            Campaign camp = new Campaign(Name='Campaign to test Speakers3', RecordTypeId ='01258000000cjmr',status='En cours', type='Autre',Start_Date_Time__c =DateTime.newInstance(2017, 3, 25, 12, 0, 0),End_Date_Time__c =DateTime.newInstance(2017, 3, 25, 17, 0, 0),Address_1__c='Musée du louvre',Address_2__c='Les Tuileries',Post_Code__c='75001',City__c='PAris',Country__c='France',Location_name__c= '1er étage',Map_to_Venue__c='www.carmignac.com', TECH_ID_Schedule__c ='11051105');
            insert camp;
            Campaign camp2 = new Campaign(Name='Campaign to test Speakers2', RecordTypeId ='01258000000cjmr',status='En cours', type='Autre',Start_Date_Time__c =DateTime.newInstance(2017, 3, 22, 15, 0, 0),End_Date_Time__c =DateTime.newInstance(2017, 3, 22, 18, 0, 0),Address_1__c='Richelieu',Address_2__c='Place Vendôme',Post_Code__c='75001',City__c='PAris',Country__c='France',Location_name__c= '2ème étage',Map_to_Venue__c='www.carmignac.com', TECH_ID_Schedule__c ='09876542');
            insert camp2;
            Speaker__c sp = new Speaker__c(Name='Adolphe', Schedule_Key_Event__c='11051105', TECH_ID_Speaker_Schedule__c='567890', Schedule_Key_Session__c='1234');
            insert sp;
            
            sp.Schedule_Key_Event__c='09876542';
            update sp;
            
            
            // Testing Result      	
            //	System.assertEquals(sp.Campaign__c, camp2.Id);
            //	System.assertEquals(testRequest.getMethod(), testRequestCTRL.getMethod());
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());        	
        }
        
        // Test End 
        System.test.stopTest(); 
        
    }	
    
}