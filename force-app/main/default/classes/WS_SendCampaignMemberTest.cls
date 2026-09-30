@isTest
public class WS_SendCampaignMemberTest {

    public static final String mockResult_1 = '{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}';
    public static final String mockResult_2 = '{"results": {"227032970": {"id": 227032970,"uid": "1704919-227032970","uuid": "1ef911d2-29e6-63a0-8a7b-7239c816d04e","firstname": "first","lastname": "last","email": "first.last@invalid.com", "participant_type_id": 61909330},"227032971": {"id": 227032971,"uid": "1704919-227032971","uuid": "1ef911d2-29e6-63a0-8a7b-7239c816d04d","firstname": "first1","lastname": "last1","email": "first.last123@invalid.com"}}}';
    
    @testSetup static void setup() {
        Campaign camp = new Campaign (
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
        String jobId = System.schedule('Test Send Campaign Member Calculation', '0 0 0 * * ?', new BATCH_SendCampaignMemberLyyti());

        Test.stopTest();
    }
}