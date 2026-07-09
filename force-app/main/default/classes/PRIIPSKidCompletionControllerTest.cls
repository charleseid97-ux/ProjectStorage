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

        // The controller counts only mandatory PRIIPs fields.
        metadataRow.Required__c = true;
        return metadataRow;
    }

        // Creates one Custom Metadata row with condition and exact-value rules.
    private static PRIIPSField__mdt newMetadataWithCondition(
        String developerName,
        String label,
        String fieldApiName,
        String team,
        Boolean productCreation,
        Boolean shareclassCreation,
        Boolean modification,
        String displayCondition,
        String exactValue
    ) {
        PRIIPSField__mdt metadataRow = newMetadata(
            developerName,
            label,
            fieldApiName,
            team,
            productCreation,
            shareclassCreation,
            modification
        );

        // These fields cover conditional display and exact completion logic.
        metadataRow.DisplayCondition__c = displayCondition;
        metadataRow.ExactValue__c = exactValue;
        return metadataRow;
    }

    // Creates one Custom Metadata row with a DisplayCondition__c expression.
    private static PRIIPSField__mdt newMetadataWithCondition(
        String developerName,
        String label,
        String fieldApiName,
        String team,
        Boolean productCreation,
        Boolean shareclassCreation,
        Boolean modification,
        String displayCondition
    ) {
        PRIIPSField__mdt metadataRow = newMetadata(
            developerName,
            label,
            fieldApiName,
            team,
            productCreation,
            shareclassCreation,
            modification
        );

        // DisplayCondition__c drives the private condition evaluator coverage.
        metadataRow.DisplayCondition__c = displayCondition;
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

        // Verifies DisplayCondition__c parsing through the public completion API.
    @IsTest
    static void getCompletionData_productCreation_appliesDisplayConditions() {
        reset();
        PRIIPSKidCompletionController.productIdOverride = fakeId(ProjectProduct__c.SObjectType, 1);
        PRIIPSKidCompletionController.recordTypeDeveloperNameOverride = 'FundCreation';
        PRIIPSKidCompletionController.productRecordOverride = newProduct('Carmignac Credit 2027', 'FCP', null);

        // Conditions cover &&, ||, =, !=, ISBLANK(), !ISBLANK() and invalid tokens.
        PRIIPSKidCompletionController.metadataRowsOverride = new List<PRIIPSField__mdt>{
            newMetadataWithCondition('ProductNameCondition', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, 'ProjectProduct__c.LegalForm__c = \'FCP\' && !ISBLANK(ProjectProduct__c.ProductName__c)'),
            newMetadataWithCondition('LegalFormCondition', 'Legal Form', 'ProjectProduct__c.LegalForm__c', 'Legal', true, false, true, 'ISBLANK(ProjectProduct__c.LegalForm__c) || ProjectProduct__c.ProductName__c != "Other"'),
            newMetadataWithCondition('CurrencyCondition', 'Currency', 'ProjectShareclass__c.Currency__c', 'Operations', true, true, true, 'UnknownToken || ProjectShareclass__c.Currency__c = \'EUR\''),
            newMetadataWithCondition('TransactionCostsCondition', 'Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Investment Performance', true, true, true, 'ProjectShareclass__c.Currency__c = \'GBP\'')
        };

        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{
            newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null),
            newShareclass(2, 'A USD Acc', 'USD', null, null)
        };

        Test.startTest();
        PRIIPSKidCompletionController.CompletionResponse response = PRIIPSKidCompletionController.getCompletionData(null);
        Test.stopTest();

        System.assertEquals(3, response.teams.size());
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals('Operations', response.teams[1].name);
        System.assertEquals('Legal', response.teams[2].name);
        reset();
    }
        // Verifies Shareclass Creation mode with local field API names.
    @IsTest
    static void getCompletionData_shareclassCreation_countsShareclassFieldsOnly() {
        reset();
        Id productId = fakeId(ProjectProduct__c.SObjectType, 1);
        PRIIPSKidCompletionController.recordTypeDeveloperNameOverride = 'FundShareclassCreation';
        PRIIPSKidCompletionController.productRecordOverride = newProduct('Carmignac Credit 2027', 'FCP', null);

        // Local field names cover object inference and Shareclass Creation filtering.
        PRIIPSKidCompletionController.metadataRowsOverride = new List<PRIIPSField__mdt>{
            newMetadata('ProductNameIgnored', 'Product Name', 'ProductName__c', 'Legal', true, false, true),
            newMetadata('CurrencyLocal', 'Currency', 'Currency__c', 'Product Strategy', true, true, true),
            newMetadata('TransactionCostsLocal', '', 'TransactionCosts__c', 'Investment Performance', true, true, true)
        };

        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{
            newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null),
            newShareclass(2, 'A USD Acc', null, null, null)
        };

        Test.startTest();
        PRIIPSKidCompletionController.CompletionResponse response = PRIIPSKidCompletionController.getCompletionData(productId);
        Test.stopTest();

        System.assertEquals('Shareclass Creation', response.projectMode);
        System.assertEquals(2, response.teams.size());
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(1, response.teams[0].completed);
        System.assertEquals(2, response.teams[0].total);
        System.assertEquals('Investment Performance', response.teams[1].name);
        System.assertEquals(1, response.teams[1].completed);
        System.assertEquals(2, response.teams[1].total);
        reset();
    }

    // Verifies DisplayCondition__c operators and ExactValue__c completion.
    @IsTest
    static void getCompletionData_productCreation_coversDisplayConditionsAndExactValue() {
        reset();
        PRIIPSKidCompletionController.productIdOverride = fakeId(ProjectProduct__c.SObjectType, 1);
        PRIIPSKidCompletionController.recordTypeDeveloperNameOverride = 'FundCreation';
        PRIIPSKidCompletionController.productRecordOverride = newProduct('Carmignac Credit 2027', 'FCP', null);

        // Conditions cover &&, ||, =, !=, ISBLANK(), !ISBLANK() and invalid tokens.
        PRIIPSKidCompletionController.metadataRowsOverride = new List<PRIIPSField__mdt>{
            newMetadataWithCondition('ProductAndCondition', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, 'ProjectProduct__c.LegalForm__c = FCP &&    && !ISBLANK(ProjectProduct__c.ProductName__c)', null),
            newMetadataWithCondition('LegalOrCondition', 'Legal Form', 'ProjectProduct__c.LegalForm__c', 'Legal', true, false, true, 'ISBLANK(ProjectProduct__c.LegalForm__c) || ProjectProduct__c.ProductName__c != "Other"', null),
            newMetadataWithCondition('CurrencyExactCondition', 'Currency', 'ProjectShareclass__c.Currency__c', 'Operations', true, true, true, 'UnknownToken || UnknownObject.Field__c = X || ProjectShareclass__c.Currency__c != \'GBP\'', 'EUR'),
            newMetadataWithCondition('TransactionCostsBlankCondition', 'Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Risk Management', true, true, true, 'ISBLANK(ProjectShareclass__c.TransactionCosts__c)', null),
            newMetadataWithCondition('TransactionCostsHiddenCondition', 'Hidden Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Investment Performance', true, true, true, 'ProjectShareclass__c.Currency__c = \'GBP\'', null),
            newMetadata('InvalidFieldIgnored', 'Invalid Field', 'ProjectProduct__c.DoesNotExist__c', 'Legal', true, false, true),
            newMetadata('MissingTeamIgnored', 'Missing Team', 'ProjectProduct__c.ProductName__c', null, true, false, true)
        };

        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{
            newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null),
            newShareclass(2, 'A USD Acc', 'USD', null, null)
        };

        Test.startTest();
        PRIIPSKidCompletionController.CompletionResponse response = PRIIPSKidCompletionController.getCompletionData(null);
        Test.stopTest();

        System.assertEquals(4, response.teams.size());
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(1, response.teams[0].completed);
        System.assertEquals('Operations', response.teams[1].name);
        System.assertEquals(1, response.teams[1].completed);
        System.assertEquals(2, response.teams[1].total);
        System.assertEquals('Legal', response.teams[2].name);
        System.assertEquals('Risk Management', response.teams[3].name);
        System.assertEquals(0, response.teams[3].completed);
        reset();
    }

    // Verifies the handled exception when no record Id is available.
    @IsTest
    static void getCompletionData_withoutRecordId_throwsHandledException() {
        reset();
        Boolean hasThrown = false;

        Test.startTest();
        try {
            PRIIPSKidCompletionController.getCompletionData(null);
        } catch (AuraHandledException e) {
            hasThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, hasThrown);
        reset();
    }

    // Verifies unsupported record page objects are rejected.
    @IsTest
    static void getCompletionData_unsupportedRecordPage_throwsHandledException() {
        reset();
        Boolean hasThrown = false;

        Test.startTest();
        try {
            PRIIPSKidCompletionController.getCompletionData(fakeId(Account.SObjectType, 1));
        } catch (AuraHandledException e) {
            hasThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, hasThrown);
        reset();
    }

    // Verifies blank modified-field source parsing.
    @IsTest
    static void parseModifiedFields_blankValue_returnsEmptySet() {
        Set<String> fields = PRIIPSKidCompletionController.parseModifiedFields(
            null,
            'ProjectShareclass__c'
        );

        System.assertEquals(0, fields.size());
    }
}