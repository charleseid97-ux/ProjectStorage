@isTest
public class BATCH_UpdateCampaignMemberLyytiSrcTest {

    private static final String PARTICIPANT_TYPES_JSON =
        '{"results": {' +
            '"1000": {"id": "1000", "description": {"fr": "Website"}},' +
            '"2000": {"id": "2000", "description": {"fr": "Invited"}}' +
        '}}';

    private static final String PARTICIPANTS_JSON =
        '{"results": {' +
            '"1": {"uid": "1704919-2001", "participant_type_id": 1000},' +
            '"2": {"uid": "1704919-2002", "participant_type_id": 2000}' +
        '}}';

    @testSetup
    static void setup() {
        Campaign camp = new Campaign(
            recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
            Status = 'Live',
            Name = 'TestCampaign',
            Sales_Team__c = 'FR',
            Type = 'Survey',
            Event_Local_Start_Time__c = '2017/05/09 12:00',
            Event_Local_End_Time__c = '2017/05/09 18:00',
            Start_Date_Time__c = Datetime.now(),
            End_Date_Time__c = Date.today().addDays(1),
            LyytiId__c = '1704919',
            Tech_ParticipantType__c = 61909330
        );
        insert camp;

        // "New" is not a status SM016_CampaignMemberTriggerHandler acts on, so inserting/updating
        // these test CampaignMembers below never attempts an (unmocked) Lyyti callout of its own.
        insert new CampaignMemberStatus(CampaignId = camp.Id, Label = 'New', HasResponded = false, IsDefault = true);

        Category_Event__c category = new Category_Event__c(Name = 'default', Campaign__c = camp.Id);
        insert category;

        Account acc = TestDataFactory.getAccount();
        insert acc;

        Contact con = TestDataFactory.getContact();
        con.AccountId = acc.Id;
        insert con;
    }

    private static CampaignMember insertMember(Id campaignId, Id contactId, Id categoryId, String lyytiId) {
        CampaignMember cm = TestDataFactory.getCampaignMember(contactId, campaignId);
        cm.Status = 'New';
        cm.Category_Event_lookup__c = categoryId;
        cm.LyytiId__c = lyytiId;
        insert cm;
        return cm;
    }

    @isTest
    static void execute_resolvesSourceAndAppliesBusinessRules() {
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];

        // Matches a normal participant type -> label used as-is.
        CampaignMember cmWebsite = insertMember(camp.Id, con.Id, category.Id, '1704919-2001');
        // Matches the "Invited" participant type -> remapped to "Salesforce".
        CampaignMember cmInvited = insertMember(camp.Id, con.Id, category.Id, '1704919-2002');
        // Not present in the participants response at all -> defaults to "Unknown".
        CampaignMember cmMissing = insertMember(camp.Id, con.Id, category.Id, '1704919-2003');

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        Database.executeBatch(new BATCH_UpdateCampaignMemberLyytiSource());

        Test.stopTest();

        Map<Id, CampaignMember> updated = new Map<Id, CampaignMember>([SELECT Id, Lyyti_Source__c FROM CampaignMember WHERE Id IN :new List<Id>{ cmWebsite.Id, cmInvited.Id, cmMissing.Id }]);

        System.assertEquals('Website', updated.get(cmWebsite.Id).Lyyti_Source__c);
        System.assertEquals('Salesforce', updated.get(cmInvited.Id).Lyyti_Source__c);
        System.assertEquals('Unknown', updated.get(cmMissing.Id).Lyyti_Source__c);
    }

    @isTest
    static void scheduledRun_executesBatchWithNoErrors() {
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];

        insertMember(camp.Id, con.Id, category.Id, '1704919-2001');

        Test.startTest();

        String jobName = 'Test Update CampaignMember Lyyti Source';
        String cronExp = '0 0 0 * * ?';
        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        String jobId = System.schedule(jobName, cronExp, new BATCH_UpdateCampaignMemberLyytiSource());

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);

        Test.stopTest();

        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE JobType = 'BatchApex' ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals(0, job.NumberOfErrors);
    }

    @isTest
    static void execute_leavesMemberUntouchedAndLogsOnCalloutFailure() {
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];

        CampaignMember cm = insertMember(camp.Id, con.Id, category.Id, '1704919-2001');

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(500, PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        Database.executeBatch(new BATCH_UpdateCampaignMemberLyytiSource());

        Test.stopTest();

        CampaignMember result = [SELECT Id, Lyyti_Source__c FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals(null, result.Lyyti_Source__c, 'Member should stay blank so the next scheduled run retries it');

        List<OperationLog__c> logs = [SELECT Id, Level__c, Operation__c FROM OperationLog__c WHERE SourceRecordId__c = :camp.Id];
        System.assert(!logs.isEmpty(), 'A failure log should have been written for the campaign');
        System.assertEquals('ERROR', logs[0].Level__c);
    }
}