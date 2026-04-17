@IsTest
public with sharing class QUEUEABLE001_AudienceManagementTest {
    
    @TestSetup
    static void makeData(){
        Campaign camp = new Campaign(
            recordtypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByDeveloperName().get('Newsletters').getRecordTypeId(),
            Status = 'Live',
            Name='TestCampaign',
            Type='Survey',
            Start_Date_Time__c= Datetime.now(),
            End_Date_Time__c= Date.today().addDays(1)
        );
        insert camp;

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
    }

    @IsTest
    public static void executeTest() {
        Map<Id,Contact> cMap = new Map<Id,Contact>([SELECT Id FROM Contact]);        
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        QUEUEABLE001_AudienceManagement am = new QUEUEABLE001_AudienceManagement(camp.Id, new List<Id>(cMap.keySet()));
        Test.startTest();

        System.enqueueJob(am);

        Test.stopTest();
    }

    @IsTest
    public static void executeTestError() {
        Map<Id,Contact> cMap = new Map<Id,Contact>([SELECT Id FROM Contact]);        
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        insert (new CampaignMember(CampaignId=camp.Id, ContactId=cMap.values()[0].id));
        QUEUEABLE001_AudienceManagement am = new QUEUEABLE001_AudienceManagement(camp.Id, new List<Id>(cMap.keySet()));
        try {
            Test.startTest();

            System.enqueueJob(am);
    
            Test.stopTest();
        } catch (Exception e) {
            System.assert(e.getMessage().contains('DUPLICATE_VALUE'));
        }
    }

    @IsTest
    public static void executeTestErrorUnhandled() {
        Map<Id,Contact> cMap = new Map<Id,Contact>([SELECT Id FROM Contact]);
        Id fakeCampaignId = '7011l000000oAAAAAA';
        QUEUEABLE001_AudienceManagement am = new QUEUEABLE001_AudienceManagement(fakeCampaignId, new List<Id>(cMap.keySet()));
        try {
            Test.startTest();

            System.enqueueJob(am);
    
            Test.stopTest();
        } catch (Exception e) {
            System.assert(e.getMessage().contains('UNKNOWN_EXCEPTION'));
        }
    }
}