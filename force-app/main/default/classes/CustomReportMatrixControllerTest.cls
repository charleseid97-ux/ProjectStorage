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
                    EffectiveManagementFees__c = 1.0
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
    }

    @IsTest
    static void testGetMatrixData() {
        Test.startTest();

        CustomReportMatrixController.getMatrixData('CountryRegistrationStatusMatrix');
         try {
            CustomReportMatrixController.getMatrixData('NonExistentConfig');
        } catch (AuraHandledException e) { }

        Test.stopTest();
    }
}