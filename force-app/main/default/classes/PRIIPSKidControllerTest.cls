@IsTest
private class PRIIPSKidControllerTest {
    // Covers product/shareclass rendering with conditions and required metadata.
    @IsTest
    static void getPriipsKidDataFiltersConditionalFields() {
        Id productId = fakeId('ProjectProduct__c', 1);
        Id shareclassId = fakeId('ProjectShareclass__c', 1);

        SObject productRecord = newSObject('ProjectProduct__c', productId);
        putValue(productRecord, 'ProductName__c', 'Test Fund');
        putValue(productRecord, 'LegalForm__c', 'FCP');
        putValue(productRecord, 'MaturityDate__c', null);
        putValue(productRecord, 'HasBenchmark__c', 'False');

        SObject shareclassRecord = newSObject('ProjectShareclass__c', shareclassId);
        putValue(shareclassRecord, 'Name__c', 'A EUR Acc');
        putValue(shareclassRecord, 'Currency__c', 'EUR');
        putValue(shareclassRecord, 'HasPerfFees__c', 'False');
        putValue(shareclassRecord, 'MaxPerfFees__c', 20);

        PRIIPSKidController.productIdOverride = productId;
        PRIIPSKidController.recordTypeDeveloperNameOverride = 'FundCreation';
        PRIIPSKidController.productRecordOverride = productRecord;
        PRIIPSKidController.shareclassRecordsOverride = new List<SObject>{ shareclassRecord };
        PRIIPSKidController.metadataRowsOverride = new List<PRIIPSField__mdt>{
            newMetadata('ProductName', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, null, true),
            newMetadata('RecommendedHoldingPeriod', 'Recommended Holding Period', 'ProjectProduct__c.RecommendedHoldingPeriod__c', 'Product Strategy', true, false, true, 'ProjectProduct__c.LegalForm__c!=\'OEIC\' && ISBLANK(ProjectProduct__c.MaturityDate__c)', false),
            newMetadata('Currency', 'Currency', 'ProjectShareclass__c.Currency__c', 'Product Strategy', true, true, true, null, false),
            newMetadata('MaxPerfFees', 'Max Performance Fees', 'ProjectShareclass__c.MaxPerfFees__c', 'Product Strategy', true, true, true, 'ProjectShareclass__c.HasPerfFees__c=\'True\'', true)
        };

        Test.startTest();
        PRIIPSKidController.PriipsKidResponse response = PRIIPSKidController.getPriipsKidData(productId);
        Test.stopTest();

        System.assertEquals('Product Creation', response.projectMode);
        System.assertEquals(1, response.productTeams.size());
        System.assertEquals(true, response.productTeams[0].fields[0].required);
        System.assertEquals(1, response.shareclasses.size());
        System.assertEquals(1, response.shareclasses[0].teams[0].fields.size(), 'MaxPerfFees is conditional and must be ignored when HasPerfFees__c is False.');

        PRIIPSKidController.resetOverridesForTest();
    }

    // Covers modification mode selected-field filtering.
    @IsTest
    static void getPriipsKidDataUsesSelectedFieldsForModification() {
        Id productId = fakeId('ProjectProduct__c', 2);
        Id shareclassId = fakeId('ProjectShareclass__c', 2);

        SObject productRecord = newSObject('ProjectProduct__c', productId);
        putValue(productRecord, 'ProductName__c', 'Modified Fund');
        putValue(productRecord, 'CutOffTime__c', '13:00 CET');
        putValue(productRecord, 'TECH_FieldsToModify__c', 'ProductName__c');

        SObject shareclassRecord = newSObject('ProjectShareclass__c', shareclassId);
        putValue(shareclassRecord, 'Name__c', 'B EUR Acc');
        putValue(shareclassRecord, 'Currency__c', 'EUR');
        putValue(shareclassRecord, 'DividendPolicy__c', 'Accumulating');
        putValue(shareclassRecord, 'TECH_FieldsToModify__c', 'Currency__c');

        PRIIPSKidController.productIdOverride = productId;
        PRIIPSKidController.recordTypeDeveloperNameOverride = 'FundShareClassModification';
        PRIIPSKidController.productRecordOverride = productRecord;
        PRIIPSKidController.shareclassRecordsOverride = new List<SObject>{ shareclassRecord };
        PRIIPSKidController.metadataRowsOverride = new List<PRIIPSField__mdt>{
            newMetadata('ProductName', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, null, false),
            newMetadata('CutOffTime', 'Cut Off Time', 'ProjectProduct__c.CutOffTime__c', 'Product Strategy', true, false, true, null, false),
            newMetadata('Currency', 'Currency', 'ProjectShareclass__c.Currency__c', 'Product Strategy', true, true, true, null, false),
            newMetadata('DividendPolicy', 'Dividend Policy', 'ProjectShareclass__c.DividendPolicy__c', 'Product Strategy', true, true, true, null, false)
        };

        Test.startTest();
        PRIIPSKidController.PriipsKidResponse response = PRIIPSKidController.getPriipsKidData(productId);
        Test.stopTest();

        System.assertEquals('Modification', response.projectMode);
        System.assertEquals(1, response.productTeams[0].fields.size(), 'Only ProductName__c is selected for modification.');
        System.assertEquals('Product Name', response.productTeams[0].fields[0].label);
        System.assertEquals(1, response.shareclasses[0].teams[0].fields.size(), 'Only Currency__c is selected for modification.');
        System.assertEquals('Currency', response.shareclasses[0].teams[0].fields[0].label);

        PRIIPSKidController.resetOverridesForTest();
    }

    // Creates an in-memory Custom Metadata row for controller tests.
    private static PRIIPSField__mdt newMetadata(
        String developerName,
        String label,
        String fieldApiName,
        String team,
        Boolean productCreation,
        Boolean shareclassCreation,
        Boolean modification,
        String displayCondition,
        Boolean required
    ) {
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
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }
}