@isTest
public class DM026_CategoryEventTest {
    
    // Test User creation
    public static User userTest = TestFactory.getCarmignacUserTestApex();
    static testMethod void fakeTest(){
        
        system.runAs(userTest){                    
            
            TestFactory.createCustomSettings();
            
            
            //Test Begin
            System.test.startTest();       
            
            DM026_CategoryEvent.fakeMethod();          
            // Test End 
            System.test.stopTest();	
            
        }
        
        //repeat the same for the rest of classes.
    } 
}