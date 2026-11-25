/** ──────────────────────────────────────
 * @description Tests of ExportProjectDataController.getProjectDataToExport: export data of a Fund creation project with a share class.
 * @covers ExportProjectDataController   95%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ExportProjectDataController {

    @isTest
    static void test_getProjectDataToExport() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'DividendFrequency__c;Type__c;DividendPolicy__c;InvestmentStatusInvestors__c');

        Test.startTest();

        List<Map<String, String>> data = ExportProjectDataController.getProjectDataToExport(proj.Id);

        Test.stopTest();

        System.assertNotEquals(0, data.size(), 'Data of the project to export');
    }
}