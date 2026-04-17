/** 
* @author
* @date 
* @date 
* @description : 
*/

@isTest
public   class SM20_EtouchesBoutonTest {
    
    static testMethod void fakeTest(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            
            SM20_EtouchesBouton.fakeMethod();
        }
        // Test End 
        System.test.stopTest();			
        
        //repeat the same for the rest of classes.
    }     
}