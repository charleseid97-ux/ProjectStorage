@isTest
private class Test_RegistrationCountryDatatableCTRL {
    @isTest
    static void testGetUniqueCountries() {
        // Créer un produit de test
        Id productRecordTypeId = PMTTestFactoryData.getRecordTypeId('Product__c', 'Fund');
        Product__c product = PMTTestFactoryData.getProduct(productRecordTypeId, 'PROD01', 'Test Product', true);
 
        // Créer deux shareclasses liées à ce produit
        Share_Class__c sc1 = new Share_Class__c(Name = 'SC1', Fund__c = product.Id);
        Share_Class__c sc2 = new Share_Class__c(Name = 'SC2', Fund__c = product.Id);
        insert new List<Share_Class__c>{ sc1, sc2 };
 
        // Créer plusieurs Country__c pour simuler doublons + date la plus ancienne
        Country__c c1 = new Country__c(ISINCountryKey__c = 'LU162376321_FR', Name = 'FR', Country__c = 'FR', RegistrationStatus__c='REG', ShareClass__c = sc1.Id, RegistrationDate__c = Date.newInstance(2021, 1, 1));
        Country__c c2 = new Country__c(ISINCountryKey__c = 'LU162376322_LU', Name = 'LU', Country__c = 'LU', RegistrationStatus__c='REG', ShareClass__c = sc2.Id, RegistrationDate__c = Date.newInstance(2020, 3, 22));
        Country__c c3 = new Country__c(ISINCountryKey__c = 'LU162376323_PT', Name = 'PT', Country__c = 'PT', RegistrationStatus__c='INSTITUTIONAL_ONLY', ShareClass__c = sc1.Id, RegistrationDate__c = Date.newInstance(2019, 7, 14));
        Country__c c4 = new Country__c(ISINCountryKey__c = 'LU162376324_ES', Name = 'ES', Country__c = 'ES', RegistrationStatus__c='INSTITUTIONAL_ONLY', ShareClass__c = sc1.Id, RegistrationDate__c = Date.newInstance(2023, 9, 1));
        insert new List<Country__c>{ c1, c2, c3, c4 };
 
        Test.startTest();
        List<RegistrationCountryDatatableController.CountryDTO> results = RegistrationCountryDatatableController.getUniqueCountries(product.Id);
        Test.stopTest();
 
    }
}