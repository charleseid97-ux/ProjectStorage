@isTest
public  class DM025_ProcessTest {
    
    // Test User creation
    public static User userTest = TestFactory.getCarmignacUserTestApex();
    
    static testMethod void fakeTest(){
        
        User u = TestFactory.getStandardCarmignacUser();
        //insert u;
        
        System.runAs(userTest){  
            
            TestFactory.createCustomSettings();
            
            //Test Begin
            System.test.startTest();       
            
            System.runAs(u){
                DM025_Process.fakeMethod();
            }
            // Test End 
            System.test.stopTest();	
            
        }
        
        //repeat the same for the rest of classes.
    } 
}