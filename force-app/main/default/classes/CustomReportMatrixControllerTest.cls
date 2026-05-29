/**
 * @description Test Class for CustomReportMatrixController
 * @author Charles EID
 * @testCoverage CustomReportMatrixController (97%)
 */
@IsTest
private class CustomReportMatrixControllerTest {

    @TestSetup
    static void setup() {
        Strategy__c strategy = new Strategy__c(
            Name         = 'Test Strategy',
            AssetClass__c = 'Equity',
            Code__c      = 'TST'
        );
        insert strategy;

        List<Product__c> products = new List<Product__c>();
        for (Integer i = 1; i <= 5; i++) {
            products.add(new Product__c(
                Name                 = 'Product ' + i,
                ProductName__c       = 'Product ' + i,
                FundStrategy__c      = strategy.Id,
                InternalShortName__c = 'PROD' + i,
                Legal_Status__c      = 'FCP',
                Fund_Code__c         = 'PROD' + i
            ));
        }
        insert products;

        List<Share_Class__c> shareClasses = new List<Share_Class__c>();
        Integer isinCounter = 1000;
        for (Integer i = 0; i < 5; i++) {
            for (Integer j = 1; j <= 2; j++) {
                String isin = 'LU' + isinCounter++;
                shareClasses.add(new Share_Class__c(
                    Name                       = 'SC-' + isin,
                    Name__c                    = 'SC-' + isin,
                    Fund__c                    = products[i].Id,
                    ISIN__c                    = isin,
                    ISIN_Code__c               = isin,
                    Type__c                    = 'A',
                    Currency__c                = 'EUR',
                    EffectiveManagementFees__c = 1.0,
                    Validity__c 			   = true,
                    Status__c 				   = 'Active'
                ));
            }
        }
        insert shareClasses;

        String[] codes    = new String[]{ 'FR', 'DE', 'GB' };
        String[] statuses = new String[]{ 'REG', 'TOBEREG', 'NOTREG' };
        List<Country__c> countries = new List<Country__c>();
        for (Integer i = 0; i < 3; i++) {
            countries.add(new Country__c(
                ShareClass__c         = shareClasses[i].Id,
                Country__c            = codes[i],
                RegistrationStatus__c = statuses[i],
                ISINCountryKey__c     = shareClasses[i].ISIN_Code__c + '-' + codes[i],
                RegistrationDate__c   = Date.today(),
                StartDate__c          = Date.today()
            ));
        }
        insert countries;
        
        List<TaxData__c> taxDataList = new List<TaxData__c>();
        for (Integer i = 0; i < 3; i++) {
            taxDataList.add(new TaxData__c(
                ShareClass__c = shareClasses[i].Id,
                Product__c = shareClasses[i].Fund__c,
                Country__c = 'IT',
                Type__c = 'Transparency',
                Status__c = 'Yes',
                Source__c = 'Manual',
                StartDate__c = Date.Today()
            ));
        }
        insert taxDataList;
    }

    @IsTest
    static void testCountryRegistrationStatusMatrixData() {
        Test.startTest();

        CustomReportMatrixController.getMatrixData('CountryRegistrationStatusMatrix', null, true);
        String filterTest = '{"ShareClass__r.Name__c":["SC-LU1000"]}';
        CustomReportMatrixController.getMatrixData('CountryRegistrationStatusMatrix', filterTest, false);
        try {
            CustomReportMatrixController.getMatrixData('NonExistentConfig', null, true);
        } catch (AuraHandledException e) { }

        Test.stopTest();
    }
    
    @IsTest
    static void testCountryTaxStatusMatrixData() {
        Test.startTest();

        String filterTestDate = '{"StartDate__c":["2025-01-01"]}';
        CustomReportMatrixController.getMatrixData('CountryTaxStatusMatrix', filterTestDate, true);

        Test.stopTest();
    }
}