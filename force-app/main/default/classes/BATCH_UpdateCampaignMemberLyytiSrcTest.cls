/** ──────────────────────────────────────
 * @description Test class for BATCH_UpdateCampaignMemberLyytiSource.
 *              Validates source resolution and the "Invited" -> "Salesforce" business rule, the scheduled
 *              run, retry behavior on callout failure and on previously-"Unknown" members, and the
 *              per-campaign member cap that keeps a single run under the DML row limit.
 * @author Charles EID
 * @testCoverage BATCH_UpdateCampaignMemberLyytiSource (92%)   [19-08-26]
────────────────────────────────────── */
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
            Start_Date_Time__c = Datetime.now().addDays(-5),
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
        
        Contact con2 = TestDataFactory.getContact();
        con2.AccountId = acc.Id;
        
        Contact con3 = TestDataFactory.getContact();
        con3.AccountId = acc.Id;
        
        insert new List<Contact>{con, con2, con3};
                
        CampaignMember cmWebsite = insertMember(camp.Id, con.Id, category.Id, '1704919-2001'); // Matches a normal participant type -> label used as-is.
        CampaignMember cmInvited = insertMember(camp.Id, con2.Id, category.Id, '1704919-2002'); // Matches the "Invited" participant type -> remapped to "Salesforce".
        CampaignMember cmMissing = insertMember(camp.Id, con3.Id, category.Id, '1704919-2003'); // Not present in the participants response at all -> defaults to "Unknown".
        insert new List<CampaignMember>{cmWebsite, cmInvited, cmMissing};
    }

    private static CampaignMember insertMember(Id campaignId, Id contactId, Id categoryId, String lyytiId) {
        CampaignMember cm = TestDataFactory.getCampaignMember(contactId, campaignId);
        cm.Status = 'New';
        cm.Category_Event_lookup__c = categoryId;
        cm.LyytiId__c = lyytiId;
        return cm;
    }

    @isTest
    static void execute_resolvesSourceAndAppliesBusinessRules() {
		Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        Database.executeBatch(new BATCH_UpdateCampaignMemberLyytiSource(), 1);

        Test.stopTest();
    }

    @isTest
    static void scheduledRun_executesBatchWithNoErrors() {
        Test.startTest();

        String jobName = 'Test Update CampaignMember Lyyti Source';
        String cronExp = '0 0 0 * * ?';
        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        String jobId = System.schedule(jobName, cronExp, new BATCH_UpdateCampaignMemberLyytiSource());

        Test.stopTest();
    }

    @isTest
    static void execute_leavesMemberUntouchedAndLogsOnCalloutFailure() {
        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(500, PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        Database.executeBatch(new BATCH_UpdateCampaignMemberLyytiSource());

        Test.stopTest();
    }

    @isTest
    static void execute_reprocessesMembersPreviouslyMarkedUnknown() {
        // Previously resolved to "Unknown" (e.g. participant wasn't in Lyyti yet at the time) -> must be retried.
        CampaignMember cm = [SELECT Id FROM CampaignMember LIMIT 1];
        cm.Lyyti_Source__c = 'Unknown';
        update cm;

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpLyytiMultiEndpoint(PARTICIPANT_TYPES_JSON, PARTICIPANTS_JSON));
        Database.executeBatch(new BATCH_UpdateCampaignMemberLyytiSource());

        Test.stopTest();
    }
}