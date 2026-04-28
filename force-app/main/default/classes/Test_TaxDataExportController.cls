@IsTest
private class Test_TaxDataExportController {

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName()
        .get('Fund')
        .getRecordTypeId();

    private static Share_Class__c createShareClass() {
        Product__c fund = PMTTestFactoryData.getProduct(
            fundRecordTypeId,
            'BETISFundCode',
            'BE TIS Fund',
            true
        );

        Share_Class__c sc = new Share_Class__c(
            Name = 'BE TIS Fund',
            Fund__c = fund.Id,
            Validity__c = true,
            ISIN__c = 'LU1234567890'
        );
        insert sc;

        return sc;
    }

    @IsTest
    static void test_exportBETISHistory_success() {
        Share_Class__c sc = createShareClass();

        TaxData__c taxData = new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = sc.Fund__c,
            Country__c = 'BE',
            Type__c = 'BE TIS',
            Status__c = 'Yes',
            Source__c = 'Manual'
        );
        insert taxData;

        TaxDataHistory__c history = new TaxDataHistory__c(
            TaxData__c = taxData.Id,
            NAV_Date__c = Date.newInstance(2026, 4, 28),
            Value__c = 12.34
        );
        insert history;

        Test.startTest();
        TaxDataExportController.ExportResult result =
            TaxDataExportController.exportBETISHistory(sc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Un résultat doit être retourné');
        System.assertEquals('BE_TIS_BE TIS Fund.xls', result.fileName);

        System.assertEquals(true, result.content.contains('<table>'));
        System.assertEquals(true, result.content.contains('LU1234567890'));
        System.assertEquals(true, result.content.contains('BE TIS Fund'));
        System.assertEquals(true, result.content.contains('2026-04-28'));
        System.assertEquals(true, result.content.contains('12.34'));
    }

    @IsTest
    static void test_exportBETISHistory_missingShareClassId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TaxDataExportController.exportBETISHistory(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'AuraHandledException');
    }

    @IsTest
    static void test_exportBETISHistory_noBETISData() {
        Share_Class__c sc = createShareClass();

        insert new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = sc.Fund__c,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Yes',
            Source__c = 'Manual'
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            TaxDataExportController.exportBETISHistory(sc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException'
        );
    }

    @IsTest
    static void test_exportBETISHistory_emptyHistoryStillExports() {
        Share_Class__c sc = createShareClass();

        insert new TaxData__c(
            ShareClass__c = sc.Id,
            Product__c = sc.Fund__c,
            Country__c = 'BE',
            Type__c = 'BE TIS',
            Status__c = 'Yes',
            Source__c = 'Manual'
        );

        Test.startTest();
        TaxDataExportController.ExportResult result =
            TaxDataExportController.exportBETISHistory(sc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('BE_TIS_BE TIS Fund.xls', result.fileName);
        System.assertEquals(true, result.content.contains('<th>ISIN</th>'));
        System.assertEquals(true, result.content.contains('<th>Share Class</th>'));
        System.assertEquals(true, result.content.contains('<th>Nav Date</th>'));
        System.assertEquals(true, result.content.contains('<th>BE TIS Value</th>'));
    }
}