/** ──────────────────────────────────────
 * @description Tests of RecordCloneHelper: fields of a project cloned onto another (single and batch versions), the error raised for
 *                  a missing source, and the list of the fields of an object.
 * @covers RecordCloneHelper   92%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_RecordCloneHelper {

    @isTest
    static void test_cloneRecordFields() {
        Id recordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c source = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
        ProjectProduct__c target = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);

        String cloneError;
        String batchCloneError;

        Test.startTest();

        SObject cloned = RecordCloneHelper.cloneRecordFields(source, target);
        SObject batchCloned = RecordCloneHelper.batchCloneRecordFields(source, target);
        String fieldNames = RecordCloneHelper.getAllFieldNames('ProjectProduct__c');
        try {
            RecordCloneHelper.cloneRecordFields(null, new ProjectProduct__c());
        }
        catch (Exception e) {
            cloneError = e.getMessage();
        }
        try {
            RecordCloneHelper.batchCloneRecordFields(null, new ProjectProduct__c());
        }
        catch (Exception e) {
            batchCloneError = e.getMessage();
        }

        Test.stopTest();

        System.assertNotEquals(null, cloned);
        System.assertNotEquals(null, batchCloned);
        System.assert(String.isNotBlank(fieldNames), 'Fields of the object');
        System.assert(cloneError != null && cloneError.contains('Source record is null'), 'cloneRecordFields: source record is null');
        System.assert(batchCloneError != null && batchCloneError.contains('Source record is null'), 'batchCloneRecordFields: source record is null');
    }
}