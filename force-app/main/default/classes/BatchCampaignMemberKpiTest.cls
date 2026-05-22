@IsTest
private class BatchCampaignMemberKpiTest {

    @TestSetup
    static void setup() {
        Campaign eventCampaign = createCampaign('Event_and_Meeting');
        Campaign newsletterCampaign = createCampaign('Newsletters');

        insert new List<Campaign>{ eventCampaign, newsletterCampaign };

        insertCampaignStatuses(eventCampaign.Id);
        insertCampaignStatuses(newsletterCampaign.Id);

        Account acc = TestDataFactory.getAccount();
        insert acc;

        Contact con = TestDataFactory.getContact();
        con.AccountId = acc.Id;
        insert con;

        Lead lead = new Lead(LastName='Test', Company='Test');
        insert lead;

        insert new List<CampaignMember>{
            new CampaignMember(
                CampaignId = eventCampaign.Id,
                ContactId = con.Id,
                Status = 'Attended'
            ),
            new CampaignMember(
                CampaignId = eventCampaign.Id,
                LeadId = lead.Id,
                Status = 'Confirmed'
            ),
            new CampaignMember(
                CampaignId = newsletterCampaign.Id,
                ContactId = con.Id,
                Status = 'Clicked'
            )
        };
    }

    @IsTest
    static void testBatch() {
        Test.startTest();
        Database.executeBatch(new BATCH_RecalculateContactParticipationKPI(), 50);
        Test.stopTest();

        Contact c = [
            SELECT E_participated_24M__c,
                   E_invited_24M__c,
                   N_received_24M__c,
                   N_clicked_24M__c
            FROM Contact LIMIT 1
        ];

        System.assertEquals(1, c.E_participated_24M__c);
        System.assertEquals(1, c.E_invited_24M__c);
        System.assertEquals(1, c.N_received_24M__c);
        System.assertEquals(1, c.N_clicked_24M__c);
    }

    private static Campaign createCampaign(String rtName) {
        Campaign c = new Campaign(
            Name = 'Test',
            Status = 'Live',
            //Sales_Team__c = 'FR',
            Event_Local_Start_Time__c = '2024/01/01 10:00',
            Event_Local_End_Time__c = '2024/01/01 23:59',
            Start_Date_Time__c = System.now(),
            LyytiId__c = String.valueOf(Math.random())
        );

        Map<String, Schema.RecordTypeInfo> rt =
            Schema.SObjectType.Campaign.getRecordTypeInfosByDeveloperName();

        if (rt.containsKey(rtName)) {
            c.RecordTypeId = rt.get(rtName).getRecordTypeId();
        }

        return c;
    }

    private static void insertCampaignStatuses(Id campaignId) {
        insert new List<CampaignMemberStatus>{
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Invited', IsDefault = true),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Confirmed', IsDefault = false),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Attended', IsDefault = false),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Clicked', IsDefault = false)
        };
    }
}