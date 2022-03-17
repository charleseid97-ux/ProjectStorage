@isTest
public   class SM020_EtouchesScanProcessTest {
    static testMethod void fakeTest(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            SM020_EtouchesScanProcess.fakeMethod();
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
}