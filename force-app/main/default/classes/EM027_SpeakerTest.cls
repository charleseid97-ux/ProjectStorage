/** 
* @author Adolphe Sonko
* @date Creation 14/04/2017
* @date Modification 14/04/2017
* @description : EM022_BounceEtouches Unit Test Class 
*/

@isTest
public class EM027_SpeakerTest {
    static testMethod void getAllCMFromCampaign() {
        
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Methods Calls
            // Data Preparation
            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.TECH_ID_Schedule__c ='12345';
            Insert camp1;
            
            Speaker__c speaker = new Speaker__c(Campaign__c=camp1.Id);
            Insert speaker;
            List<String> ListScheduleId = new List<String>();
            ListScheduleId.add('12345');
            
            List<Campaign> found_ListCampaign = EM027_Speaker.getEventListsByScheduleId(ListScheduleId);
            
            // Results verification
            System.assertEquals(found_ListCampaign.size(), 1);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
}