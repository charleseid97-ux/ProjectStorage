@IsTest
private class ReferentialProductExportCtrlTest {

    /**
     * Creates the Product Catalog records required by the export tests.
     */
    @TestSetup
    static void setupData() {
        Strategy__c strategy = new Strategy__c(
            Name = 'UT Export Strategy',
            Code__c = 'UTEXP',
            AssetClass__c = 'Equity'
        );
        insert strategy;

        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByDeveloperName()
            .get('Fund')
            .getRecordTypeId();

        Product__c fund = new Product__c(
            Name = 'UT Export Fund',
            ProductName__c = 'UT Export Fund',
            InternalShortName__c = 'UTEF',
            RecordTypeId = fundRecordTypeId,
            VehicleType__c = 'Funds',
            Tech_NotDisplayedProductCatalog__c = false,
            FundStrategy__c = strategy.Id
        );
        insert fund;

        Share_Class__c shareClassRecord = new Share_Class__c(
            Name = 'UT Export Share Class',
            Fund__c = fund.Id,
            ISIN__c = 'UT0000000001',
            Status__c = 'Active'
        );
        insert shareClassRecord;
    }

    /**
     * Verifies that an active Share Class is returned by the export.
     */
    @IsTest
    static void getExportRowsReturnsMatchingShareClass() {
        Test.startTest();
        List<ReferentialProductExportCtrl.ExportRow> rows =
            ReferentialProductExportCtrl.getExportRows(
                'All countries',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                true,
                null
            );
        Test.stopTest();

        System.assertEquals(1, rows.size());
        Share_Class__c expectedShareClass = [
            SELECT Name
            FROM Share_Class__c
            WHERE ISIN__c = 'UT0000000001'
            LIMIT 1
        ];

        System.assertEquals('UT0000000001', String.valueOf(rows[0].isin));
        System.assertEquals('UT Export Fund', String.valueOf(rows[0].fund));
        System.assertEquals('UTEF', String.valueOf(rows[0].internalShortName));
        System.assertEquals(expectedShareClass.Name, String.valueOf(rows[0].shareClassName));
    }

    /**
     * Verifies that the text search returns the expected Share Class by ISIN.
     */
    @IsTest
    static void getExportRowsFiltersBySearch() {
        Test.startTest();
        List<ReferentialProductExportCtrl.ExportRow> rows =
            ReferentialProductExportCtrl.getExportRows(
                'All countries',
                null,
                null,
                null,
                null,
                null,
                null,
                'UT0000000001',
                true,
                null
            );
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('UT0000000001', String.valueOf(rows[0].isin));
    }

    /**
     * Verifies that a search with no matching Product or Share Class returns no rows.
     */
    @IsTest
    static void getExportRowsReturnsNoResult() {
        Test.startTest();
        List<ReferentialProductExportCtrl.ExportRow> rows =
            ReferentialProductExportCtrl.getExportRows(
                'All countries',
                null,
                null,
                null,
                null,
                null,
                null,
                'NO_MATCH_EXPECTED_999',
                true,
                null
            );
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }
}