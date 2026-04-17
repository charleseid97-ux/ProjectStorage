@isTest
public   class SM022_EtouchesProcessAttendeeTest {
    static testMethod void fakeTest(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            SM022_EtouchesProcessAttendee.fakeMethod();
        }
        // Test End 
        System.test.stopTest();	
        
        
        
        //repeat the same for the rest of classes.
    } 
}