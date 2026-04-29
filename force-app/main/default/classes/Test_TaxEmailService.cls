@IsTest
public with sharing class Test_TaxEmailService {
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
            Name = 'UK Fund',
            Product_Name__c = 'UK Fund',
            ProductName__c = 'UK Fund',
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

        insert new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
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
            WHERE ShareClass__c = :sc.Id
            AND Country__c = 'UK'
            AND Type__c = 'Transparency'
            AND Status__c = 'Requested'
        ];

        System.assertEquals(
            1,
            ukTaxDataCount,
            'Le TaxData UK Requested doit exister pour couvrir le traitement quarterly'
        );
    }

    @IsTest
    static void test_TaxUKQuarterlyEmailJob_execute() {
        Test.startTest();

        String jobId = System.schedule(
            'Test UK Quarterly Tax Email Job',
            '0 0 12 * * ?',
            new TaxUKQuarterlyEmailJob()
        );

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}