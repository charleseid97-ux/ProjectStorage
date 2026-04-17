/** 
* @author Briag GUEMARD
* @date Creation 15/04/2017
* @date Modification 15/04/2017
* @description : EM024_CategoryEvent Unit Test Class 
*/
@isTest
private class EM024_CategoryEventTest {

    static testMethod void getRecordsByIds() {
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            //Test method
            Campaign camp1 = TestFactory.getSimpleCampaignEvents();
            Insert camp1;
            Category_Event__c testCAte = TestFactory.getCAtegoryEvent(camp1.Id);
            Insert testCAte;
            Category_Event__c categ = EM024_CategoryEvent.getRecordsByIds(new Set<Id>{testCAte.Id});
            
            
            
            // Results verification
            System.assertEquals(categ.Tech_Category_Event_ID_Etouches__c, testCAte.Tech_Category_Event_ID_Etouches__c);
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
            
        }
        // Test End 
        System.test.stopTest(); 
    }

}