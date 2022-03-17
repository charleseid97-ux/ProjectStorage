/** 
* @author Briag Guemard
* @date Creation 11/04/2016
* @date Modification 11/04/2016
* @description : EM019_TemplateEtouches Unit Test Class 
*/
@isTest
private class EM019_TemplateEtouchesTest {
    
    static testMethod void getAllTemplateEtouches(){
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            Template_Etouches__c test = new Template_Etouches__c();
            test.FolderID__c='555';
            test.Sales_Team__c='BS';
            test.TemplateID__c='666';
            test.Type__c='Survey';
            insert test;
            
            Template_Etouches__c Test2 = new Template_Etouches__c();
            Test2.FolderID__c='111';
            Test2.Sales_Team__c='BS';
            Test2.TemplateID__c='999';
            Test2.Type__c='Survey';
            
            insert Test2;
            // Methods Calls
            List<Template_Etouches__c> listTest = EM019_TemplateEtouches.getAllTemplateEtouches();
            
            // Results verification	
            System.assertEquals(listTest.size(), 2);
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
            
        }
        
    }
    
    
}