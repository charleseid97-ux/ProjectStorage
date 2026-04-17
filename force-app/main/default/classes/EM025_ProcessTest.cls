/** 
* @author Briag GUEMARD
* @date Creation 15/04/2017
* @date Modification 15/04/2017
* @description : EM025_Process Unit Test Class 
*/
@isTest
private class EM025_ProcessTest {
    
    static testMethod void getListByIndex() {

        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            Process_Id__c processTemp = TestFactory.getProcessID();
            Insert processTemp;
            //Test method
            List<Process_Id__c> tempList = EM025_Process.getListByIndex(new Set<String> {processTemp.Index__c});
            
            // Results verification
            System.assertEquals(tempList.size(), 1);
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
 
        }

        // Test End 
        System.test.stopTest();
    }
    
    
}