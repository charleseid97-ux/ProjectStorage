/**
 * Created by Noor Nabee on 3/18/2020.
 */

@IsTest
private class BATCH002_DeleteCampaignMember_TEST {
    @IsTest
    static void testBehavior() {

        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            // Test Begin
            System.test.startTest();
            TestFactory.createCustomSettings();
            //Data preparation.
            WebserviceParameters__c param = new WebserviceParameters__c(
                    Name = 'EtouchesAPI',
                    Endpoint__c = 'https://qa.eiseverywhere.com/api/v2',
                    key__c = 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
                    Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',
                    accountid__c = '4740');

            insert param;

            Campaign camp1 = TestFactory.getSimpleCampaignEventsEtouhchesNotSend();
            camp1.Event_code_Etouches__c = '118819' ;
            camp1.TECH_Mailing_List_ID_Etouches__c = '85265' ;
            Insert camp1;

            Campaign camp2 = TestFactory.getSimpleCampaignEvents();
            camp2.Event_code_Etouches__c = '113814' ;
            camp2.TECH_Mailing_List_ID_Etouches__c = '85279' ;
            Insert camp2;

            Campaign camp3 = TestFactory.getSimpleCampaignEvents();
            camp3.Event_code_Etouches__c = '11381b5' ;
            camp3.TECH_Mailing_List_ID_Etouches__c = '85280' ;
            Insert camp3;

            Account accTest = TestFactory.getSimpleAccount();
            insert accTest;

            Contact testContact1 = TestFactory.getSimpleNoProfileContact(accTest.Id, 'TestFName', 'LastNameTestCarmignac', '65432345',
                    'TechwbesiteId', 'mail@mail1.com',
                    'mail@mail1.com', 'mail@mail1.com');
            testContact1.Subscriber__c = true;
            insert testContact1;

            Category_Event__c categ = new Category_Event__c(Name = 'Category 1', Campaign__c = camp1.Id, Tech_Category_Event_ID_Etouches__c = '1234');
            insert categ;

            CampaignMember campMember = new CampaignMember(ContactId = testContact1.id, CampaignId = camp1.Id, Category_Event_lookup__c = categ.Id, TECH_ID_Subscriber__c = '752809');
            insert campMember;

            CampaignMember campMember2 = new CampaignMember(ContactId = testContact1.id, CampaignId = camp2.Id, Category_Event_lookup__c = categ.Id);
            campMember2.TECH_ID_Subscriber__c = '758124' ;
            insert campMember2;

            CampaignMember campMember3 = new CampaignMember(ContactId = testContact1.id, CampaignId = camp3.Id, Category_Event_lookup__c = categ.Id);
            campMember3.TECH_ID_Subscriber__c = '' ;
            insert campMember3;

            BATCH002_DeleteCampaignMemberScheduler sh1 = new BATCH002_DeleteCampaignMemberScheduler();
            String CRON = '0 0 23 * * ?';
            system.schedule('BATCH002_DeleteCampaignMemberScheduler', CRON, sh1);

        }

        System.test.stopTest();

    }
}