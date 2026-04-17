@isTest
public class SCH_BATCH018_CountLegalEntCompany_TEST {
    
    static testMethod void SCH_BATCH018_CountLegalEntCompany_TEST (){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest();
            
            
            SCH_BATCH018_CountLegalEntCompany sh1 = new SCH_BATCH018_CountLegalEntCompany();
            String sch = '0 0 23 * * ?'; 
            system.schedule('Test', sch, sh1);
            
        }
        
        // Test End 
        System.test.stopTest();
        
        //repeat the same for the rest of classes.
        
    }
}