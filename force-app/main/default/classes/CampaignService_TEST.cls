/**
 * Created by noorgoolamnabee on 08/11/2022.
 */
@IsTest
public with sharing class CampaignService_TEST {



    @IsTest
    static void testBehavior() {

        User usr = TestFactory.getStandardCarmignacUser();

        system.runAs(usr) {

            Campaign c =  TestFactory.getCampaignNewsletter();
            insert c;

            Campaign updatedCampaign = [SELECT Id, Name FROM Campaign WHERE Id = : c.Id];
            System.assertNotEquals(updatedCampaign.Name, c.Name);
            
            c.Description = 'Modification test';
            update c;
            
            updatedCampaign = [SELECT Id, Name FROM Campaign WHERE Id = : c.Id];
            System.assertNotEquals(updatedCampaign.Name, c.Name);
            
            delete c;
        }
    }
}