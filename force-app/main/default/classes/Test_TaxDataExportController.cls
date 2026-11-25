/** ──────────────────────────────────────
 * @description Tests of TaxDataExportController.exportBETISHistory: export of the BE TIS history of a share class (with and without
 *                  history rows), and the handled errors (no share class Id, no BE TIS request).
 * @author Khadija
 * @covers TaxDataExportController   96%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_TaxDataExportController {

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();

    @isTest
    static void test_exportBETISHistory() {
        Product__c fund = PMTTestFactoryData.getProduct(fundRecordTypeId, 'BETISFundCode', 'BE TIS Fund', true);
        Share_Class__c withHistory = createShareClass(fund.Id, 'BE TIS Fund', 'LU1234567890');
        Share_Class__c withoutHistory = createShareClass(fund.Id, 'BE TIS Empty', 'LU1234567891');
        Share_Class__c withoutBeTis = createShareClass(fund.Id, 'AT Only', 'LU1234567892');
        TaxData__c beTis = newTaxData(withHistory, 'BE', 'BE TIS');
        insert new List<TaxData__c>{ beTis, newTaxData(withoutHistory, 'BE', 'BE TIS'), newTaxData(withoutBeTis, 'AT', 'Transparency') };
        insert new TaxDataHistory__c(TaxData__c = beTis.Id, NAV_Date__c = Date.newInstance(2026, 4, 28), Value__c = 12.34);

        Test.startTest();

        TaxDataExportController.ExportResult result = TaxDataExportController.exportBETISHistory(withHistory.Id);
        TaxDataExportController.ExportResult emptyResult = TaxDataExportController.exportBETISHistory(withoutHistory.Id);
        Boolean missingIdRejected = throwsHandledException(null);
        Boolean noBeTisRejected = throwsHandledException(withoutBeTis.Id);

        Test.stopTest();

        System.assertEquals('BE_TIS_BE TIS Fund.xls', result.fileName);
        System.assert(result.content.contains('<table>'));
        System.assert(result.content.contains('LU1234567890'));
        System.assert(result.content.contains('BE TIS Fund'));
        System.assert(result.content.contains('2026-04-28'));
        System.assert(result.content.contains('12.34'));

        System.assertEquals('BE_TIS_BE TIS Empty.xls', emptyResult.fileName, 'Exported without history rows');
        System.assert(emptyResult.content.contains('<th>ISIN</th>'));
        System.assert(emptyResult.content.contains('<th>Share Class</th>'));
        System.assert(emptyResult.content.contains('<th>Nav Date</th>'));
        System.assert(emptyResult.content.contains('<th>BE TIS Value</th>'));

        System.assert(missingIdRejected, 'AuraHandledException without share class Id');
        System.assert(noBeTisRejected, 'AuraHandledException without BE TIS request');
    }

    private static Share_Class__c createShareClass(Id fundId, String name, String isin) {
        Share_Class__c sc = new Share_Class__c(Name = name, Fund__c = fundId, Validity__c = true, ISIN__c = isin);
        insert sc;
        return sc;
    }

    private static TaxData__c newTaxData(Share_Class__c sc, String country, String type) {
        return new TaxData__c(ShareClass__c = sc.Id, Product__c = sc.Fund__c, Country__c = country, Type__c = type, Status__c = 'Yes', Source__c = 'Manual');
    }

    private static Boolean throwsHandledException(Id shareClassId) {
        try {
            TaxDataExportController.exportBETISHistory(shareClassId);
        }
        catch (AuraHandledException e) {
            return true;
        }
        return false;
    }
}