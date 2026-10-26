@IsTest
private class BatchCloseCampaignLyytiTest {

    @TestSetup
    static void setup() {
        Campaign c = createCampaign();
        insert c;

        insertCampaignStatuses(c.Id);

        Category_Event__c category = new Category_Event__c(
            Name = 'default',
            Campaign__c = c.Id
        );
        insert category;

        Account acc = TestDataFactory.getAccount();
        insert acc;

        Contact conInvited = TestDataFactory.getContact();
        conInvited.AccountId = acc.Id;

        Contact conConfirmed = TestDataFactory.getContact();
        conConfirmed.AccountId = acc.Id;

        Contact conAttended = TestDataFactory.getContact();
        conAttended.AccountId = acc.Id;

        insert new List<Contact>{
            conInvited,
            conConfirmed,
            conAttended
        };

        Lead leadNoShow = new Lead(
            LastName = 'No Show Lead',
            Company = 'Test Company'
        );

        Lead leadCancelled = new Lead(
            LastName = 'Cancelled Lead',
            Company = 'Test Company'
        );

        insert new List<Lead>{
            leadNoShow,
            leadCancelled
        };

        insert new List<CampaignMember>{
            new CampaignMember(
                CampaignId = c.Id,
                ContactId = conInvited.Id,
                Status = 'Invited',
                Category_Event_lookup__c = category.Id,
                Cancelled__c = true
            ),
            new CampaignMember(
                CampaignId = c.Id,
                ContactId = conConfirmed.Id,
                Status = 'Confirmed',
                Category_Event_lookup__c = category.Id,
                Cancelled__c = false
            ),
            new CampaignMember(
                CampaignId = c.Id,
                ContactId = conAttended.Id,
                Status = 'Attended',
                Category_Event_lookup__c = category.Id,
                Cancelled__c = false
            ),
            new CampaignMember(
                CampaignId = c.Id,
                LeadId = leadNoShow.Id,
                Status = 'No Show',
                Category_Event_lookup__c = category.Id,
                Cancelled__c = false
            ),
            new CampaignMember(
                CampaignId = c.Id,
                LeadId = leadCancelled.Id,
                Status = 'Cancelled',
                Category_Event_lookup__c = category.Id,
                Cancelled__c = false
            )
        };

        Test.setCreatedDate(conAttended.Id, System.now().addMonths(-1));
        Test.setCreatedDate(leadNoShow.Id, System.now().addMonths(-1));
    }

    @IsTest
    static void testBatchChain() {
        Test.startTest();
        Database.executeBatch(new BATCH_FindCampaignsToCloseLyyti(), 50);
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
                   Attendees_Invested_Count__c,
                   Attendees_Loyalty_Rate__c
            FROM Campaign
            LIMIT 1
        ];

        List<CampaignMember> members = [
            SELECT Status, Cancelled__c
            FROM CampaignMember
            WHERE CampaignId = :c.Id
        ];

        Integer cancelledStatusCount = 0;
        for (CampaignMember cm : members) {
            if (cm.Status == 'Cancelled') {
                cancelledStatusCount++;
            }
        }

        System.assertEquals('Closed', c.Status);

        // Le membre Invited avec Cancelled__c = true est passé à Cancelled.
        System.assertEquals(2, cancelledStatusCount);

        // Statuts finaux :
        // Cancelled : ancien Invited annulé + Lead Cancelled = 2
        // Confirmed : 1
        // Attended : 1
        // No Show : 1
        System.assertEquals(5, c.Initially_invited__c);
        System.assertEquals(5, c.Initially_registered__c);
        System.assertEquals(1, c.Attended_Count__c);
        System.assertEquals(2, c.Cancelled_Count__c);
        System.assertEquals(1, c.NoShow_Count__c);

        // Contact Attended créé dans les 3 mois.
        System.assertEquals(1, c.New_Person_Attendees_3M__c);
    }

    @IsTest
    static void testCloseCampaignMembersBatchDirectly() {
        Campaign c = [
            SELECT Id
            FROM Campaign
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(
            new BATCH_CloseCampaignMembersLyyti(new List<Id>{ c.Id }),
            200
        );
        Test.stopTest();

        Campaign refreshed = [
            SELECT Status,
                   Initially_invited__c,
                   Initially_registered__c,
                   Attended_Count__c,
                   Cancelled_Count__c,
                   NoShow_Count__c
            FROM Campaign
            WHERE Id = :c.Id
        ];

        System.assertEquals('Closed', refreshed.Status);
        System.assertEquals(5, refreshed.Initially_invited__c);
        System.assertEquals(5, refreshed.Initially_registered__c);
        System.assertEquals(1, refreshed.Attended_Count__c);
        System.assertEquals(2, refreshed.Cancelled_Count__c);
        System.assertEquals(1, refreshed.NoShow_Count__c);
    }

    private static Campaign createCampaign() {
        Date d = Date.today();
        String ds = d.year() + '/' +
            (d.month() < 10 ? '0' : '') + d.month() + '/' +
            (d.day() < 10 ? '0' : '') + d.day();

        return new Campaign(
            RecordTypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
            Name = 'Test Campaign',
            Status = 'Live',
            Sales_Team__c = 'FR',
            Type = 'Event',
            Event_Local_Start_Time__c = ds + ' 10:00',
            Event_Local_End_Time__c = ds + ' 23:59',
            Start_Date_Time__c = System.now(),
            LyytiId__c = '123',
            Tech_ParticipantType__c = 1
        );
    }

    private static void insertCampaignStatuses(Id campaignId) {
        insert new List<CampaignMemberStatus>{
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Invited', IsDefault = true),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Cancelled', IsDefault = false),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Attended', IsDefault = false),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Confirmed', IsDefault = false),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'No Show', IsDefault = false),
            new CampaignMemberStatus(CampaignId = campaignId, Label = 'Declined', IsDefault = false)
        };
    }
}