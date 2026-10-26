/** ──────────────────────────────────────
 * @description Tests of RegistrationCountryDatatableController.getUniqueCountries: registration countries of a fund's share classes,
 *                  one line per country and registration status (REG and INSTITUTIONAL_ONLY).
 * @covers RegistrationCountryDatatableController   96%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_RegistrationCountryDatatableCTRL {

    @isTest
    static void test_getUniqueCountries() {
        Product__c product = PMTTestFactoryData.getProduct(PMTTestFactoryData.getRecordTypeId('Product__c', 'Fund'), 'PROD01', 'Test Product', true);
        Share_Class__c sc1 = new Share_Class__c(Name = 'SC1', Fund__c = product.Id);
        Share_Class__c sc2 = new Share_Class__c(Name = 'SC2', Fund__c = product.Id);
        insert new List<Share_Class__c>{ sc1, sc2 };

        // 4 countries on 2 share classes, registered or for institutional investors only
        insert new List<Country__c>{
            new Country__c(ISINCountryKey__c = 'LU162376321_FR', Name = 'FR', Country__c = 'FR', RegistrationStatus__c = 'REG', ShareClass__c = sc1.Id, RegistrationDate__c = Date.newInstance(2021, 1, 1)),
            new Country__c(ISINCountryKey__c = 'LU162376322_LU', Name = 'LU', Country__c = 'LU', RegistrationStatus__c = 'REG', ShareClass__c = sc2.Id, RegistrationDate__c = Date.newInstance(2020, 3, 22)),
            new Country__c(ISINCountryKey__c = 'LU162376323_PT', Name = 'PT', Country__c = 'PT', RegistrationStatus__c = 'INSTITUTIONAL_ONLY', ShareClass__c = sc1.Id, RegistrationDate__c = Date.newInstance(2019, 7, 14)),
            new Country__c(ISINCountryKey__c = 'LU162376324_ES', Name = 'ES', Country__c = 'ES', RegistrationStatus__c = 'INSTITUTIONAL_ONLY', ShareClass__c = sc1.Id, RegistrationDate__c = Date.newInstance(2023, 9, 1))
        };

        Test.startTest();

        List<RegistrationCountryDatatableController.CountryDTO> results = RegistrationCountryDatatableController.getUniqueCountries(product.Id);

        Test.stopTest();

        System.assertEquals(4, results.size(), 'One line per country and registration status');
    }
}