/** ──────────────────────────────────────
 * @description Tests of PRIIPSKidController.getPriipsKidData: Product Creation fields with display conditions and required flags, and
 *                  the Modification mode limited to the selected fields. In memory only: the controller overrides replace the org data.
 * @author EL HITARY Achraf
 * @covers PRIIPSKidController   79%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class PRIIPSKidControllerTest {

    @isTest
    static void test_getPriipsKidData() {
        // Product Creation: conditional fields (MaxPerfFees ignored when HasPerfFees__c is False) and required metadata
        Id productId = fakeId('ProjectProduct__c', 1);
        SObject productRecord = newSObject('ProjectProduct__c', productId);
        putValue(productRecord, 'ProductName__c', 'Test Fund');
        putValue(productRecord, 'LegalForm__c', 'FCP');
        putValue(productRecord, 'MaturityDate__c', null);
        putValue(productRecord, 'HasBenchmark__c', 'False');
        SObject shareclassRecord = newSObject('ProjectShareclass__c', fakeId('ProjectShareclass__c', 1));
        putValue(shareclassRecord, 'Name__c', 'A EUR Acc');
        putValue(shareclassRecord, 'Currency__c', 'EUR');
        putValue(shareclassRecord, 'HasPerfFees__c', 'False');
        putValue(shareclassRecord, 'MaxPerfFees__c', 20);
        setProject(productId, 'FundCreation', productRecord, shareclassRecord, new List<PRIIPSField__mdt>{
            newMetadata('ProductName', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, null, true),
            newMetadata('RecommendedHoldingPeriod', 'Recommended Holding Period', 'ProjectProduct__c.RecommendedHoldingPeriod__c', 'Product Strategy', true, false, true, 'ProjectProduct__c.LegalForm__c!=\'OEIC\' && ISBLANK(ProjectProduct__c.MaturityDate__c)', false),
            newMetadata('Currency', 'Currency', 'ProjectShareclass__c.Currency__c', 'Product Strategy', true, true, true, null, false),
            newMetadata('MaxPerfFees', 'Max Performance Fees', 'ProjectShareclass__c.MaxPerfFees__c', 'Product Strategy', true, true, true, 'ProjectShareclass__c.HasPerfFees__c=\'True\'', true)
        });

        Test.startTest();

        PRIIPSKidController.PriipsKidResponse response = PRIIPSKidController.getPriipsKidData(productId);
        System.assertEquals('Product Creation', response.projectMode);
        System.assertEquals(1, response.productTeams.size());
        System.assert(response.productTeams[0].fields[0].required);
        System.assertEquals(1, response.shareclasses.size());
        System.assertEquals(1, response.shareclasses[0].teams[0].fields.size(), 'MaxPerfFees is conditional and must be ignored when HasPerfFees__c is False.');

        // Modification: only the selected fields
        Id modifiedProductId = fakeId('ProjectProduct__c', 2);
        SObject modifiedProduct = newSObject('ProjectProduct__c', modifiedProductId);
        putValue(modifiedProduct, 'ProductName__c', 'Modified Fund');
        putValue(modifiedProduct, 'CutOffTime__c', '13:00 CET');
        putValue(modifiedProduct, 'TECH_FieldsToModify__c', 'ProductName__c');
        SObject modifiedShareclass = newSObject('ProjectShareclass__c', fakeId('ProjectShareclass__c', 2));
        putValue(modifiedShareclass, 'Name__c', 'B EUR Acc');
        putValue(modifiedShareclass, 'Currency__c', 'EUR');
        putValue(modifiedShareclass, 'DividendPolicy__c', 'Accumulating');
        putValue(modifiedShareclass, 'TECH_FieldsToModify__c', 'Currency__c');
        setProject(modifiedProductId, 'FundShareClassModification', modifiedProduct, modifiedShareclass, new List<PRIIPSField__mdt>{
            newMetadata('ProductName', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, null, false),
            newMetadata('CutOffTime', 'Cut Off Time', 'ProjectProduct__c.CutOffTime__c', 'Product Strategy', true, false, true, null, false),
            newMetadata('Currency', 'Currency', 'ProjectShareclass__c.Currency__c', 'Product Strategy', true, true, true, null, false),
            newMetadata('DividendPolicy', 'Dividend Policy', 'ProjectShareclass__c.DividendPolicy__c', 'Product Strategy', true, true, true, null, false)
        });
        response = PRIIPSKidController.getPriipsKidData(modifiedProductId);

        Test.stopTest();

        System.assertEquals('Modification', response.projectMode);
        System.assertEquals(1, response.productTeams[0].fields.size(), 'Only ProductName__c is selected for modification.');
        System.assertEquals('Product Name', response.productTeams[0].fields[0].label);
        System.assertEquals(1, response.shareclasses[0].teams[0].fields.size(), 'Only Currency__c is selected for modification.');
        System.assertEquals('Currency', response.shareclasses[0].teams[0].fields[0].label);

        PRIIPSKidController.resetOverridesForTest();
    }

    // Overrides of a project scenario (PS scope) with one share class
    private static void setProject(Id productId, String recordTypeDeveloperName, SObject productRecord, SObject shareclassRecord, List<PRIIPSField__mdt> rows) {
        PRIIPSKidController.resetOverridesForTest();
        PRIIPSKidController.productIdOverride = productId;
        PRIIPSKidController.recordTypeDeveloperNameOverride = recordTypeDeveloperName;
        PRIIPSKidController.projectScopeOverride = 'PS';
        PRIIPSKidController.productRecordOverride = productRecord;
        PRIIPSKidController.shareclassRecordsOverride = new List<SObject>{ shareclassRecord };
        PRIIPSKidController.metadataRowsOverride = rows;
    }

    // Creates an in-memory Custom Metadata row for controller tests.
    private static PRIIPSField__mdt newMetadata(String developerName, String label, String fieldApiName, String team, Boolean productCreation, Boolean shareclassCreation, Boolean modification, String displayCondition, Boolean required) {
        PRIIPSField__mdt metadataRow = new PRIIPSField__mdt();
        metadataRow.DeveloperName = developerName;
        metadataRow.MasterLabel = label;
        metadataRow.FieldApiName__c = fieldApiName;
        metadataRow.Team__c = team;
        metadataRow.ProductCreation__c = productCreation;
        metadataRow.ShareclassCreation__c = shareclassCreation;
        metadataRow.ProductShareModification__c = modification;
        metadataRow.DisplayCondition__c = displayCondition;
        metadataRow.Required__c = required;
        return metadataRow;
    }

    // Creates a fake Id with the correct object prefix.
    private static Id fakeId(String objectApiName, Integer suffix) {
        String prefix = Schema.getGlobalDescribe().get(objectApiName).getDescribe().getKeyPrefix();
        String numberValue = String.valueOf(suffix).leftPad(12, '0');
        return (Id) (prefix + numberValue);
    }

    // Creates a dynamic SObject with a known Id.
    private static SObject newSObject(String objectApiName, Id recordId) {
        return Schema.getGlobalDescribe().get(objectApiName).newSObject(recordId);
    }

    // Sets a field value only when the field exists in the current org.
    private static void putValue(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) record.put(fieldApiName, value);
    }
}