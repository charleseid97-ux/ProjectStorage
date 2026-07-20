@IsTest
private class RegistrationCountryActionControllerTest {
    private static final String EXCLUSIVITY_ERROR =
        'The same country cannot be selected in Country Reg Needed Institutional, Country Reg Needed Retail and Country Reg Needed Semi-Pro at the same time. Please remove the duplicate country before submitting the request.';
    private static final String REGISTERED_COUNTRIES_ERROR =
        'One or more selected countries are already registered for this share class. Please remove the registered countries before saving.';

    // Verifies ordered normalization without requiring every type to be populated.
    @IsTest
    static void normalizeCountrySelections() {
        Map<String, List<String>> countriesByType =
            RegistrationCountryActionController.buildCountriesByType(
                new List<String>{ 'FR', ' FR ', null, 'DE', 'FR' },
                null,
                new List<String>()
            );

        System.assertEquals(new List<String>{ 'FR', 'DE' }, countriesByType.get('Retail'));
        System.assertEquals(new List<String>(), countriesByType.get('Institutional'));
        System.assertEquals(new List<String>(), countriesByType.get('Semi-Pro'));
    }

    // Verifies that the server blocks a duplicate across two submitted types.
    @IsTest
    static void blockCountrySelectedForTwoTypes() {
        Map<String, List<String>> countriesByType = new Map<String, List<String>>{
            'Retail' => new List<String>{ 'FR' },
            'Institutional' => new List<String>{ 'FR' },
            'Semi-Pro' => new List<String>{ 'DE' }
        };
        Exception capturedException;

        try {
            RegistrationCountryActionController.validateCountryExclusivity(countriesByType);
        } catch (Exception exceptionValue) {
            capturedException = exceptionValue;
        }

        System.assertNotEquals(null, capturedException);
        System.assertEquals(EXCLUSIVITY_ERROR, capturedException.getMessage());
    }

    // Verifies that an already registered Country__c value blocks submission.
    @IsTest
    static void blockAlreadyRegisteredCountry() {
        Id shareClassId = buildUnknownShareClassId();
        RegistrationCountryActionController.registeredCountriesOverride =
            new Set<String>{ 'FR' };
        Exception capturedException;

        try {
            RegistrationCountryActionController.validateAlreadyRegistered(
                shareClassId,
                new Set<String>{ 'FR', 'DE' }
            );
        } catch (Exception exceptionValue) {
            capturedException = exceptionValue;
        }

        System.assertNotEquals(null, capturedException);
        System.assertEquals(REGISTERED_COUNTRIES_ERROR, capturedException.getMessage());
    }

    // Verifies the preparation result while the external API is not configured.
    @IsTest
    static void returnPendingResultBeforeMappingsExist() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();

        RegistrationCountryApiService.Response apiResponse =
            new RegistrationCountryApiService.Response();
        apiResponse.configured = false;
        RegistrationCountryApiService.responseOverride = apiResponse;

        Test.startTest();
        RegistrationCountryActionController.SubmitResult result =
            RegistrationCountryActionController.submitRegistrationCountryRequest(
                shareClassId,
                new List<String>{ activeCountry },
                new List<String>(),
                new List<String>(),
                'Pending mapping comment'
            );
        Test.stopTest();

        System.assertEquals(false, result.submitted);
        System.assertEquals(true, result.pendingMappings);
    }

    // Verifies HTTP 200 processing and the success email notification path.
    @IsTest
    static void submitAndNotifyTeamsAfterHttp200() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();

        RegistrationCountryApiService.Response apiResponse =
            new RegistrationCountryApiService.Response();
        apiResponse.configured = true;
        apiResponse.statusCode = 200;
        apiResponse.externalId = 'EXT-100';
        RegistrationCountryApiService.responseOverride = apiResponse;
        RegistrationCountryNotificationService.recipientEmailsOverride =
            new Set<String>{ getCurrentUserEmail() };

        Test.startTest();
        RegistrationCountryActionController.SubmitResult result =
            RegistrationCountryActionController.submitRegistrationCountryRequest(
                shareClassId,
                new List<String>{ activeCountry },
                new List<String>(),
                new List<String>(),
                'Success email comment'
            );
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, result.submitted);
        System.assertEquals(200, result.statusCode);
        System.assertEquals(1, emailInvocations);
    }

    // Verifies that a non-200 response triggers a failure email and blocks success.
    @IsTest
    static void notifySubmittingUserAfterNon200Response() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();

        RegistrationCountryApiService.Response apiResponse =
            new RegistrationCountryApiService.Response();
        apiResponse.configured = true;
        apiResponse.statusCode = 401;
        RegistrationCountryApiService.responseOverride = apiResponse;

        Test.startTest();
        RegistrationCountryActionController.SubmitResult result =
            RegistrationCountryActionController.submitRegistrationCountryRequest(
                shareClassId,
                new List<String>{ activeCountry },
                new List<String>(),
                new List<String>(),
                'Authentication failure comment'
            );
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, result.failed);
        System.assertEquals(401, result.statusCode);
        System.assertEquals(1, emailInvocations);
    }


    // Verifies that an authentication or callout exception sends a failure email.
    @IsTest
    static void notifySubmittingUserAfterApiException() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();
        RegistrationCountryApiService.throwExceptionOverride = true;

        Test.startTest();
        RegistrationCountryActionController.SubmitResult result =
            RegistrationCountryActionController.submitRegistrationCountryRequest(
                shareClassId,
                new List<String>{ activeCountry },
                new List<String>(),
                new List<String>(),
                'Callout exception comment'
            );
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, result.failed);
        System.assertEquals(null, result.statusCode);
        System.assertEquals(1, emailInvocations);
    }

    // Verifies Share Class identifier validation before metadata access.
    @IsTest
    static void rejectMissingShareClassId() {
        Exception capturedException;

        try {
            RegistrationCountryActionController.validateShareClassId(null);
        } catch (Exception exceptionValue) {
            capturedException = exceptionValue;
        }

        System.assertNotEquals(null, capturedException);
        System.assertEquals('Missing Share Class Id.', capturedException.getMessage());
    }

    // Creates test overrides for record and Country__c registration queries.
    private static Id prepareControllerOverrides() {
        Id shareClassId = buildUnknownShareClassId();
        RegistrationCountryActionController.shareClassNameOverride = 'Test Share Class';
        RegistrationCountryActionController.registeredCountriesOverride = new Set<String>();
        return shareClassId;
    }

    // Returns the current test user email for notification assertions.
    private static String getCurrentUserEmail() {
        return [
            SELECT Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ].Email;
    }

    // Builds a valid but non-existing Share Class identifier for isolated tests.
    private static Id buildUnknownShareClassId() {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get('Share_Class__c');
        String keyPrefix = objectType.getDescribe().getKeyPrefix();
        return (Id) (keyPrefix + '000000000000');
    }

    // Finds one active value from Country__c.Country__c.
    private static String findFirstActiveCountryValue() {
        Schema.DescribeFieldResult fieldDescribe =
            Schema.SObjectType.Country__c.fields.Country__c;

        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        System.assert(false, 'Country__c.Country__c must contain one active value.');
        return null;
    }
}
