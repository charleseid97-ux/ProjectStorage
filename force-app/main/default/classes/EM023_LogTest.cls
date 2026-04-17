/** 
* @author Guemard Braig 
* @date Creation 11/04/2017
* @date Modification 11/04/2017
* @description : EM023_Log Unit Test Class 
*/
@isTest
private class EM023_LogTest {
    
    static testMethod void insertLogError() {
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            EM023_Log.errorToLog log1 = TestFactory.getSimpleLogToInsert();
            
            List<EM023_Log.errorToLog> listTest = new List<EM023_Log.errorToLog>();
            listTest.add(log1);
            
            
            List<EM023_Log.errorToLog> listTest2 = new List<EM023_Log.errorToLog>();
            EM023_Log.insertLogError(listTest);
            
            EM023_Log.insertLogError(listTest2);
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void insertLogErrorPRocess() {
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            EM023_Log.errorToLog log1 = TestFactory.getSimpleLogToInsert();
            
            List<EM023_Log.errorToLog> listTest = new List<EM023_Log.errorToLog>();
            listTest.add(log1);
            
            
            List<EM023_Log.errorToLog> listTest2 = new List<EM023_Log.errorToLog>();
            EM023_Log.insertLogErrorScan(listTest,'Process ID String');
            
            EM023_Log.insertLogErrorScan(listTest2,'Process Fail');
            
            
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void  getAllErrorLogFromProcess(){
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            Interface_Log__c log1 = TestFactory.getSimpleLogEtouchesToInsert();
            Insert log1;
            String processSearched = '123456';
            List<Interface_Log__c> listTest = EM023_Log.getAllErrorLogFromProcess(processSearched);
            
            System.assertEquals(listTest.size(), 1);
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
            
        }
        
        
        // Test End 
        System.test.stopTest();
        
        
    }
    
    
    
}