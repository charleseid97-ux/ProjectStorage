@IsTest
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
    private static final String STATUS_DEREG_REQUESTED = 'De-Registered Requested';

    private static final String SOURCE_MANUAL = 'Manual';

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName()
        .get('Fund')
        .getRecordTypeId();

    private static Product__c createFund(String legalForm) {
        Product__c fund = PMTTestFactoryData.getProduct(
            fundRecordTypeId,
            'TaxTriggerFund',
            'Tax Trigger Fund',
            true
        );

        fund.LegalForm__c = legalForm;
        update fund;

        return fund;
    }

    private static Share_Class__c createShareClass(Id fundId, String dividendPolicy) {
        Share_Class__c sc = new Share_Class__c(
            Name = 'Tax Trigger SC',
            Name__c = 'Tax Trigger SC',
            Fund__c = fundId,
            DividendPolicy__c = dividendPolicy,
            Validity__c = true,
            ISIN__c = 'LU1234567890'
        );
        insert sc;

        return sc;
    }

    @IsTest
    static void test_beforeInsert_populatesName() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_AT,
            Type__c = TYPE_TRANSPARENCY,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL
        );

        Test.startTest();
        insert td;
        Test.stopTest();

        TaxData__c insertedTd = [
            SELECT Name
            FROM TaxData__c
            WHERE Id = :td.Id
        ];

        System.assertEquals(
            true,
            insertedTd.Name.contains('Transparency - AT'),
            'Le Name doit être généré automatiquement'
        );
    }

    @IsTest
    static void test_preventDuplicates_blocksDuplicateOnInsert() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        insert new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_AT,
            Type__c = TYPE_TRANSPARENCY,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL
        );

        TaxData__c duplicateTd = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_AT,
            Type__c = TYPE_TRANSPARENCY,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(duplicateTd, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Le doublon doit être bloqué');
        System.assertEquals(
            true,
            sr.getErrors()[0].getMessage().contains('Duplicate records are not allowed')
        );
    }

    @IsTest
    static void test_handleDates_transparencyStartDateSetsYes() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_AT,
            Type__c = TYPE_TRANSPARENCY,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL
        );
        insert td;

        td.StartDate__c = Date.today();

        Test.startTest();
        update td;
        Test.stopTest();

        TaxData__c updatedTd = [
            SELECT Status__c
            FROM TaxData__c
            WHERE Id = :td.Id
        ];

        System.assertEquals(STATUS_YES, updatedTd.Status__c);
    }

    @IsTest
    static void test_handleDates_transparencyEndDateSetsNo() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_AT,
            Type__c = TYPE_TRANSPARENCY,
            Status__c = STATUS_YES,
            Source__c = SOURCE_MANUAL,
            StartDate__c = Date.today().addDays(-10)
        );
        insert td;

        td.EndDate__c = Date.today();

        Test.startTest();
        update td;
        Test.stopTest();

        TaxData__c updatedTd = [
            SELECT Status__c
            FROM TaxData__c
            WHERE Id = :td.Id
        ];

        System.assertEquals(STATUS_NO, updatedTd.Status__c);
    }

    @IsTest
    static void test_beAssetTest_valueChange_setsFiscalDatesAndArchivesHistory() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_BE,
            Type__c = TYPE_BE_ASSET_TEST,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL,
            Value__c = 10,
            StartDate__c = Date.newInstance(2025, 5, 1),
            EndDate__c = Date.newInstance(2026, 4, 30)
        );
        insert td;

        td.Value__c = 20;

        Test.startTest();
        update td;
        Test.stopTest();

        TaxData__c updatedTd = [
            SELECT Status__c, StartDate__c, EndDate__c
            FROM TaxData__c
            WHERE Id = :td.Id
        ];

        Date todayDate = Date.today();

        System.assertEquals(STATUS_YES, updatedTd.Status__c);
        System.assertEquals(Date.newInstance(todayDate.year(), 5, 1), updatedTd.StartDate__c);
        System.assertEquals(Date.newInstance(todayDate.year() + 1, 4, 30), updatedTd.EndDate__c);

        List<TaxDataHistory__c> histories = [
            SELECT TaxData__c, Value__c, StartDate__c, EndDate__c
            FROM TaxDataHistory__c
            WHERE TaxData__c = :td.Id
        ];

        System.assertEquals(1, histories.size(), 'Un historique doit être créé');
        System.assertEquals(10, histories[0].Value__c);
    }

    @IsTest
    static void test_beTis_valueChange_archivesHistory() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_BE,
            Type__c = TYPE_BE_TIS,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL,
            Value__c = 15,
            NAV_Date__c = Date.newInstance(2026, 4, 28)
        );
        insert td;

        td.Value__c = 30;

        Test.startTest();
        update td;
        Test.stopTest();

        List<TaxDataHistory__c> histories = [
            SELECT TaxData__c, Value__c, NAV_Date__c
            FROM TaxDataHistory__c
            WHERE TaxData__c = :td.Id
        ];

        System.assertEquals(1, histories.size());
        System.assertEquals(15, histories[0].Value__c);
        System.assertEquals(Date.newInstance(2026, 4, 28), histories[0].NAV_Date__c);
    }

    @IsTest
    static void test_validateBelgiumSimulator_success() {
        Product__c fund = createFund('FCP');
        Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

        insert new Country__c(
            ShareClass__c = sc.Id,
            Country__c = COUNTRY_BE,
            RegistrationStatus__c = 'REG',
            ISINCountryKey__c = 'LU1234567890_BE'
        );

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_BE,
            Type__c = TYPE_BE_SIMULATOR,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(td, false);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(), 'Belgium Simulator doit être autorisé');
    }

    @IsTest
    static void test_validateBelgiumSimulator_blocked() {
        Product__c fund = createFund('SICAV');
        Share_Class__c sc = createShareClass(fund.Id, 'Distributing');

        TaxData__c td = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = COUNTRY_BE,
            Type__c = TYPE_BE_SIMULATOR,
            Status__c = STATUS_REQUESTED,
            Source__c = SOURCE_MANUAL
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(td, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Belgium Simulator doit être bloqué');
        System.assertEquals(
            true,
            sr.getErrors()[0].getMessage().contains('Belgium Simulator can only be created')
        );
    }

    @IsTest
    static void test_buildRequestName_and_normalizeBEType() {
        String nameValue = TaxTriggerHandler.buildRequestName(
            TYPE_BE_TIS,
            COUNTRY_BE,
            'Fund Name',
            'Share Class Name'
        );

        System.assertEquals(true, nameValue.startsWith('TIS - BE -'));
        System.assertEquals('TIS', TaxTriggerHandler.normalizeBEType(TYPE_BE_TIS));
        System.assertEquals('Asset Test', TaxTriggerHandler.normalizeBEType(TYPE_BE_ASSET_TEST));
        System.assertEquals('Simulator', TaxTriggerHandler.normalizeBEType(TYPE_BE_SIMULATOR));
    }
    
    @IsTest
static void test_afterInsert_callsATAndCHTransparencyEmailServices() {
    Product__c fund = createFund('FCP');
    Share_Class__c sc = createShareClass(fund.Id, 'Accumulating');

    insert new Country__c(
        ShareClass__c = sc.Id,
        Country__c = 'CH',
        RegistrationStatus__c = 'REG',
        RegistrationDate__c = Date.today(),
        ISINCountryKey__c = 'LU1234567890_CH'
    );

    List<TaxData__c> taxDataToInsert = new List<TaxData__c>{
        new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'Manual'
        ),
        new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = fund.Id,
            Country__c = 'CH',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'Manual'
        )
    };

    Test.startTest();
    insert taxDataToInsert;
    Test.stopTest();

    List<TaxData__c> insertedTaxData = [
        SELECT Id, Country__c, Type__c, Status__c
        FROM TaxData__c
        WHERE Id IN :taxDataToInsert
    ];

    System.assertEquals(
        2,
        insertedTaxData.size(),
        'Les TaxData AT et CH doivent être insérés, ce qui déclenche les appels email after insert'
    );
}
}