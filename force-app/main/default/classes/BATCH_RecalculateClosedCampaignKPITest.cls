@IsTest
private class BATCH_RecalculateClosedCampaignKPITest {

    @TestSetup
    static void setup() {

        Campaign c = createClosedCampaign();
        insert c;

        insertCampaignStatuses(c.Id);

        Account acc = TestDataFactory.getAccount();
        //acc.Ultimate_Parent_ID__c = 'UP-001';
        insert acc;

        Contact attendedContact = TestDataFactory.getContact();
        attendedContact.AccountId = acc.Id;

        Contact confirmedContact = TestDataFactory.getContact();
        confirmedContact.AccountId = acc.Id;

        insert new List<Contact>{
            attendedContact,
            confirmedContact
        };

        Lead noShowLead = new Lead(
            LastName = 'No Show Lead',
            Company = 'Test Company'
        );

        insert noShowLead;

        insert new List<CampaignMember>{
            new CampaignMember(
                CampaignId = c.Id,
                ContactId = attendedContact.Id,
                Status = 'Attended'
            ),
            new CampaignMember(
                CampaignId = c.Id,
                ContactId = confirmedContact.Id,
                Status = 'Confirmed'
            ),
            new CampaignMember(
                CampaignId = c.Id,
                LeadId = noShowLead.Id,
                Status = 'No Show'
            )
        };

        insert new Opportunity(
            Name = 'Open Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(1),
            Amount = 10000,
            AccountId = acc.Id
        );

        Test.setCreatedDate(attendedContact.Id, System.now().addMonths(-1));
        Test.setCreatedDate(noShowLead.Id, System.now().addMonths(-1));
    }

    @IsTest
    static void testBatchExecution() {

        Test.startTest();

        Database.executeBatch(
            new BATCH_RecalculateClosedCampaignKPI(),
            10
        );

        Test.stopTest();

        Campaign c = [
            SELECT Status,
                   Initially_invited__c,
                   Initially_registered__c,
                   Attended_Count__c,
                   Cancelled_Count__c,
                   NoShow_Count__c,
                   New_Person_Attendees_3M__c,
                   Ultimate_Parents_Attended__c,
                   Attendees_Open_Opportunities_Amount__c
            FROM Campaign
            LIMIT 1
        ];

        System.assertEquals('Closed', c.Status);

        // Attended + Confirmed + No Show
        System.assertEquals(3, c.Initially_invited__c);

        // Confirmed + Attended + No Show
        System.assertEquals(3, c.Initially_registered__c);

        System.assertEquals(1, c.Attended_Count__c);

        System.assertEquals(0, c.Cancelled_Count__c);

        System.assertEquals(1, c.NoShow_Count__c);

        // attendedContact 
        System.assertEquals(1, c.New_Person_Attendees_3M__c);

        

        // open opportunity amount
        System.assertEquals(10000, c.Attendees_Open_Opportunities_Amount__c);
    }

    private static Campaign createClosedCampaign() {

        Date d = Date.today();

        String ds =
            d.year() + '/' +
            (d.month() < 10 ? '0' : '') + d.month() + '/' +
            (d.day() < 10 ? '0' : '') + d.day();

        return new Campaign(
            RecordTypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
            Name = 'Closed Campaign KPI',
            Status = 'Closed',
            Sales_Team__c = 'FR',
            Type = 'Event',
            Event_Local_Start_Time__c = ds + ' 10:00',
            Event_Local_End_Time__c = ds + ' 23:59',
            Start_Date_Time__c = System.now(),
            LyytiId__c = 'LYYTI-001',
            Tech_ParticipantType__c = 1
        );
    }

    private static void insertCampaignStatuses(Id campaignId) {

        insert new List<CampaignMemberStatus>{
            new CampaignMemberStatus(
                CampaignId = campaignId,
                Label = 'Invited',
                IsDefault = true
            ),
            new CampaignMemberStatus(
                CampaignId = campaignId,
                Label = 'Confirmed',
                IsDefault = false
            ),
            new CampaignMemberStatus(
                CampaignId = campaignId,
                Label = 'Attended',
                IsDefault = false
            ),
            new CampaignMemberStatus(
                CampaignId = campaignId,
                Label = 'No Show',
                IsDefault = false
            ),
            new CampaignMemberStatus(
                CampaignId = campaignId,
                Label = 'Cancelled',
                IsDefault = false
            )
        };
    }
}