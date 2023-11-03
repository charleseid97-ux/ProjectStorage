@IsTest
public with sharing class CTL_AudienceManagementTest {
    
    @TestSetup
    static void makeData(){
        Account a = new Account(
            Name='Test Account',
            BusinessDevelopmentRegion__c='BP_FR',
            BillingCountry='France'
        );
        insert a;

        Contact c = new Contact(
            LastName='Test',
            AccountId=a.Id,
            Source__c='BrightTalk',
            Email='test@test.test'
        );
        insert c;

        Product__c strat = new Product__c();
        strat.RecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
        strat.Name = 'AECI';
        strat.Product_Name__c = 'ALM ES CI';
        insert strat;

        Product__c fund = new Product__c();
        fund.RecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        fund.Name = 'Super Fund';
        fund.Product_Name__c = 'Super Fund Test';
        fund.Strategy__c = strat.Id;
        insert fund;

        Share_Class__c share = new Share_Class__c();
        share.Name = 'Test shared class';
        share.Fund__c = fund.Id;
        insert share;

        AUM__c aum = new AUM__c();
        aum.ShareClass__c = share.Id;
        aum.Company__c = a.Id;
        aum.AUMExternalId__c = '0000000000';
        insert aum;

        Meeting_Note__c mn = new Meeting_Note__c();
        mn.Date__c = Date.today();
        insert mn;

        ClientInterest__c ci = new ClientInterest__c();
        ci.Product__c = strat.Id;
        ci.Interest__c = 3;
        ci.MeetingNote__c = mn.Id;
        insert ci;

        Event e = new Event();
        e.Meeting_Note__c = mn.Id;
        e.DurationInMinutes = 10;
        e.ActivityDateTime = Datetime.now();
        insert e;

        EventRelation er = new EventRelation();
        er.RelationId = c.Id;
        er.EventId = e.Id;
        er.IsInvitee = false;
        er.IsParent = true;
        er.IsWhat= false;
        insert er;

        Campaign camp = new Campaign(
            recordtypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByDeveloperName().get('Newsletters').getRecordTypeId(),
            Status = 'Live',
            Name='TestCampaign',
            Type='Survey',
            Start_Date_Time__c= Datetime.now(),
            End_Date_Time__c= Date.today().addDays(1)
        );
        insert camp;

        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Carmignac - Business Developer'];
        User u = new User(
            ProfileId = prof.Id,
            FirstName = 'Test',
            LastName = 'AudienceManagement',
            Email = 'testuser@test.com',
            Username = 'testaudiencemanagement'+ Datetime.now().second() + '@test.com' ,
            alias = 'testu',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR_EURO',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'fr',
            Position__c = 'Business Developer',
            BusinessDevelopmentRegions__c = 'BP_FR',
            IsActive = true,
            BypassApexTriggers__c = '',
            BypassProcessBuilders__c = false,
            BypassValidationRules__c = false,
            BypassWorkflowRules__c = false
        );
        insert u;
    }

    @IsTest
    public static void getContactsTest() {
        List<Contact> cList = CTL_AudienceManagement.getContacts('');
        System.assertEquals(1, cList.size());
    }

    @IsTest
    public static void getProductsTest() {
        List<Product__c> pList = CTL_AudienceManagement.getProducts();
        System.assertEquals(1, pList.size());
    }

    @IsTest
    public static void getCampaignsTest() {
        List<Campaign> cList = CTL_AudienceManagement.getCampaigns();
        System.assertEquals(1, cList.size());
    }

    @IsTest
    public static void getUsersTest() {
        Map<Id,User> uMap = new Map<Id, User>(CTL_AudienceManagement.getUsers());
        User u = [SELECT Id FROM User WHERE Name = 'Test AudienceManagement'];
        System.assert(uMap.keySet().contains(u.Id));
    }

    @IsTest
    public static void getFilterListTest() {
        List<CTL_AudienceManagement.Filter> filterList = CTL_AudienceManagement.getFilterList();
        System.assertNotEquals(0, filterList.size());        
    }

    @IsTest
    public static void getAllFilterTest() {
        List<CTL_AudienceManagement.Filter> filterList = CTL_AudienceManagement.getAllFilters();
        System.assertNotEquals(0, filterList.size());        
    }

    @IsTest
    public static void getPrefCenterFiltersTest() {
        List<CTL_AudienceManagement.Filter> filterList = CTL_AudienceManagement.getPrefCenterFilters();
        System.assertNotEquals(0, filterList.size());        
    }

    @IsTest
    public static void addToCampaignTest() {
        Campaign camp = [SELECT Id, Name FROM Campaign LIMIT 1];
        System.debug(camp.Name);
        List<Id> cIds = new List<Id>();
        for(Contact c : [SELECT Id FROM Contact]) {
            cIds.add(c.Id);
        }
        List<CampaignMember> cmList = [SELECT Id FROM CampaignMember WHERE CampaignId =: camp.Id];
        System.assertEquals(0, cmList.size());
        CTL_AudienceManagement.addToCampaign(camp.Id, cIds);
        cmList = [SELECT Id FROM CampaignMember WHERE CampaignId =: camp.Id];
        System.assertEquals(1, cmList.size());
    }

    @IsTest
    public static void getContactFromProductInterestTestNoResult() {
        try {
            Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'AECI'];
            String request = 'SELECT MeetingNote__c FROM ClientInterest__c WHERE Product__c !=\'' + prod.Id + '\'';
            CTL_AudienceManagement.getContactFromProductInterest(request);
        } catch (Exception e) {
            System.assertEquals('Script-thrown exception', e.getMessage());
        }
    }

    @IsTest
    public static void getContactFromProductInterestTest() {
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'AECI'];
        String request = 'SELECT MeetingNote__c FROM ClientInterest__c WHERE Product__c =\'' + prod.Id + '\'';
        List<Id> contactIds = CTL_AudienceManagement.getContactFromProductInterest(request);
        Contact c = [SELECT Id FROM Contact WHERE Name LIKE '%Test%'];
        System.assert(contactIds.contains(c.Id));
    }

    @IsTest
    public static void getCompanyFromProductInterestTestNoResult() {
        try {
            Id fakeProductId = 'a1V1l000000000000I';
            List<Id> accountIds = CTL_AudienceManagement.getCompanyFromProductInterest(fakeProductId);
        } catch (Exception e) {
            System.assertEquals('Script-thrown exception', e.getMessage());
        }
    }

    @IsTest
    public static void getCompanyFromProductInterestTest() {
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'AECI'];
        List<Id> accountIds = CTL_AudienceManagement.getCompanyFromProductInterest(prod.Id);
        Account acc = [SELECT Id FROM Account WHERE Name LIKE '%Test Account%'];
        System.assert(accountIds.contains(acc.Id));
    }
}