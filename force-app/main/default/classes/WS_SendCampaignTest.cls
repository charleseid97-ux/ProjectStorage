/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
public class WS_SendCampaignTest {

 

    @isTest
    static void sendCampaignLyyti_Test() {

        Campaign camp1 = new Campaign 
            (
                recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
                Status = 'Live',
                Name='TestCampaign',
                Sales_Team__c='FR',
                Type='Survey',
                Event_Local_Start_Time__c = '2017/05/09 12:00',
                Event_Local_End_Time__c = '2017/05/09 18:00',
                Start_Date_Time__c= Datetime.now(),
                End_Date_Time__c= Date.today().addDays(1),
                Event_Lyyti__c = true
            );
            
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": {"eid": 1704919, "participant_types": {"62929867": {"participant_type_id": 62929867, "name": {"fr": "Invited", "en": "Invited"}}, "62929873": {"participant_type_id": 62929873, "name": {"fr": "Social Media", "en": "Social Media"}}}}}'));
            insert camp1;

        Test.stopTest();

        //System.assertNotEquals(0, websites.size());
    }

    @isTest
    static void getParticipantType_Test() {

        Campaign camp1 = new Campaign 
            (
                recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
                Status = 'Live',
                Name='TestCampaign',
                Sales_Team__c='FR',
                Type='Survey',
                Event_Local_Start_Time__c = '2017/05/09 12:00',
                Event_Local_End_Time__c = '2017/05/09 18:00',
                Start_Date_Time__c= Datetime.now(),
                End_Date_Time__c= Date.today().addDays(1),
                LyytiId__c = '1704919'
            );
            
        Test.startTest();
        
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200, '{"results": {"61909330": {"id": 61909330, "avec": null, "description": {"fr": "Invited"}}, "61909333": {"id": 61909333, "avec": null, "description": {"fr": "Social Media"}}}}'));
            insert camp1;

        Test.stopTest();

        //System.assertNotEquals(0, websites.size());
    }

}