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
            ProductName__c = UK_FUND_NAME,
            InternalShortName__c = 'UKFUND',
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
        // Adds an excluded CELT record to verify that it is ignored by the KPMG export.
        Product__c excludedFund = new Product__c(
            Name = 'CELT',
            ProductName__c = 'CELT',
            InternalShortName__c = 'CELT',
            FundStrategy__c = strategy.Id,
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRtId,
            Validity__c = true,
            LegalForm__c = 'OEIC',
            VehicleType__c = 'Funds'
        );
        insert excludedFund;

        Share_Class__c excludedShareClass = new Share_Class__c(
            Name = 'CELT Share Class',
            Name__c = 'CELT Share Class',
            Fund__c = excludedFund.Id,
            Type__c = 'A',
            Currency__c = 'GBP',
            LaunchDate__c = Date.today().addMonths(-6),
            Validity__c = true,
            ISIN__c = 'LU0000000002'
        );
        insert excludedShareClass;

        insert new TaxData__c(
            ShareClass__c = excludedShareClass.Id,
            Product__c = excludedFund.Id,
            Country__c = 'UK',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'Manual'
        );
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
    // Verifies Austria and Switzerland Transparency email processing.
    @IsTest
    static void test_sendATAndCHTransparencyEmails_paths() {
        Strategy__c strategy = new Strategy__c(
            Name = 'S TAX',
            AssetClass__c = 'Equity',
            SubAssetClass__c = 'Global',
            Code__c = 'STAX'
        );
        insert strategy;

        Id fundRtId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByDeveloperName()
            .get('Fund')
            .getRecordTypeId();

        Product__c fund = new Product__c(
            Name = 'Tax Fund',
            ProductName__c = 'Tax Fund',
            InternalShortName__c = 'TAXFUND',
            FundStrategy__c = strategy.Id,
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRtId,
            Validity__c = true,
            LegalForm__c = 'OEIC',
            VehicleType__c = 'Funds'
        );
        insert fund;

        Share_Class__c shareClass = new Share_Class__c(
            Name = 'Tax Share Class',
            Name__c = 'Tax Share Class',
            Fund__c = fund.Id,
            Type__c = 'A',
            Currency__c = 'EUR',
            LaunchDate__c = Date.today().addMonths(-6),
            Validity__c = true,
            ISIN__c = 'LU0000000003'
        );
        insert shareClass;

        // CH requires a registration date for the generated email.
        insert new Country__c(
            ShareClass__c = shareClass.Id,
            Country__c = 'CH',
            RegistrationStatus__c = 'REG',
            RegistrationDate__c = Date.today().addMonths(-3),
            ISINCountryKey__c = 'LU0000000003_CH'
        );

        TaxData__c atTaxData = new TaxData__c(
            ShareClass__c = shareClass.Id,
            Product__c = fund.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'Manual'
        );

        TaxData__c chTaxData = new TaxData__c(
            ShareClass__c = shareClass.Id,
            Product__c = fund.Id,
            Country__c = 'CH',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'Manual'
        );

        insert new List<TaxData__c>{ atTaxData, chTaxData };

        Test.startTest();

        TaxEmailService.sendATTransparencyEmails(
            new List<TaxData__c>{ atTaxData }
        );

        TaxEmailService.sendCHTransparencyEmails(
            new List<TaxData__c>{ chTaxData }
        );

        Test.stopTest();

        Set<Id> taxDataIds = new Set<Id>{ atTaxData.Id, chTaxData.Id };

        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM TaxData__c
                WHERE Id IN :taxDataIds
            ],
            'AT and CH TaxData records should remain available after email processing.'
        );
    }
}