/** ──────────────────────────────────────
 * @description Tests of the fieldSelector LWC controller: reading the selectable, dependent and selected fields (Project Product, Project Share Class, Share Class child), saving the selection, and the save error returned to the LWC.
 * @covers FieldSelectorController   99%   [12-10-26]
 * @lastModifiedBy Charles EID   [12-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_FieldSelectorController {

    @testSetup
    static void setup() {
        Id prodRT = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(prodRT);
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;UnknownField__c');
    }

    @isTest
    static void test_getFields() {
        ProjectProduct__c proj = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        ProjectShareclass__c shc = [SELECT Id FROM ProjectShareclass__c LIMIT 1];
        ProjectShareclassChild__c shcChild = [SELECT Id FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :shc.Id LIMIT 1];

        Test.startTest();

        List<Map<String, String>> productDependentFields = FieldSelectorController.getDependentFields('Product__c');
        FieldSelectorController.getDependentFields('Parent_Share_Class__c');
        List<Map<String, String>> shareClassFields = FieldSelectorController.getMetadataFields('Parent_Share_Class__c');
        List<Map<String, String>> productSelectedFields = FieldSelectorController.getSelectedFields(proj.Id, 'Product__c');
        List<Map<String, String>> shcSelectedFields = FieldSelectorController.getSelectedFields(shc.Id, 'Parent_Share_Class__c');
        List<Map<String, String>> shcChildSelectedFields = FieldSelectorController.getSelectedFields(shcChild.Id, 'Share_Class__c');

        Test.stopTest();

        System.assertNotEquals(0, productDependentFields.size());
        System.assertNotEquals(0, shareClassFields.size());
        System.assertEquals(0, productSelectedFields.size(), 'No field selected yet on the Project Product');
        System.assertEquals(1, shcSelectedFields.size(), 'UnknownField__c does not exist on Share_Class__c and must be skipped');
        System.assertEquals('CurrencyIsoCode', shcSelectedFields[0].get('value'));
        System.assertEquals(shcSelectedFields, shcChildSelectedFields, 'The child reads the selection of its parent Project Share Class');
    }

    @isTest
    static void test_updateSelectedFields() {
        ProjectProduct__c proj = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        ProjectShareclass__c shc = [SELECT Id FROM ProjectShareclass__c LIMIT 1];
        ProjectShareclassChild__c shcChild = [SELECT Id FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :shc.Id LIMIT 1];
        Id unknownId = ProjectProduct__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        String errorMessage;

        Test.startTest();

        FieldSelectorController.updateSelectedFields(proj.Id, new List<String>{'Name'}, 'ProjectProduct__c');
        FieldSelectorController.updateSelectedFields(shc.Id, new List<String>{'CurrencyIsoCode'}, 'Parent_Share_Class__c');
        String shcFieldsFromParent = [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :shc.Id].TECH_FieldsToModify__c;
        FieldSelectorController.updateSelectedFields(shcChild.Id, new List<String>{'DividendPolicy__c'}, 'Share_Class__c');

        // FIX-20269: une erreur DML remonte au LWC en AuraHandledException (ici, un Id qui n'existe pas)
        try {
            FieldSelectorController.updateSelectedFields(unknownId, new List<String>{'Name'}, 'ProjectProduct__c');
        }
        catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }

        Test.stopTest();

        System.assertEquals('Name', [SELECT TECH_FieldsToModify__c FROM ProjectProduct__c WHERE Id = :proj.Id].TECH_FieldsToModify__c);
        System.assertEquals('CurrencyIsoCode', shcFieldsFromParent);
        System.assertEquals('DividendPolicy__c', [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :shc.Id].TECH_FieldsToModify__c, 'Saving from the child updates its parent Project Share Class');
        System.assertNotEquals(null, errorMessage, 'A DML error must reach the LWC as an AuraHandledException');
    }
}