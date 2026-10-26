/** ──────────────────────────────────────
 * @description Tests of the Country__c trigger: Italian Transparency request created, deactivated and reactivated with the registration
 *                  of the share class in Italy (other countries ignored), and the Belgium Simulator request created for an FCP fund
 *                  only.
 * @author Khadija
 * @covers CountryTriggerHandler   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_CountryTriggerHandler {

    private static final String COUNTRY_IT = 'IT';
    private static final String COUNTRY_BE = 'BE';
    private static final String TYPE_TRANSPARENCY = 'Transparency';
    private static final String TYPE_BE_SIMULATOR = 'Belgium Simulator';
    private static final String STATUS_YES = 'Yes';
    private static final String STATUS_NO = 'No';
    private static final String SOURCE_MANUAL = 'Manual';
    private static final String STATUS_REG = 'REG';
    private static final String STATUS_NOT_REGISTERED = 'NOTREG';
    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();

    // Italy: request created on registration then deactivated, an existing request reactivated, and another country ignored
    @isTest
    static void test_italianTransparency() {
        Product__c fund = PMTTestFactoryData.getProduct(fundRecordTypeId, 'CountryTaxFund', 'Country Tax Fund', true);
        Share_Class__c registeredSc = createShareClass(fund.Id, 'LU1234567890');
        Share_Class__c reactivatedSc = createShareClass(fund.Id, 'LU1234567891');
        TaxData__c existing = new TaxData__c(ShareClass__c = reactivatedSc.Id, Product__c = fund.Id, Country__c = COUNTRY_IT, Type__c = TYPE_TRANSPARENCY, Status__c = STATUS_NO, Source__c = SOURCE_MANUAL, StartDate__c = Date.newInstance(2026, 1, 1), EndDate__c = Date.newInstance(2026, 1, 31));
        insert existing;
        Country__c reactivated = new Country__c(ShareClass__c = reactivatedSc.Id, Country__c = COUNTRY_IT, RegistrationStatus__c = STATUS_NOT_REGISTERED, RegistrationDate__c = Date.newInstance(2026, 1, 1), ISINCountryKey__c = 'LU1234567891_IT');
        insert reactivated;
        Country__c registered = new Country__c(ShareClass__c = registeredSc.Id, Country__c = COUNTRY_IT, RegistrationStatus__c = STATUS_REG, RegistrationDate__c = Date.newInstance(2026, 4, 28), ISINCountryKey__c = 'LU1234567890_IT');

        Test.startTest();

        insert registered;
        TaxData__c created = [SELECT ShareClass__c, Product__c, Status__c, Source__c, StartDate__c, EndDate__c
                              FROM TaxData__c
                              WHERE ShareClass__c = :registeredSc.Id AND Country__c = :COUNTRY_IT AND Type__c = :TYPE_TRANSPARENCY LIMIT 1];
        registered.RegistrationStatus__c = STATUS_NOT_REGISTERED;
        reactivated.RegistrationStatus__c = STATUS_REG;
        reactivated.RegistrationDate__c = Date.newInstance(2026, 4, 28);
        update new List<Country__c>{ registered, reactivated };
        insert new Country__c(ShareClass__c = registeredSc.Id, Country__c = 'FR', RegistrationStatus__c = STATUS_REG, RegistrationDate__c = Date.today(), ISINCountryKey__c = 'LU1234567890_FR');

        Test.stopTest();

        System.assertEquals(fund.Id, created.Product__c);
        System.assertEquals(STATUS_YES, created.Status__c);
        System.assertEquals(SOURCE_MANUAL, created.Source__c);
        System.assertEquals(Date.newInstance(2026, 4, 28), created.StartDate__c);
        System.assertEquals(null, created.EndDate__c);

        TaxData__c deactivated = [SELECT Status__c, EndDate__c FROM TaxData__c WHERE Id = :created.Id];
        System.assertEquals(STATUS_NO, deactivated.Status__c);
        System.assertEquals(Date.today(), deactivated.EndDate__c);

        TaxData__c reactivatedTaxData = [SELECT Status__c, StartDate__c, EndDate__c FROM TaxData__c WHERE Id = :existing.Id];
        System.assertEquals(STATUS_YES, reactivatedTaxData.Status__c);
        System.assertEquals(Date.newInstance(2026, 4, 28), reactivatedTaxData.StartDate__c);
        System.assertEquals(null, reactivatedTaxData.EndDate__c);

        Integer italianRequestCount = [SELECT COUNT() FROM TaxData__c WHERE ShareClass__c = :registeredSc.Id AND Country__c = :COUNTRY_IT];
        System.assertEquals(1, italianRequestCount, 'The FR registration creates no Italian request');
    }

    // Belgium: Simulator request created for a share class of an FCP fund, not for another legal form
    @isTest
    static void test_belgiumSimulator() {
        Product__c fcpFund = PMTTestFactoryData.getProduct(fundRecordTypeId, 'CountryTaxFundFCP', 'Country Tax Fund FCP', true);
        fcpFund.LegalForm__c = 'FCP';
        update fcpFund;
        Product__c otherFund = PMTTestFactoryData.getProduct(fundRecordTypeId, 'CountryTaxFund', 'Country Tax Fund', true);
        Share_Class__c fcpSc = createShareClass(fcpFund.Id, 'LU1234567890');
        Share_Class__c otherSc = createShareClass(otherFund.Id, 'LU1234567891');

        Test.startTest();

        Database.insert(new Country__c(ShareClass__c = fcpSc.Id, Country__c = COUNTRY_BE, RegistrationStatus__c = STATUS_REG, ISINCountryKey__c = 'LU1234567890_BE'), false);
        Database.insert(new Country__c(ShareClass__c = otherSc.Id, Country__c = COUNTRY_BE, RegistrationStatus__c = STATUS_REG, ISINCountryKey__c = 'LU1234567891_BE'), false);

        Test.stopTest();

        Integer fcpSimulatorCount = [SELECT COUNT()
                                     FROM TaxData__c
                                     WHERE ShareClass__c = :fcpSc.Id AND Country__c = :COUNTRY_BE AND Type__c = :TYPE_BE_SIMULATOR];
        Integer otherSimulatorCount = [SELECT COUNT()
                                       FROM TaxData__c
                                       WHERE ShareClass__c = :otherSc.Id AND Country__c = :COUNTRY_BE AND Type__c = :TYPE_BE_SIMULATOR];
        System.assertEquals(1, fcpSimulatorCount, 'FCP fund');
        System.assertEquals(0, otherSimulatorCount, 'Other legal form');
    }

    private static Share_Class__c createShareClass(Id fundId, String isin) {
        Share_Class__c sc = new Share_Class__c(Name = 'Country Tax SC', Fund__c = fundId, Validity__c = true, ISIN__c = isin, DividendPolicy__c = 'Accumulating');
        insert sc;
        return sc;
    }
}