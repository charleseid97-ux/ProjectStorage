@isTest
public class WS_SendCampaignMemberTest {

    public static final String mockResult_1 = '{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}';
    public static final String mockResult_2 = '{"results": {"227032970": {"id": 227032970,"uid": "1704919-227032970","uuid": "1ef911d2-29e6-63a0-8a7b-7239c816d04e","firstname": "first","lastname": "last","email": "first.last@invalid.com", "participant_type_id": 61909330},"227032971": {"id": 227032971,"uid": "1704919-227032971","uuid": "1ef911d2-29e6-63a0-8a7b-7239c816d04d","firstname": "first1","lastname": "last1","email": "first.last123@invalid.com"}}}';
    
    @testSetup static void setup() {
        Campaign camp = new Campaign 
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
                LyytiId__c = '1704919',
                Tech_ParticipantType__c=61909330
            );
        insert camp;
        
        List<CampaignMemberStatus> statuses = new List<CampaignMemberStatus>{ 
            new CampaignMemberStatus(CampaignId = camp.Id, Label = 'Invited', HasResponded = false, IsDefault = true), 
            new CampaignMemberStatus(CampaignId = camp.Id, Label = 'Declined', HasResponded = false, IsDefault = false), 
            new CampaignMemberStatus(CampaignId = camp.Id, Label = 'Attended', HasResponded = false, IsDefault = false), 
            new CampaignMemberStatus(CampaignId = camp.Id, Label = 'No Show', HasResponded = false, IsDefault = false), 
            new CampaignMemberStatus(CampaignId = camp.Id, Label = 'Confirmed', HasResponded = true, IsDefault = false) }; 
        insert statuses;
        
        Category_Event__c category = new Category_Event__c(Name='default', Campaign__c=camp.Id);
        insert category;
        Account acc = TestDataFactory.getAccount();
        insert acc;
        
        Contact con = TestDataFactory.getContact();
        con.AccountId = acc.Id;
        insert con;
    }

    // Covers the insert path of sendCallWSLyyti (oldItems == null). Status doesn't branch that
    // path at all (only LastModifiedById does), so a dedicated single-record insert test for
    // 'Invited' or 'Confirmed' is redundant with the bulk insert below - dropped, no coverage lost.
    @isTest
    static void sendCMStatusInvitedBulk_Test() {
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        List<Contact> contacts = new List<Contact>();
        List<CampaignMember> cms = new List<CampaignMember>();
        for(Integer i = 0;i<150;i++){
            Contact con = TestDataFactory.getContact();
        	con.AccountId = acc.Id;
            contacts.add(con);
        }
        insert contacts;

        for(Contact con : contacts){
            CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        	cm.Status = 'Invited';
        	cm.Category_Event_lookup__c = category.Id;
            cms.add(cm);
        }

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200, mockResult_1));
        insert cms;

        Test.stopTest();
    }

    // Covers the update path of sendCallWSLyyti/getCMToUpdate for every status branch in one bulk
    // update (callWS batches every qualifying Id into a single @future call, so there's no
    // per-record governor constraint like Database.executeBatch has - unlike the batch tests
    // below, these don't need separate test methods per status). The "Cancelled" scenario sets
    // Status and Cancelled__c together in this same update: Cancelled__c is checked with priority
    // over the status branches in getCMToUpdate, and sendCallWSLyyti's dispatch gate only requires
    // status != 'Invited' at the time of this update, so no separate pre-step is needed.
    @isTest
    static void sendCMStatusTransitions_Test() {
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];

        List<String> targetStatuses = new List<String>{ 'Declined', 'Attended', 'No Show', 'Attended', 'Confirmed' };
        Integer cancelledIndex = 3;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < targetStatuses.size(); i++) {
            Contact con = TestDataFactory.getContact();
            con.AccountId = acc.Id;
            con.LastName = 'Last' + i;
            con.Email = 'first.last' + i + '@invalid.com';
            contacts.add(con);
        }
        insert contacts;

        List<CampaignMember> cms = new List<CampaignMember>();
        for (Integer i = 0; i < targetStatuses.size(); i++) {
            CampaignMember cm = TestDataFactory.getCampaignMember(contacts[i].Id, camp.Id);
            cm.Status = 'Invited';
            cm.Category_Event_lookup__c = category.Id;
            cm.LyytiId__c = '1711900-834136176';
            cms.add(cm);
        }
        insert cms;

        for (Integer i = 0; i < cms.size(); i++) {
            cms[i].Status = targetStatuses[i];
        }
        cms[cancelledIndex].Cancelled__c = true;

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200, mockResult_1));
        update cms;

        Test.stopTest();
    }

    @isTest
    static void sendCMGetIdLyyti_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Category_Event_lookup__c = category.Id;
        insert cm;

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200, mockResult_2));
        SM016_CampaignMemberService.callWS(new Set<Id>{cm.Id}, true);
        
        Test.stopTest();
    }
    
    // A test method can only invoke Database.executeBatch once, and the iterable returned by
    // start() must fit within a single chunk. BATCH_SendCampaignMemberLyyti's Schedulable wrapper
    // hardcodes a batch size of 1, so we call Database.executeBatch directly with a size large
    // enough (200) to fit all 5 statuses in one chunk, covering every branch of execute() in a
    // single batch run instead of 5 separate test methods each running their own batch.
    @isTest
    static void testBatchExecution_AllStatuses() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];

        List<String> statuses = new List<String>{ 'Invited', 'Declined', 'Attended', 'No Show', 'Confirmed' };

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < statuses.size(); i++) {
            Contact con = TestDataFactory.getContact();
            con.AccountId = acc.Id;
            con.LastName = 'Last' + i;
            con.Email = 'first.last' + i + '@invalid.com';
            contacts.add(con);
        }
        insert contacts;

        List<CampaignMember> cms = new List<CampaignMember>();
        for (Integer i = 0; i < statuses.size(); i++) {
            CampaignMember cm = TestDataFactory.getCampaignMember(contacts[i].Id, camp.Id);
            cm.Status = statuses[i];
            cm.Category_Event_lookup__c = category.Id;
            cms.add(cm);
        }
        insert cms;

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200, mockResult_1));
        Database.executeBatch(new BATCH_SendCampaignMemberLyyti(), 200);

        Test.stopTest();
    }

    // Covers BATCH_SendCampaignMemberLyyti.execute(SchedulableContext), the Schedulable wrapper
    // that testBatchExecution_AllStatuses bypasses (it calls Database.executeBatch directly to
    // avoid the wrapper's hardcoded batch size of 1). No CampaignMember matches the batch's
    // start() query in this test's own transaction, so the batch scope is empty and there's no
    // risk of the "iterable must fit the batch size" constraint.
    @isTest
    static void testBatchScheduling_Test() {
        Test.startTest();

        String jobId = System.schedule('Test Send Campaign Member Calculation', '0 0 0 * * ?', new BATCH_SendCampaignMemberLyyti());

        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Expected the Lyyti campaign member batch to be scheduled.');
    }
}