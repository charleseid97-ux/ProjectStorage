@IsTest
private class PRIIPSKidCompletionControllerTest {
    // Resets controller overrides after each test scenario.
    private static void reset() {
        PRIIPSKidCompletionController.resetOverridesForTest();
    }

    // Creates a fake Salesforce Id with the right object prefix.
    private static Id fakeId(Schema.SObjectType objectType, Integer index) {
        String prefix = objectType.getDescribe().getKeyPrefix();
        String suffix = String.valueOf(index).leftPad(12, '0');
        return Id.valueOf(prefix + suffix);
    }

    // Creates one Custom Metadata row used by the completion engine.
    private static PRIIPSField__mdt newMetadata(
        String developerName,
        String label,
        String fieldApiName,
        String team,
        Boolean productCreation,
        Boolean shareclassCreation,
        Boolean modification
    ) {
        PRIIPSField__mdt metadataRow = new PRIIPSField__mdt();
        metadataRow.DeveloperName = developerName;
        metadataRow.MasterLabel = label;
        metadataRow.FieldApiName__c = fieldApiName;
        metadataRow.Team__c = team;
        metadataRow.ProductCreation__c = productCreation;
        metadataRow.ShareclassCreation__c = shareclassCreation;
        metadataRow.ProductShareModification__c = modification;
        return metadataRow;
    }

    // Creates a Project Product SObject without inserting org data.
    private static SObject newProduct(String productName, String legalForm, String selectedFields) {
        SObject productRecord = Schema.getGlobalDescribe().get('ProjectProduct__c').newSObject();
        productRecord.put('Id', fakeId(ProjectProduct__c.SObjectType, 1));
        productRecord.put('ProductName__c', productName);
        productRecord.put('LegalForm__c', legalForm);
        productRecord.put('TECH_FieldsToModify__c', selectedFields);
        return productRecord;
    }

    // Creates a Project Shareclass SObject without inserting org data.
    private static SObject newShareclass(Integer index, String nameValue, String currencyValue, Object transactionCosts, String selectedFields) {
        SObject shareclassRecord = Schema.getGlobalDescribe().get('ProjectShareclass__c').newSObject();
        shareclassRecord.put('Id', fakeId(ProjectShareclass__c.SObjectType, index));
        shareclassRecord.put('Name', 'SC - ' + String.valueOf(index));
        shareclassRecord.put('Name__c', nameValue);
        shareclassRecord.put('Currency__c', currencyValue);
        shareclassRecord.put('TransactionCosts__c', transactionCosts);
        shareclassRecord.put('TECH_FieldsToModify__c', selectedFields);
        return shareclassRecord;
    }

    // Returns a small metadata set covering product and shareclass completion.
    private static List<PRIIPSField__mdt> metadataRows() {
        return new List<PRIIPSField__mdt>{
            newMetadata('ProductName', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true),
            newMetadata('LegalForm', 'Legal Form', 'ProjectProduct__c.LegalForm__c', 'Legal', true, false, true),
            newMetadata('Currency', 'Currency', 'ProjectShareclass__c.Currency__c', 'Product Strategy', true, true, true),
            newMetadata('TransactionCosts', 'Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Investment Performance', true, true, true)
        };
    }

    // Verifies combined team completion for a Product Creation project.
    @IsTest
    static void getCompletionData_productCreation_combinesProductAndShareclass() {
        reset();
        PRIIPSKidCompletionController.productIdOverride = fakeId(ProjectProduct__c.SObjectType, 1);
        PRIIPSKidCompletionController.recordTypeDeveloperNameOverride = 'FundCreation';
        PRIIPSKidCompletionController.metadataRowsOverride = metadataRows();
        PRIIPSKidCompletionController.productRecordOverride = newProduct('Carmignac Credit 2027', null, null);
        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{
            newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null),
            newShareclass(2, 'A USD Acc', null, null, null)
        };

        Test.startTest();
        PRIIPSKidCompletionController.CompletionResponse response = PRIIPSKidCompletionController.getCompletionData(null);
        Test.stopTest();

        System.assertEquals('Product Creation', response.projectMode);
        System.assertEquals(3, response.teams.size(), 'Three teams should have completion indicators.');
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(2, response.teams[0].completed);
        System.assertEquals(3, response.teams[0].total);
        System.assertEquals(67, response.teams[0].percentage);
        reset();
    }

    // Verifies that modification projects count only selected fields from TECH_FieldsToModify__c.
    @IsTest
    static void getCompletionData_modification_usesSelectedFieldsOnly() {
        reset();
        PRIIPSKidCompletionController.productIdOverride = fakeId(ProjectProduct__c.SObjectType, 1);
        PRIIPSKidCompletionController.recordTypeDeveloperNameOverride = 'FundShareClassModification';
        PRIIPSKidCompletionController.metadataRowsOverride = metadataRows();
        PRIIPSKidCompletionController.productRecordOverride = newProduct('Carmignac Credit 2027', 'FCP', 'ProjectProduct__c.ProductName__c');
        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{
            newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), 'Currency__c'),
            newShareclass(2, 'A USD Acc', 'USD', null, 'ProjectShareclass__c.TransactionCosts__c')
        };

        Test.startTest();
        PRIIPSKidCompletionController.CompletionResponse response = PRIIPSKidCompletionController.getCompletionData(null);
        Test.stopTest();

        System.assertEquals('Modification', response.projectMode);
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(2, response.teams[0].completed);
        System.assertEquals(2, response.teams[0].total);
        System.assertEquals('Investment Performance', response.teams[1].name);
        System.assertEquals(0, response.teams[1].completed);
        System.assertEquals(1, response.teams[1].total);
        reset();
    }

    // Verifies parsing of local and object-qualified modified field names.
    @IsTest
    static void parseModifiedFields_returnsLocalAndQualifiedNames() {
        Set<String> fields = PRIIPSKidCompletionController.parseModifiedFields(
            'Currency__c;ProjectShareclass__c.TransactionCosts__c',
            'ProjectShareclass__c'
        );

        System.assert(fields.contains('Currency__c'));
        System.assert(fields.contains('ProjectShareclass__c.Currency__c'));
        System.assert(fields.contains('TransactionCosts__c'));
        System.assert(fields.contains('ProjectShareclass__c.TransactionCosts__c'));
    }
}
