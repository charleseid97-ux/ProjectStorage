/** ──────────────────────────────────────
 * @description Tests of the TaxData__c trigger: request name and duplicate check on insert, AT/CH Transparency emails after insert,
 *                  status from the Transparency dates, BE Asset Test fiscal dates with its BE TIS request, and the history archived
 *                  when a BE value changes.
 * @author Khadija
 * @covers TaxTriggerHandler   89%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_TaxTriggerHandler {

    private static final String COUNTRY_BE = 'BE';
    private static final String COUNTRY_AT = 'AT';
    private static final String TYPE_TRANSPARENCY = 'Transparency';
    private static final String TYPE_BE_TIS = 'BE TIS';
    private static final String TYPE_BE_ASSET_TEST = 'BE Asset Test';
    private static final String TYPE_BE_SIMULATOR = 'Belgium Simulator';
    private static final String STATUS_REQUESTED = 'Requested';
    private static final String STATUS_YES = 'Yes';
    private static final String STATUS_NO = 'No';
    private static final String SOURCE_MANUAL = 'Manual';
    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();

    // Name generated, duplicate blocked, and AT and CH Transparency requests inserted together (emails after insert)
    @isTest
    static void test_insertTaxData() {
        Product__c fund = createFund();
        Share_Class__c sc = createShareClass(fund.Id, 'LU1234567890');
        Share_Class__c otherSc = createShareClass(fund.Id, 'LU1234567891');
        insert new Country__c(ShareClass__c = otherSc.Id, Country__c = 'CH', RegistrationStatus__c = 'REG', RegistrationDate__c = Date.today(), ISINCountryKey__c = 'LU1234567891_CH');
        TaxData__c td = newTaxData(sc, fund, COUNTRY_AT, TYPE_TRANSPARENCY, STATUS_REQUESTED);
        List<TaxData__c> transparencyRequests = new List<TaxData__c>{ newTaxData(otherSc, fund, 'AT', TYPE_TRANSPARENCY, STATUS_REQUESTED), newTaxData(otherSc, fund, 'CH', TYPE_TRANSPARENCY, STATUS_REQUESTED) };

        Test.startTest();

        insert td;
        Database.SaveResult duplicate = Database.insert(newTaxData(sc, fund, COUNTRY_AT, TYPE_TRANSPARENCY, STATUS_REQUESTED), false);
        insert transparencyRequests;

        Test.stopTest();

        TaxData__c insertedTd = [SELECT Name FROM TaxData__c WHERE Id = :td.Id];
        Integer transparencyRequestCount = [SELECT COUNT() FROM TaxData__c WHERE Id IN :transparencyRequests];
        System.assert(insertedTd.Name.contains('Transparency - AT'), 'Le Name doit être généré automatiquement');
        System.assert(!duplicate.isSuccess(), 'Le doublon doit être bloqué');
        System.assert(duplicate.getErrors()[0].getMessage().contains('Duplicate records are not allowed'));
        System.assertEquals(2, transparencyRequestCount, 'Les TaxData AT et CH doivent être insérés, ce qui déclenche les appels email after insert');
        System.assert(TaxTriggerHandler.buildRequestName(TYPE_BE_TIS, COUNTRY_BE, 'Fund Name', 'Share Class Name').startsWith('TIS - BE -'));
        System.assertEquals('TIS', TaxTriggerHandler.normalizeBEType(TYPE_BE_TIS));
        System.assertEquals('Asset Test', TaxTriggerHandler.normalizeBEType(TYPE_BE_ASSET_TEST));
        System.assertEquals('Simulator', TaxTriggerHandler.normalizeBEType(TYPE_BE_SIMULATOR));
    }

    // Transparency status from its start and end dates, BE Asset Test and BE TIS value changes (history archived)
    @isTest
    static void test_updateTaxData() {
        Product__c fund = createFund();
        Share_Class__c startSc = createShareClass(fund.Id, 'LU1234567890');
        Share_Class__c endSc = createShareClass(fund.Id, 'LU1234567891');
        Share_Class__c assetTestSc = createShareClass(fund.Id, 'LU1234567892');
        Share_Class__c tisSc = createShareClass(fund.Id, 'LU1234567893');
        TaxData__c started = newTaxData(startSc, fund, COUNTRY_AT, TYPE_TRANSPARENCY, STATUS_REQUESTED);
        TaxData__c ended = newTaxData(endSc, fund, COUNTRY_AT, TYPE_TRANSPARENCY, STATUS_YES);
        ended.StartDate__c = Date.today().addDays(-10);
        TaxData__c assetTest = newTaxData(assetTestSc, fund, COUNTRY_BE, TYPE_BE_ASSET_TEST, STATUS_REQUESTED);
        assetTest.Value__c = 10;
        assetTest.StartDate__c = Date.newInstance(2025, 5, 1);
        assetTest.EndDate__c = Date.newInstance(2026, 4, 30);
        TaxData__c tis = newTaxData(tisSc, fund, COUNTRY_BE, TYPE_BE_TIS, STATUS_REQUESTED);
        tis.Value__c = 15;
        tis.NAV_Date__c = Date.newInstance(2026, 4, 28);
        insert new List<TaxData__c>{ started, ended, assetTest, tis };
        started.StartDate__c = Date.today();
        ended.EndDate__c = Date.today();
        assetTest.Value__c = 20;
        tis.Value__c = 30;

        Test.startTest();

        update new List<TaxData__c>{ started, ended, assetTest, tis };

        Test.stopTest();

        List<TaxData__c> updatedTaxData = [SELECT Status__c, StartDate__c, EndDate__c
                                           FROM TaxData__c
                                           WHERE Id IN :new List<Id>{ started.Id, ended.Id, assetTest.Id }];
        Map<Id, TaxData__c> updatedById = new Map<Id, TaxData__c>(updatedTaxData);
        System.assertEquals(STATUS_YES, updatedById.get(started.Id).Status__c);
        System.assertEquals(STATUS_NO, updatedById.get(ended.Id).Status__c);

        Date todayDate = Date.today();
        System.assertEquals(STATUS_YES, updatedById.get(assetTest.Id).Status__c);
        System.assertEquals(Date.newInstance(todayDate.year(), 5, 1), updatedById.get(assetTest.Id).StartDate__c);
        System.assertEquals(Date.newInstance(todayDate.year() + 1, 4, 30), updatedById.get(assetTest.Id).EndDate__c);
        List<TaxDataHistory__c> assetTestHistories = [SELECT Value__c FROM TaxDataHistory__c WHERE TaxData__c = :assetTest.Id];
        System.assertEquals(1, assetTestHistories.size(), 'Un historique doit être créé');
        System.assertEquals(10, assetTestHistories[0].Value__c);
        Integer beTisCount = [SELECT COUNT()
                              FROM TaxData__c
                              WHERE ShareClass__c = :assetTestSc.Id AND Country__c = :COUNTRY_BE AND Type__c = :TYPE_BE_TIS];
        System.assertEquals(1, beTisCount, 'Un record BE TIS doit être créé lorsque la value dépasse 10%.');

        List<TaxDataHistory__c> tisHistories = [SELECT Value__c, NAV_Date__c FROM TaxDataHistory__c WHERE TaxData__c = :tis.Id];
        System.assertEquals(1, tisHistories.size());
        System.assertEquals(15, tisHistories[0].Value__c);
        System.assertEquals(Date.newInstance(2026, 4, 28), tisHistories[0].NAV_Date__c);
    }

    private static Product__c createFund() {
        Product__c fund = PMTTestFactoryData.getProduct(fundRecordTypeId, 'TaxTriggerFund', 'Tax Trigger Fund', true);
        fund.LegalForm__c = 'FCP';
        update fund;
        return fund;
    }

    private static Share_Class__c createShareClass(Id fundId, String isin) {
        Share_Class__c sc = new Share_Class__c(Name = 'Tax Trigger SC', Name__c = 'Tax Trigger SC', Fund__c = fundId, DividendPolicy__c = 'Accumulating', Validity__c = true, ISIN__c = isin);
        insert sc;
        return sc;
    }

    private static TaxData__c newTaxData(Share_Class__c sc, Product__c fund, String country, String type, String status) {
        return new TaxData__c(ShareClass__c = sc.Id, Product__c = fund.Id, Country__c = country, Type__c = type, Status__c = status, Source__c = SOURCE_MANUAL);
    }
}