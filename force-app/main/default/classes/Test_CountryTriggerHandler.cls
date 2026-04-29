@IsTest
private class Test_CountryTriggerHandler {

    private static final String COUNTRY_IT = 'IT';
    private static final String TYPE_TRANSPARENCY = 'Transparency';
    private static final String STATUS_YES = 'Yes';
    private static final String STATUS_NO = 'No';
    private static final String SOURCE_MANUAL = 'Manual';
    private static final String STATUS_REG = 'REG';
    private static final String STATUS_NOT_REGISTERED = 'NOTREG';

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName()
        .get('Fund')
        .getRecordTypeId();

    private static Share_Class__c createShareClass() {
        Product__c fund = PMTTestFactoryData.getProduct(
            fundRecordTypeId,
            'CountryTaxFund',
            'Country Tax Fund',
            true
        );

        Share_Class__c sc = new Share_Class__c(
            Name = 'Country Tax SC',
            Fund__c = fund.Id,
            Validity__c = true,
            ISIN__c = 'LU1234567890'
        );
        insert sc;

        return sc;
    }

    @IsTest
    static void test_insertItalianEligible_createsTaxData() {
        Share_Class__c sc = createShareClass();

        Country__c country = new Country__c(
            ShareClass__c = sc.Id,
            Country__c = COUNTRY_IT,
            RegistrationStatus__c = STATUS_REG,
            RegistrationDate__c = Date.newInstance(2026, 4, 28),
            ISINCountryKey__c = 'LU1234567890_IT'
        );

        Test.startTest();
        insert country;
        Test.stopTest();

        TaxData__c taxData = [
            SELECT ShareClass__c, Product__c, Country__c, Type__c,
                   Status__c, Source__c, StartDate__c, EndDate__c
            FROM TaxData__c
            WHERE ShareClass__c = :sc.Id
            AND Country__c = :COUNTRY_IT
            AND Type__c = :TYPE_TRANSPARENCY
            LIMIT 1
        ];

        System.assertEquals(sc.Id, taxData.ShareClass__c);
        System.assertEquals(sc.Fund__c, taxData.Product__c);
        System.assertEquals(STATUS_YES, taxData.Status__c);
        System.assertEquals(SOURCE_MANUAL, taxData.Source__c);
        System.assertEquals(Date.newInstance(2026, 4, 28), taxData.StartDate__c);
        System.assertEquals(null, taxData.EndDate__c);
    }

    @IsTest
    static void test_updateItalianBecomesEligible_updatesExistingTaxData() {
        Share_Class__c sc = createShareClass();

        TaxData__c existing = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = sc.Fund__c,
            Country__c = COUNTRY_IT,
            Type__c = TYPE_TRANSPARENCY,
            Status__c = STATUS_NO,
            Source__c = SOURCE_MANUAL,
            StartDate__c = Date.newInstance(2026, 1, 1),
            EndDate__c = Date.newInstance(2026, 1, 31)
        );
        insert existing;

        Country__c country = new Country__c(
            ShareClass__c = sc.Id,
            Country__c = COUNTRY_IT,
            RegistrationStatus__c = STATUS_NOT_REGISTERED,
            RegistrationDate__c = Date.newInstance(2026, 1, 1),
            ISINCountryKey__c = 'LU1234567890_IT'
        );
        insert country;

        country.RegistrationStatus__c = STATUS_REG;
        country.RegistrationDate__c = Date.newInstance(2026, 4, 28);

        Test.startTest();
        update country;
        Test.stopTest();

        TaxData__c updatedTaxData = [
            SELECT Status__c, StartDate__c, EndDate__c
            FROM TaxData__c
            WHERE Id = :existing.Id
        ];

        System.assertEquals(STATUS_YES, updatedTaxData.Status__c);
        System.assertEquals(Date.newInstance(2026, 4, 28), updatedTaxData.StartDate__c);
        System.assertEquals(null, updatedTaxData.EndDate__c);
    }

    @IsTest
    static void test_updateItalianNoLongerEligible_deactivatesTaxData() {
        Share_Class__c sc = createShareClass();

        Country__c country = new Country__c(
            ShareClass__c = sc.Id,
            Country__c = COUNTRY_IT,
            RegistrationStatus__c = STATUS_REG,
            RegistrationDate__c = Date.newInstance(2026, 4, 1),
            ISINCountryKey__c = 'LU1234567890_IT'
        );
        insert country;

        TaxData__c existing = [
            SELECT Id, Status__c, EndDate__c
            FROM TaxData__c
            WHERE ShareClass__c = :sc.Id
            AND Country__c = :COUNTRY_IT
            AND Type__c = :TYPE_TRANSPARENCY
            LIMIT 1
        ];

        country.RegistrationStatus__c = STATUS_NOT_REGISTERED;

        Test.startTest();
        update country;
        Test.stopTest();

        TaxData__c updatedTaxData = [
            SELECT Status__c, EndDate__c
            FROM TaxData__c
            WHERE Id = :existing.Id
        ];

        System.assertEquals(STATUS_NO, updatedTaxData.Status__c);
        System.assertEquals(Date.today(), updatedTaxData.EndDate__c);
    }

    @IsTest
    static void test_nonItalyIgnored() {
        Share_Class__c sc = createShareClass();

        Country__c country = new Country__c(
            ShareClass__c = sc.Id,
            Country__c = 'FR',
            RegistrationStatus__c = STATUS_REG,
            RegistrationDate__c = Date.today(),
            ISINCountryKey__c = 'LU1234567890_FR'
        );

        Test.startTest();
        insert country;
        Test.stopTest();

        Integer countTaxData = [
            SELECT COUNT()
            FROM TaxData__c
            WHERE ShareClass__c = :sc.Id
            AND Country__c = :COUNTRY_IT
        ];

        System.assertEquals(0, countTaxData);
    }
}