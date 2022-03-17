/** 
* @author
* @date 
* @date 
* @description : 
*/

@isTest
public class EM014_ScheduleTokenTest {
    
     static testMethod void EM014_ScheduleTokenTest(){
		
         
		User u = TestFactory.getStandardCarmignacUser();
        //insert u;
		
		
   		//Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            //Data preparation.
            TestFactory.createCustomSettings();
            WebserviceParameters__c param = new WebserviceParameters__c(
            Name ='EtouchesAPI', 
            Endpoint__c='https://qa.eiseverywhere.com/api/v2',
            key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
            Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',
            accountid__c='4740');
            insert param;
        	EM014_ScheduleToken m = new EM014_ScheduleToken();
            String sch = '0 21 11 * * ?';
            String jobID = system.schedule('EM014_ScheduleToken Test', sch, m);
            system.debug(jobID);
        }
        	// Test End 
        System.test.stopTest();	
        		

     //repeat the same for the rest of classes.
  	} 
}