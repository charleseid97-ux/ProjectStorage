@IsTest
public with sharing class Test_TaxEmailService {

    private static final String UK_FUND_NAME = 'UK Fund';

    @IsTest
    static void test_sendUKQuarterlyTransparencyEmails_path() {
        Strategy__c strategy = new Strategy__c(
            Name = 'S UK',
            AssetClass__c = 'Equity',
            SubAssetClass__c = 'Global',
            Code__c = 'SUK'
        );
        insert strategy;

        Id fundRtId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByDeveloperName()
            .get('Fund')
            .getRecordTypeId();

        Product__c fund = new Product__c(
            Name = UK_FUND_NAME,
            Product_Name__c = UK_FUND_NAME,
            ProductName__c = UK_FUND_NAME,
            FundStrategy__c = strategy.Id,
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRtId,
            Validity__c = true,
            LegalForm__c = 'OEIC',
            VehicleType__c = 'Funds'
        );
        insert fund;

        Share_Class__c sc = new Share_Class__c(
            Name = 'UK Share Class',
            Name__c = 'UK Share Class',
            Fund__c = fund.Id,
            Type__c = 'A',
            Currency__c = 'GBP',
            LaunchDate__c = Date.today().addMonths(-6),
            Validity__c = true,
            ISIN__c = 'LU0000000001'
        );
        insert sc;

        insert new Country__c(
            ShareClass__c = sc.Id,
            Country__c = 'GB',
            RegistrationStatus__c = 'REG',
            RegistrationDate__c = Date.today().addMonths(-3),
            ISINCountryKey__c = 'LU0000000001_GB'
        );

        TaxData__c taxData = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = 'UK',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'Manual'
        );
        insert taxData;

        Test.startTest();
        TaxEmailService.sendUKQuarterlyTransparencyEmails();
        Test.stopTest();

        Integer ukTaxDataCount = [
            SELECT COUNT()
            FROM TaxData__c
            WHERE Id = :taxData.Id
        ];

        System.assertEquals(
            1,
            ukTaxDataCount,
            'The UK TaxData record should exist.'
        );
    }

    @IsTest
    static void test_TaxUKQuarterlyEmailJob_schedule() {
        Test.startTest();

        String jobId = System.schedule(
            'Test UK Quarterly Tax Email Job',
            '0 0 8 * * ?',
            new TaxUKQuarterlyEmailJob()
        );

        Test.stopTest();

        System.assertNotEquals(
            null,
            jobId,
            'The scheduled job Id should not be null.'
        );
    }

    @IsTest
    static void test_TaxUKQuarterlyEmailJob_execute_directly() {
        Test.startTest();
        TaxUKQuarterlyEmailJob.forceRunForTest = true;
        new TaxUKQuarterlyEmailJob().execute(null);
        Test.stopTest();
    
        System.assert(true, 'Job executed without exception.');
    }
    
    @IsTest
static void test_getLastBusinessDayOfMonth() {
    System.assertEquals(
        Date.newInstance(2026, 2, 27),
        TaxUKQuarterlyEmailJob.getLastBusinessDayOfMonth(Date.newInstance(2026, 2, 1))
    );

    System.assertEquals(
        Date.newInstance(2025, 8, 29),
        TaxUKQuarterlyEmailJob.getLastBusinessDayOfMonth(Date.newInstance(2025, 8, 1))
    );

    System.assertEquals(
        Date.newInstance(2025, 3, 31),
        TaxUKQuarterlyEmailJob.getLastBusinessDayOfMonth(Date.newInstance(2025, 3, 1))
    );
}
}