@IsTest
private class GenericExternalIdServiceTest {

    /**
     * Verify that an External ID is generated
     * when the target field is null.
     */
    @IsTest
    static void testPopulateWhenFieldIsNull() {

        Account acc = new Account(
            Name = 'Test Account'
        );

        Test.startTest();

        GenericExternalIdService.populate(
            new List<SObject>{ acc },
            'Description'
        );

        Test.stopTest();

        System.assertNotEquals(
            null,
            acc.Description,
            'The field should have been populated.'
        );

        System.assert(
            acc.Description.startsWith('Account_'),
            'The generated External ID should start with Account_.'
        );

        System.assert(
            Pattern.matches(
                '^Account_[0-9]+$',
                acc.Description
            ),
            'The generated External ID should contain only digits after Account_.'
        );
    }


    /**
     * Verify that a blank value is replaced.
     */
    @IsTest
    static void testPopulateWhenFieldIsBlank() {

        Account acc = new Account(
            Name = 'Test Account',
            Description = '   '
        );

        GenericExternalIdService.populate(
            new List<SObject>{ acc },
            'Description'
        );

        System.assert(
            acc.Description.startsWith('Account_'),
            'A blank field should be populated.'
        );
    }


    /**
     * Verify that an existing value is preserved.
     */
    @IsTest
    static void testExistingValueIsPreserved() {

        String existingExternalId =
            'EXTERNAL_SYSTEM_12345';

        Account acc = new Account(
            Name = 'Test Account',
            Description = existingExternalId
        );

        GenericExternalIdService.populate(
            new List<SObject>{ acc },
            'Description'
        );

        System.assertEquals(
            existingExternalId,
            acc.Description,
            'Existing values must not be overwritten.'
        );
    }


    /**
     * Verify that multiple records can be processed.
     */
    @IsTest
    static void testPopulateMultipleRecords() {

        Account acc1 = new Account(
            Name = 'Account 1'
        );

        Account acc2 = new Account(
            Name = 'Account 2'
        );

        Account acc3 = new Account(
            Name = 'Account 3',
            Description = 'EXISTING_ID'
        );

        List<SObject> records = new List<SObject>{
            acc1,
            acc2,
            acc3
        };

        GenericExternalIdService.populate(
            records,
            'Description'
        );

        System.assert(
            acc1.Description.startsWith('Account_'),
            'Account 1 should receive an External ID.'
        );

        System.assert(
            acc2.Description.startsWith('Account_'),
            'Account 2 should receive an External ID.'
        );

        System.assertNotEquals(
            acc1.Description,
            acc2.Description,
            'Generated IDs should normally be unique.'
        );

        System.assertEquals(
            'EXISTING_ID',
            acc3.Description,
            'Existing External IDs must be preserved.'
        );
    }


    /**
     * Null collections should simply be ignored.
     */
    @IsTest
    static void testNullRecords() {

        Test.startTest();

        GenericExternalIdService.populate(
            null,
            'Description'
        );

        Test.stopTest();

        System.assert(true);
    }


    /**
     * Empty collections should simply be ignored.
     */
    @IsTest
    static void testEmptyRecords() {

        Test.startTest();

        GenericExternalIdService.populate(
            new List<SObject>(),
            'Description'
        );

        Test.stopTest();

        System.assert(true);
    }


    /**
     * Field API name is mandatory.
     */
    @IsTest
    static void testBlankFieldApiName() {

        Account acc = new Account(
            Name = 'Test Account'
        );

        try {

            GenericExternalIdService.populate(
                new List<SObject>{ acc },
                ''
            );

            System.assert(
                false,
                'An exception should have been thrown.'
            );

        } catch (
            GenericExternalIdService.ExternalIdServiceException e
        ) {

            System.assertEquals(
                'The External ID field API name is required.',
                e.getMessage()
            );
        }
    }


    /**
     * Unknown fields should be rejected.
     */
    @IsTest
    static void testUnknownField() {

        Account acc = new Account(
            Name = 'Test Account'
        );

        try {

            GenericExternalIdService.populate(
                new List<SObject>{ acc },
                'FieldThatDoesNotExist__c'
            );

            System.assert(
                false,
                'An exception should have been thrown.'
            );

        } catch (
            GenericExternalIdService.ExternalIdServiceException e
        ) {

            System.assert(
                e.getMessage().contains(
                    'does not exist on object Account'
                ),
                'The expected field validation error should be returned.'
            );
        }
    }


    /**
     * Read-only fields should be rejected.
     *
     * Account.Id cannot be created or updated manually,
     * so it covers the validation branch.
     */
    @IsTest
    static void testNonWritableField() {

        Account acc = new Account(
            Name = 'Test Account'
        );

        try {

            GenericExternalIdService.populate(
                new List<SObject>{ acc },
                'Id'
            );

            System.assert(
                false,
                'An exception should have been thrown.'
            );

        } catch (
            GenericExternalIdService.ExternalIdServiceException e
        ) {

            System.assertEquals(
                'The field Id cannot be populated.',
                e.getMessage()
            );
        }
    }


    /**
     * Direct test of the @TestVisible
     * External ID generator.
     */
    @IsTest
    static void testCreateExternalId() {

        String externalId =
            GenericExternalIdService.createExternalId(
                'AccountPlan'
            );

        System.assertNotEquals(
            null,
            externalId
        );

        System.assert(
            externalId.startsWith(
                'AccountPlan_'
            )
        );

        System.assert(
            Pattern.matches(
                '^AccountPlan_[0-9]+$',
                externalId
            ),
            'Expected format: AccountPlan_<numeric value>'
        );
    }


    /**
     * Verify CamelCase generation
     * for a standard Salesforce object.
     */
    @IsTest
    static void testBuildCamelCaseStandardObject() {
        String objectName = GenericExternalIdService.buildCamelCaseObjectName(
        Account.SObjectType
        );

    System.assertEquals('Account', objectName);
    }
}