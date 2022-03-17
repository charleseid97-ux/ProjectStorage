@isTest
public class BATCH003_UpdateLEntities_Scheduler_TEST {
    
    static testMethod void BATCH003_UpdateLEntities_Scheduler_TEST(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest();
            
            
            BATCH003_UpdateLegalEntities_Scheduler sh1 = new BATCH003_UpdateLegalEntities_Scheduler();
            String sch = '0 0 23 * * ?'; system.schedule('Test', sch, sh1);
            
        }
        
        // Test End 
        System.test.stopTest();
        
        //repeat the same for the rest of classes.
        
    }
}