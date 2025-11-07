@isTest
public class Test_ExportProjectDataController {
    
	private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
 
    @IsTest
    static void test_getProjectDataToExport() {

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(proj.Id, 'DividendFrequency__c;Type__c;DividendPolicy__c;InvestmentStatusInvestors__c');
        Test.startTest();
        List<Map<String, String>> data = ExportProjectDataController.getProjectDataToExport(proj.Id);
        Test.stopTest();
        system.assertNotEquals(0, data.size());
    }
}