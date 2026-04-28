@IsTest
private class Test_TaxDataActionController {

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName()
        .get('Fund')
        .getRecordTypeId();

    private static Product__c createFund() {
        return PMTTestFactoryData.getProduct(
            fundRecordTypeId,
            'TaxFundCode',
            'Tax Fund',
            true
        );
    }

    private static Share_Class__c createShareClass(Id fundId) {
        Share_Class__c sc = new Share_Class__c(
            Name = 'Tax Share Class',
            Fund__c = fundId,
            ISIN__c = 'FR0010111111',
            Validity__c = true
        );
        insert sc;
        return sc;
    }

    @IsTest
    static void test_getContext() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);

        Test.startTest();
        Share_Class__c result = TaxDataActionController.getContext(sc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Le contexte doit être retourné');
        System.assertEquals(sc.Id, result.Id);
        System.assertEquals(fund.Id, result.Fund__c);
    }

    @IsTest
    static void test_createTaxDataPairs_success() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);

        String pairsJson = JSON.serialize(new List<TaxDataActionController.Pair>{
            buildPair('AT', 'Transparency'),
            buildPair('BE', 'BE TIS'),
            buildPair('BE', 'BE Asset Test')
        });

        Test.startTest();
        TaxDataActionController.CreateResult result =
            TaxDataActionController.createTaxDataPairs(sc.Id, pairsJson, 'Test comment');
        Test.stopTest();

        System.assertEquals(3, result.createdCount, '3 TaxData doivent être créés');
        System.assertEquals(3, result.createdIds.size(), 'Les IDs créés doivent être retournés');
        System.assertEquals(0, result.failedByCountry.size(), 'Aucune erreur attendue');

        List<TaxData__c> taxDataList = [
            SELECT Id, ShareClass__c, Product__c, Country__c, Type__c, Status__c, Source__c
            FROM TaxData__c
            WHERE ShareClass__c = :sc.Id
        ];

        System.assertEquals(3, taxDataList.size());

        Set<String> keys = new Set<String>();
        for (TaxData__c td : taxDataList) {
            System.assertEquals(sc.Id, td.ShareClass__c);
            System.assertEquals(fund.Id, td.Product__c);
            System.assertEquals('Requested', td.Status__c);
            System.assertEquals('Manual', td.Source__c);
            keys.add(td.Country__c + '|' + td.Type__c);
        }

        System.assertEquals(true, keys.contains('AT|Transparency'));
        System.assertEquals(true, keys.contains('BE|BE TIS'));
        System.assertEquals(true, keys.contains('BE|BE Asset Test'));
    }

    @IsTest
    static void test_createTaxDataPairs_invalidInputs() {
        Test.startTest();

        TaxDataActionController.CreateResult missingSc =
            TaxDataActionController.createTaxDataPairs(null, '[]', null);

        TaxDataActionController.CreateResult emptyPayload =
            TaxDataActionController.createTaxDataPairs(UserInfo.getUserId(), '', null);

        TaxDataActionController.CreateResult invalidJson =
            TaxDataActionController.createTaxDataPairs(UserInfo.getUserId(), 'not-json', null);

        Test.stopTest();

        System.assertEquals('Missing Share Class Id.', missingSc.message);
        System.assertEquals('No countries provided (empty payload).', emptyPayload.message);
        System.assertEquals(true, invalidJson.message.startsWith('Invalid payload:'));
    }

    @IsTest
    static void test_getClosableTaxDataOptions() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);

        insert new List<TaxData__c>{
            new TaxData__c(
                ShareClass__c = sc.Id,
                Product__c = fund.Id,
                Country__c = 'AT',
                Type__c = 'Transparency',
                Status__c = 'Yes',
                Source__c = 'Manual',
                De_Register__c = false
            ),
            new TaxData__c(
                ShareClass__c = sc.Id,
                Product__c = fund.Id,
                Country__c = 'BE',
                Type__c = 'BE TIS',
                Status__c = 'Yes',
                Source__c = 'Manual',
                De_Register__c = false
            ),
            new TaxData__c(
                ShareClass__c = sc.Id,
                Product__c = fund.Id,
                Country__c = 'IT',
                Type__c = 'Transparency',
                Status__c = 'Yes',
                Source__c = 'Manual',
                De_Register__c = false
            )
        };

        Test.startTest();
        List<TaxDataActionController.ClosableOption> options =
            TaxDataActionController.getClosableTaxDataOptions(sc.Id);
        Test.stopTest();

        System.assertEquals(2, options.size(), 'IT doit être exclu des options');

        Set<String> keys = new Set<String>();
        for (TaxDataActionController.ClosableOption option : options) {
            keys.add(option.key);
        }

        System.assertEquals(true, keys.contains('AT|Transparency'));
        System.assertEquals(true, keys.contains('BE|BE TIS'));
    }

    @IsTest
    static void test_submitClosureRequests_success() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Yes',
            Source__c = 'Manual',
            De_Register__c = false
        );
        insert td;

        Test.startTest();
        TaxDataActionController.UpdateResult result =
            TaxDataActionController.submitClosureRequests(
                sc.Id,
                new List<String>{ 'AT|Transparency' }
            );
        Test.stopTest();

        System.assertEquals(1, result.updatedCount);
        System.assertEquals(1, result.updatedIds.size());
        System.assertEquals(0, result.failedByCountry.size());

        TaxData__c updatedTd = [
            SELECT De_Register__c
            FROM TaxData__c
            WHERE Id = :td.Id
        ];

        System.assertEquals(true, updatedTd.De_Register__c);
    }

    @IsTest
    static void test_submitClosureRequests_noMatch() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);

        insert new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Yes',
            Source__c = 'Manual',
            De_Register__c = false
        );

        Test.startTest();
        TaxDataActionController.UpdateResult result =
            TaxDataActionController.submitClosureRequests(
                sc.Id,
                new List<String>{ 'CH|Transparency' }
            );
        Test.stopTest();

        System.assertEquals(0, result.updatedCount);
        System.assertEquals(
            true,
            result.failedByCountry.containsKey('CH|Transparency'),
            'La sélection inexistante doit être remontée en erreur'
        );
    }

    @IsTest
    static void test_getUnregisteredCountries() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);

        insert new Country__c(
            ShareClass__c = sc.Id,
            Country__c = 'GB',
            RegistrationStatus__c = 'REG',
            ISINCountryKey__c = 'FR0010111111_GB'
        );

        Test.startTest();
        List<String> result = TaxDataActionController.getUnregisteredCountries(
            sc.Id,
            new List<String>{ 'UK', 'AT' }
        );
        Test.stopTest();

        System.assertEquals(false, result.contains('UK'), 'UK doit être considéré enregistré via GB');
        System.assertEquals(true, result.contains('AT'), 'AT doit être retourné comme non enregistré');
    }

    private static TaxDataActionController.Pair buildPair(String country, String typeValue) {
        TaxDataActionController.Pair pair = new TaxDataActionController.Pair();
        pair.country = country;
        pair.typeValue = typeValue;
        return pair;
    }
}