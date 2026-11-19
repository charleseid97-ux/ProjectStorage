/** ──────────────────────────────────────
 * @description Tests of PRIIPSKidCompletionController and PRIIPSKidHelper.parseModifiedFields: completion by team in Product Creation
 *                  (product and share class fields, display conditions, exact values, invalid fields and teams), Modification (selected
 *                  fields only) and Shareclass Creation modes, the handled errors (no record Id, unsupported page), and the parsing of
 *                  the modified fields. In memory only: the controller overrides replace the org data.
 * @author EL HITARY Achraf
 * @covers PRIIPSKidCompletionController   86%   [21-10-26]
 * @covers PRIIPSKidHelper   90%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class PRIIPSKidCompletionControllerTest {

    // Completion by team in each project mode, then the handled errors
    @isTest
    static void test_getCompletionData() {
        Test.startTest();

        // Product Creation: product and share class fields combined
        setProject('FundCreation', fakeId(ProjectProduct__c.SObjectType, 1), newProduct('Carmignac Credit 2027', null, null), metadataRows());
        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{ newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null), newShareclass(2, 'A USD Acc', null, null, null) };
        PRIIPSKidCompletionController.CompletionResponse response = PRIIPSKidCompletionController.getCompletionData(null);
        System.assertEquals('Product Creation', response.projectMode);
        System.assertEquals(3, response.teams.size(), 'Three teams should have completion indicators.');
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(2, response.teams[0].completed);
        System.assertEquals(3, response.teams[0].total);
        System.assertEquals(67, response.teams[0].percentage);

        // Product Creation: display conditions (&&, ||, =, !=, ISBLANK(), !ISBLANK() and invalid tokens)
        setProject('FundCreation', fakeId(ProjectProduct__c.SObjectType, 1), newProduct('Carmignac Credit 2027', 'FCP', null), new List<PRIIPSField__mdt>{
            newMetadataWithCondition('ProductNameCondition', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, 'ProjectProduct__c.LegalForm__c = \'FCP\' && !ISBLANK(ProjectProduct__c.ProductName__c)'),
            newMetadataWithCondition('LegalFormCondition', 'Legal Form', 'ProjectProduct__c.LegalForm__c', 'Legal', true, false, true, 'ISBLANK(ProjectProduct__c.LegalForm__c) || ProjectProduct__c.ProductName__c != "Other"'),
            newMetadataWithCondition('CurrencyCondition', 'Currency', 'ProjectShareclass__c.Currency__c', 'Operations', true, true, true, 'UnknownToken || ProjectShareclass__c.Currency__c = \'EUR\''),
            newMetadataWithCondition('TransactionCostsCondition', 'Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Investment Performance', true, true, true, 'ProjectShareclass__c.Currency__c = \'GBP\'')
        });
        PRIIPSKidCompletionController.shareclassRecordsOverride = twoShareclasses();
        response = PRIIPSKidCompletionController.getCompletionData(null);
        System.assertEquals(3, response.teams.size());
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals('Operations', response.teams[1].name);
        System.assertEquals('Legal', response.teams[2].name);

        // Product Creation: exact values, malformed conditions, unknown field and missing team ignored
        setProject('FundCreation', fakeId(ProjectProduct__c.SObjectType, 1), newProduct('Carmignac Credit 2027', 'FCP', null), new List<PRIIPSField__mdt>{
            newMetadataWithCondition('ProductAndCondition', 'Product Name', 'ProjectProduct__c.ProductName__c', 'Product Strategy', true, false, true, 'ProjectProduct__c.LegalForm__c = FCP &&    && !ISBLANK(ProjectProduct__c.ProductName__c)', null),
            newMetadataWithCondition('LegalOrCondition', 'Legal Form', 'ProjectProduct__c.LegalForm__c', 'Legal', true, false, true, 'ISBLANK(ProjectProduct__c.LegalForm__c) || ProjectProduct__c.ProductName__c != "Other"', null),
            newMetadataWithCondition('CurrencyExactCondition', 'Currency', 'ProjectShareclass__c.Currency__c', 'Operations', true, true, true, 'UnknownToken || UnknownObject.Field__c = X || ProjectShareclass__c.Currency__c != \'GBP\'', 'EUR'),
            newMetadataWithCondition('TransactionCostsBlankCondition', 'Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Risk Management', true, true, true, 'ISBLANK(ProjectShareclass__c.TransactionCosts__c)', null),
            newMetadataWithCondition('TransactionCostsHiddenCondition', 'Hidden Transaction Costs', 'ProjectShareclass__c.TransactionCosts__c', 'Investment Performance', true, true, true, 'ProjectShareclass__c.Currency__c = \'GBP\'', null),
            newMetadata('InvalidFieldIgnored', 'Invalid Field', 'ProjectProduct__c.DoesNotExist__c', 'Legal', true, false, true),
            newMetadata('MissingTeamIgnored', 'Missing Team', 'ProjectProduct__c.ProductName__c', null, true, false, true)
        });
        PRIIPSKidCompletionController.shareclassRecordsOverride = twoShareclasses();
        response = PRIIPSKidCompletionController.getCompletionData(null);
        System.assertEquals(4, response.teams.size());
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(1, response.teams[0].completed);
        System.assertEquals('Operations', response.teams[1].name);
        System.assertEquals(1, response.teams[1].completed);
        System.assertEquals(2, response.teams[1].total);
        System.assertEquals('Legal', response.teams[2].name);
        System.assertEquals('Risk Management', response.teams[3].name);
        System.assertEquals(0, response.teams[3].completed);

        // Modification: only the fields selected in TECH_FieldsToModify__c count
        setProject('FundShareClassModification', fakeId(ProjectProduct__c.SObjectType, 1), newProduct('Carmignac Credit 2027', 'FCP', 'ProjectProduct__c.ProductName__c'), metadataRows());
        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{ newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), 'Currency__c'), newShareclass(2, 'A USD Acc', 'USD', null, 'ProjectShareclass__c.TransactionCosts__c') };
        response = PRIIPSKidCompletionController.getCompletionData(null);
        System.assertEquals('Modification', response.projectMode);
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(2, response.teams[0].completed);
        System.assertEquals(2, response.teams[0].total);
        System.assertEquals('Investment Performance', response.teams[1].name);
        System.assertEquals(0, response.teams[1].completed);
        System.assertEquals(1, response.teams[1].total);

        // Shareclass Creation: local field API names, product fields ignored
        setProject('FundShareclassCreation', null, newProduct('Carmignac Credit 2027', 'FCP', null), new List<PRIIPSField__mdt>{
            newMetadata('ProductNameIgnored', 'Product Name', 'ProductName__c', 'Legal', true, false, true),
            newMetadata('CurrencyLocal', 'Currency', 'Currency__c', 'Product Strategy', true, true, true),
            newMetadata('TransactionCostsLocal', '', 'TransactionCosts__c', 'Investment Performance', true, true, true)
        });
        PRIIPSKidCompletionController.shareclassRecordsOverride = new List<SObject>{ newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null), newShareclass(2, 'A USD Acc', null, null, null) };
        response = PRIIPSKidCompletionController.getCompletionData(fakeId(ProjectProduct__c.SObjectType, 1));
        System.assertEquals('Shareclass Creation', response.projectMode);
        System.assertEquals(2, response.teams.size());
        System.assertEquals('Product Strategy', response.teams[0].name);
        System.assertEquals(1, response.teams[0].completed);
        System.assertEquals(2, response.teams[0].total);
        System.assertEquals('Investment Performance', response.teams[1].name);
        System.assertEquals(1, response.teams[1].completed);
        System.assertEquals(2, response.teams[1].total);

        // Handled errors: no record Id, then an unsupported record page
        PRIIPSKidCompletionController.resetOverridesForTest();
        Boolean noRecordIdRejected = throwsHandledException(null);
        Boolean unsupportedPageRejected = throwsHandledException(fakeId(Account.SObjectType, 1));

        Test.stopTest();

        PRIIPSKidCompletionController.resetOverridesForTest();
        System.assert(noRecordIdRejected, 'No record Id');
        System.assert(unsupportedPageRejected, 'Unsupported record page');
    }

    // Local and object-qualified modified field names, and a blank value
    @isTest
    static void test_parseModifiedFields() {
        Test.startTest();

        Set<String> fields = PRIIPSKidHelper.parseModifiedFields('Currency__c;ProjectShareclass__c.TransactionCosts__c', 'ProjectShareclass__c');
        Set<String> blankFields = PRIIPSKidHelper.parseModifiedFields(null, 'ProjectShareclass__c');

        Test.stopTest();

        System.assert(fields.containsAll(new Set<String>{ 'Currency__c', 'ProjectShareclass__c.Currency__c', 'TransactionCosts__c', 'ProjectShareclass__c.TransactionCosts__c' }), 'Local and qualified names');
        System.assertEquals(0, blankFields.size());
    }

    // Overrides of a project scenario (PS scope): record type, product Id, product record and metadata rows
    private static void setProject(String recordTypeDeveloperName, Id productId, SObject product, List<PRIIPSField__mdt> rows) {
        PRIIPSKidCompletionController.resetOverridesForTest();
        PRIIPSKidCompletionController.productIdOverride = productId;
        PRIIPSKidCompletionController.recordTypeDeveloperNameOverride = recordTypeDeveloperName;
        PRIIPSKidCompletionController.projectScopeOverride = 'PS';
        PRIIPSKidCompletionController.productRecordOverride = product;
        PRIIPSKidCompletionController.metadataRowsOverride = rows;
    }

    private static Boolean throwsHandledException(Id recordId) {
        try {
            PRIIPSKidCompletionController.getCompletionData(recordId);
        }
        catch (AuraHandledException e) {
            return true;
        }
        return false;
    }

    // Creates a fake Salesforce Id with the right object prefix.
    private static Id fakeId(Schema.SObjectType objectType, Integer index) {
        String prefix = objectType.getDescribe().getKeyPrefix();
        String suffix = String.valueOf(index).leftPad(12, '0');
        return Id.valueOf(prefix + suffix);
    }

    // Creates one Custom Metadata row used by the completion engine (the controller counts only mandatory PRIIPs fields).
    private static PRIIPSField__mdt newMetadata(String developerName, String label, String fieldApiName, String team, Boolean productCreation, Boolean shareclassCreation, Boolean modification) {
        PRIIPSField__mdt metadataRow = new PRIIPSField__mdt();
        metadataRow.DeveloperName = developerName;
        metadataRow.MasterLabel = label;
        metadataRow.FieldApiName__c = fieldApiName;
        metadataRow.Team__c = team;
        metadataRow.ProductCreation__c = productCreation;
        metadataRow.ShareclassCreation__c = shareclassCreation;
        metadataRow.ProductShareModification__c = modification;
        metadataRow.Required__c = true;
        return metadataRow;
    }

    // Creates one Custom Metadata row with condition and exact-value rules.
    private static PRIIPSField__mdt newMetadataWithCondition(String developerName, String label, String fieldApiName, String team, Boolean productCreation, Boolean shareclassCreation, Boolean modification, String displayCondition, String exactValue) {
        PRIIPSField__mdt metadataRow = newMetadata(developerName, label, fieldApiName, team, productCreation, shareclassCreation, modification);
        metadataRow.DisplayCondition__c = displayCondition;
        metadataRow.ExactValue__c = exactValue;
        return metadataRow;
    }

    // Creates one Custom Metadata row with a DisplayCondition__c expression.
    private static PRIIPSField__mdt newMetadataWithCondition(String developerName, String label, String fieldApiName, String team, Boolean productCreation, Boolean shareclassCreation, Boolean modification, String displayCondition) {
        PRIIPSField__mdt metadataRow = newMetadata(developerName, label, fieldApiName, team, productCreation, shareclassCreation, modification);
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

    private static List<SObject> twoShareclasses() {
        return new List<SObject>{ newShareclass(1, 'A EUR Acc', 'EUR', Decimal.valueOf('0.12'), null), newShareclass(2, 'A USD Acc', 'USD', null, null) };
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
}