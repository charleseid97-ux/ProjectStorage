/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 12-06-2023
 * @last modified by  : SILA Nicolas
**/
@IsTest
public with sharing class BATCH_AudienceManagementTest {
    
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
        BATCH_AudienceManagement batchJob = new BATCH_AudienceManagement(camp.Id, new List<Id>(cMap.keySet()),DateTime.now());
        Test.startTest();

        Database.executeBatch(batchJob, 200);

        Test.stopTest();
    }

    @IsTest
    public static void executeTestError() {
        Map<Id,Contact> cMap = new Map<Id,Contact>([SELECT Id FROM Contact]);        
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        insert (new CampaignMember(CampaignId=camp.Id, ContactId=cMap.values()[0].id));
        BATCH_AudienceManagement batchJob = new BATCH_AudienceManagement(camp.Id, new List<Id>(cMap.keySet()),DateTime.now());
        try {
            Test.startTest();

            Database.executeBatch(batchJob, 200);
    
            Test.stopTest();
        } catch (Exception e) {
            System.assert(e.getMessage().contains('DUPLICATE_VALUE'));
        }
    }

    @IsTest
    public static void executeTestErrorUnhandled() {
        Map<Id,Contact> cMap = new Map<Id,Contact>([SELECT Id FROM Contact]);
        Id fakeCampaignId = '7011l000000oAAAAAA';
        BATCH_AudienceManagement batchJob = new BATCH_AudienceManagement(fakeCampaignId, new List<Id>(cMap.keySet()),DateTime.now());
        try {
            Test.startTest();

            Database.executeBatch(batchJob, 200);
    
            Test.stopTest();
        } catch (Exception e) {
            System.assert(e.getMessage().contains('UNKNOWN_EXCEPTION'));
        }
    }
}