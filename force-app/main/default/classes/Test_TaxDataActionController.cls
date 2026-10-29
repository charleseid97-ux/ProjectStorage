/** ──────────────────────────────────────
 * @description Tests of TaxDataActionController: share class context, creation of TaxData requests from country/type pairs (and the
 *                  invalid inputs), closable requests, closure requests (matching and unknown selections), and the countries where the
 *                  share class is not registered.
 * @author Khadija
 * @covers TaxDataActionController   86%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_TaxDataActionController {

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
    private static final String KEY_AT_TRANSPARENCY = 'AT|Transparency';

    // Context of the share class, TaxData requests created from pairs, and the invalid inputs
    @isTest
    static void test_createTaxDataPairs() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);
        String pairsJson = JSON.serialize(new List<TaxDataActionController.Pair>{ buildPair('AT', 'Transparency'), buildPair('BE', 'BE TIS'), buildPair('BE', 'BE Asset Test') });

        Test.startTest();

        Share_Class__c context = TaxDataActionController.getContext(sc.Id);
        TaxDataActionController.CreateResult result = TaxDataActionController.createTaxDataPairs(sc.Id, pairsJson, 'Test comment');
        TaxDataActionController.CreateResult missingSc = TaxDataActionController.createTaxDataPairs(null, '[]', null);
        TaxDataActionController.CreateResult emptyPayload = TaxDataActionController.createTaxDataPairs(UserInfo.getUserId(), '', null);
        TaxDataActionController.CreateResult invalidJson = TaxDataActionController.createTaxDataPairs(UserInfo.getUserId(), 'not-json', null);

        Test.stopTest();

        System.assertEquals(sc.Id, context.Id, 'Le contexte doit être retourné');
        System.assertEquals(fund.Id, context.Fund__c);

        System.assertEquals(3, result.createdCount, '3 TaxData doivent être créés');
        System.assertEquals(3, result.createdIds.size(), 'Les IDs créés doivent être retournés');
        System.assertEquals(0, result.failedByCountry.size(), 'Aucune erreur attendue');
        Set<String> keys = new Set<String>();
        for (TaxData__c td : [SELECT ShareClass__c, Product__c, Country__c, Type__c, Status__c, Source__c
                              FROM TaxData__c
                              WHERE ShareClass__c = :sc.Id]) {
            System.assertEquals(fund.Id, td.Product__c);
            System.assertEquals('Requested', td.Status__c);
            System.assertEquals('Manual', td.Source__c);
            keys.add(td.Country__c + '|' + td.Type__c);
        }
        System.assertEquals(new Set<String>{ KEY_AT_TRANSPARENCY, 'BE|BE TIS', 'BE|BE Asset Test' }, keys);

        System.assertEquals('Missing Share Class Id.', missingSc.message);
        System.assertEquals('No countries provided (empty payload).', emptyPayload.message);
        System.assert(invalidJson.message.startsWith('Invalid payload:'));
    }

    // Closable requests (IT excluded), closure of a matching request and of an unknown one, and the unregistered countries
    @isTest
    static void test_closeTaxData() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id);
        TaxData__c atTransparency = newTaxData(sc, fund, 'AT', 'Transparency');
        insert new List<TaxData__c>{ atTransparency, newTaxData(sc, fund, 'BE', 'BE TIS'), newTaxData(sc, fund, 'IT', 'Transparency') };
        insert new Country__c(ShareClass__c = sc.Id, Country__c = 'GB', RegistrationStatus__c = 'REG', ISINCountryKey__c = 'FR0010111111_GB');

        Test.startTest();

        List<TaxDataActionController.ClosableOption> options = TaxDataActionController.getClosableTaxDataOptions(sc.Id);
        TaxDataActionController.UpdateResult closed = TaxDataActionController.submitClosureRequests(sc.Id, new List<String>{ KEY_AT_TRANSPARENCY });
        TaxDataActionController.UpdateResult noMatch = TaxDataActionController.submitClosureRequests(sc.Id, new List<String>{ 'CH|Transparency' });
        List<String> unregistered = TaxDataActionController.getUnregisteredCountries(sc.Id, new List<String>{ 'UK', 'AT' });

        Test.stopTest();

        Set<String> optionKeys = new Set<String>();
        for (TaxDataActionController.ClosableOption option : options) optionKeys.add(option.key);
        System.assertEquals(new Set<String>{ KEY_AT_TRANSPARENCY, 'BE|BE TIS' }, optionKeys, 'IT doit être exclu des options');

        System.assertEquals(1, closed.updatedCount);
        System.assertEquals(1, closed.updatedIds.size());
        System.assertEquals(0, closed.failedByCountry.size());
        TaxData__c closedTaxData = [SELECT De_Register__c FROM TaxData__c WHERE Id = :atTransparency.Id];
        System.assert(closedTaxData.De_Register__c, 'De-registration requested');

        System.assertEquals(0, noMatch.updatedCount);
        System.assert(noMatch.failedByCountry.containsKey('CH|Transparency'), 'La sélection inexistante doit être remontée en erreur');

        System.assert(!unregistered.contains('UK'), 'UK doit être considéré enregistré via GB');
        System.assert(unregistered.contains('AT'), 'AT doit être retourné comme non enregistré');
    }

    private static Product__c createFund() {
        return PMTTestFactoryData.getProduct(fundRecordTypeId, 'TaxFundCode', 'Tax Fund', true);
    }

    private static Share_Class__c createShareClass(Id fundId) {
        Share_Class__c sc = new Share_Class__c(Name = 'Tax Share Class', Fund__c = fundId, ISIN__c = 'FR0010111111', Validity__c = true);
        insert sc;
        return sc;
    }

    private static TaxData__c newTaxData(Share_Class__c sc, Product__c fund, String country, String type) {
        return new TaxData__c(ShareClass__c = sc.Id, Product__c = fund.Id, Country__c = country, Type__c = type, Status__c = 'Yes', Source__c = 'Manual', De_Register__c = false);
    }

    private static TaxDataActionController.Pair buildPair(String country, String typeValue) {
        TaxDataActionController.Pair pair = new TaxDataActionController.Pair();
        pair.country = country;
        pair.typeValue = typeValue;
        return pair;
    }
}