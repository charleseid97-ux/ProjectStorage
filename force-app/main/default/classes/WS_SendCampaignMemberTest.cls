@isTest
public class WS_SendCampaignMemberTest {
    
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

    @isTest
    static void sendCMStatusInvited_Test() {

        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Invited';
        cm.Category_Event_lookup__c = category.Id;
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            insert cm;

        Test.stopTest();

    }

    @isTest
    static void sendCMStatusDeclined_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Invited';
        cm.Category_Event_lookup__c = category.Id;
        cm.LyytiId__c='1711900-834136176';
        insert cm;
        
        cm.Status = 'Declined';
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            update cm;

        Test.stopTest();

    }

    @isTest
    static void sendCMStatusAttended_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Invited';
        cm.Category_Event_lookup__c = category.Id;
        cm.LyytiId__c='1711900-834136176';
        insert cm;
        
        cm.Status = 'Attended';
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            update cm;

        Test.stopTest();

    }

    @isTest
    static void sendCMStatusNoShow_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Invited';
        cm.Category_Event_lookup__c = category.Id;
        cm.LyytiId__c='1711900-834136176';
        insert cm;
        
        cm.Status = 'No Show';
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            update cm;

        Test.stopTest();

    }
    
    @isTest
    static void sendCMStatusCancelled_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Invited';
        cm.Category_Event_lookup__c = category.Id;
        cm.LyytiId__c='1711900-834136176';
        insert cm;
        
        cm.Status = 'Attended';
        update cm;
        
        cm.Cancelled__c = true;
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            update cm;

        Test.stopTest();

    }
    
    @isTest
    static void sendCMUpdateStatusConfirmed_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Invited';
        cm.Category_Event_lookup__c = category.Id;
        cm.LyytiId__c='1711900-834136176';
        insert cm;
        
        cm.Status = 'Confirmed';
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            update cm;

        Test.stopTest();

    }

    @isTest
    static void sendCMCreateStatusConfirmed_Test() {
		Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        
        CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        cm.Status = 'Confirmed';
        cm.Category_Event_lookup__c = category.Id;
        
        Test.startTest();
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            insert cm;

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
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": {"227032970": {"id": 227032970,"uid": "1704919-227032970","uuid": "1ef911d2-29e6-63a0-8a7b-7239c816d04e","firstname": "first","lastname": "last","email": "first.last@invalid.com"},"227032971": {"id": 227032971,"uid": "1704919-227032971","uuid": "1ef911d2-29e6-63a0-8a7b-7239c816d04d","firstname": "first1","lastname": "last1","email": "first.last123@invalid.com"}}}'));
        	SM016_CampaignMemberService.callWS(new Set<Id>{cm.Id}, true);
        
        Test.stopTest();

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
			Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));
            insert cms;

        Test.stopTest();

    }
    
         
    @isTest
    static void testBatchExecution() {
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Category_Event__c category = [SELECT Id FROM Category_Event__c LIMIT 1];
        List<Contact> contacts = new List<Contact>();
        List<CampaignMember> cms = new List<CampaignMember>();
        for(Integer i = 0;i<40;i++){
            Contact con = TestDataFactory.getContact();
        	con.AccountId = acc.Id;
            contacts.add(con);
        }
        insert contacts;
        Integer i = 0;
        List<String> status = new List<String>{'Invited', 'Declined', 'Attended', 'No Show', 'Confirmed'};
        for(Contact con : contacts){
            CampaignMember cm = TestDataFactory.getCampaignMember(con.Id,camp.Id);
        	cm.Status = status[math.mod(i,5)];
        	cm.Category_Event_lookup__c = category.Id;
            
            cms.add(cm);
            i++;
        }
		insert cms;
        
        Test.startTest();
        
        String jobName = 'Test Send Campaign Member Calculation';
        String cronExp = '0 0 0 * * ?';
        BATCH_SendCampaignMemberLyytiScheduler scheduler = new BATCH_SendCampaignMemberLyytiScheduler();
        String jobId = System.schedule(jobName, cronExp, scheduler);
        Test.setMock(HttpCalloutMock.class, new MockHttpCampaign(200,'{"results": [{ "participants": { "1711900-834136176": {"id": "834136176", "uid": "1711900-834136176"} } }]}'));

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime 
                          FROM CronTrigger 
                          WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);
        System.assertEquals(0, ct.TimesTriggered);
        System.assertNotEquals(null, ct.NextFireTime);
        
        Test.stopTest();
        
       
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors 
                            FROM AsyncApexJob 
                            WHERE JobType = 'BatchApex' 
                            ORDER BY CreatedDate DESC 
                            LIMIT 1];
        System.assertEquals(0, job.NumberOfErrors);
        
        List<CampaignMember> cmwithId = [SELECT Id,LyytiId__c FROM CampaignMember WHERE LyytiId__c!=null];
        List<CampaignMember> cmWithoutId = [SELECT Id,LyytiId__c FROM CampaignMember WHERE LyytiId__c=null];
        
        system.debug('cmwithId '+cmwithId.size());
        system.debug('cmWithoutId '+cmWithoutId.size());
       
    }



}