@isTest
public class SM021_EtouchesProcessQueueTest {
    
    static testMethod void fakeTest(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            SM021_EtouchesProcessQueue.fakeMethod();
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
    
}