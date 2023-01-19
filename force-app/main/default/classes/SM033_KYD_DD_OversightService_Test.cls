/**
 * Created by noorg on 16/06/2021.
 */
@IsTest
public with sharing class SM033_KYD_DD_OversightService_Test
{
    @IsTest
    public static void testBehavior()
    {
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);

        List<Account> accList = new List<Account>{
                new Account(Name = 'Account FR Test', BusinessDevelopmentRegion__c = 'BP_FR'
                        , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                        , Billingcity = 'Chicago', BillingStreet = 'asd123', BillingPostalCode = '60606'
                        , BillingCountry = 'United States', In__c = 'Retail', Final_Distribution__c = 'Retail')
                , new Account(Name = 'Account ES Test', BusinessDevelopmentRegion__c = 'BP_ES'
                        , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                        , Billingcity = 'Barcelona', BillingStreet = 'xyz456', BillingPostalCode = '70301'
                        , BillingCountry = 'Spain', In__c = 'Retail', Final_Distribution__c = 'Retail')
                , new Account(Name = 'Account Fail Test', BusinessDevelopmentRegion__c = 'BP_LU', BillingCountry = 'Luxembourg')
        };
        insert accList;

        Grid__c franceGrid = new Grid__c(Name = 'France S5', ActiveGrid__c = true);
        insert franceGrid;

        Convention__c masterAgreement = new Convention__c(Name = 'tmpName', Grid__c = franceGrid.Id, Company__c = accList[0].Id,
                Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
                RecordTypeId = agmRtMap.get('Request_Agreement'), OwnerId = UserInfo.getUserId());
        insert masterAgreement;

        SingleRequestMock fakeUMEResp = new SingleRequestMock(
                200,
                'OK',
                'jsonUMEStr',
                null
        );

        Test.setMock(HttpCalloutMock.class, fakeUMEResp);

        Legal_Entity__c le = new Legal_Entity__c(
                Name = 'Test',
                LEI__c = '5067007V6269EHSP3295',
                TECH_brid__c = '5063007V6269EHOP329522'
        );

        insert le;

        KYD_Due_Diligence_Oversight__c kydDD = new KYD_Due_Diligence_Oversight__c(
                Name = 'Test',
                Active__c = true,
                LegalEntity__c = le.Id,
                Agreement__c = masterAgreement.Id
        );

        insert kydDD;

        KYC_Document_Configuration__c config = new KYC_Document_Configuration__c();
        config.RiskLevel__c = 'low';
        config.EntityType__c = 'Regulated & Listed Entities';
        config.KYD_Responsible__c = 'RELIANCE';
        config.CollectiveFunds_personality__c = 'No';
        insert config;

        Test.startTest();
        kydDD.Final_Risk__c = 'low';
        kydDD.EntityType__c = 'Regulated & Listed Entities';
        kydDD.KYD_Responsible__c = 'RELIANCE';
        kydDD.CollectiveFunds_personality__c = 'No';
        update kydDD;
        Test.stopTest();
    }
}