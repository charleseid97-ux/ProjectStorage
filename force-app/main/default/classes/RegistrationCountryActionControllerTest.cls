@IsTest
private class RegistrationCountryActionControllerTest {
    private static final String EXCLUSIVITY_ERROR =
        'The same country cannot be selected in Country Reg Needed Institutional, Country Reg Needed Retail and Country Reg Needed Semi-Pro at the same time. Please remove the duplicate country before submitting the request.';
    private static final String REGISTERED_COUNTRIES_ERROR =
        'One or more selected countries are already registered for this share class. Please remove the registered countries before saving.';

    // Simulates successful authentication and a configurable catalog response.
    private class SequantisCalloutMock implements HttpCalloutMock {
        private Integer registrationStatusCode;
        private String registrationResponseBody;
        private Boolean throwCalloutException;

        // Creates one mock response scenario for the Sequantis integration.
        SequantisCalloutMock(
            Integer statusCode,
            String responseBody,
            Boolean shouldThrowException
        ) {
            registrationStatusCode = statusCode;
            registrationResponseBody = responseBody;
            throwCalloutException = shouldThrowException;
        }

        // Returns the authentication or registration response according to the endpoint.
        public HttpResponse respond(HttpRequest request) {
            if (throwCalloutException) {
                throw new CalloutException('Mock Sequantis callout exception.');
            }

            HttpResponse response = new HttpResponse();

            // Returns the technical token expected by the registration request.
            if (request.getEndpoint().contains('/rest/authentication/')) {
                response.setStatusCode(200);
                response.setBody('1618075391563505891');
                return response;
            }

            // Returns the configured CARMIGNAC_CATALOG response.
            response.setStatusCode(registrationStatusCode);
            response.setBody(registrationResponseBody);
            return response;
        }
    }

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

    // Verifies HTTP 202 processing and the success email notification path.
    @IsTest
    static void submitAndNotifyTeamsAfterHttp202() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();
        RegistrationCountryNotificationService.recipientEmailsOverride =
            new Set<String>{ getCurrentUserEmail() };

        // Simulates the response currently returned by CARMIGNAC_CATALOG.
        Test.setMock(
            HttpCalloutMock.class,
            new SequantisCalloutMock(202, 'Registration', false)
        );

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
        System.assertEquals(false, result.failed);
        System.assertEquals(202, result.statusCode);
        System.assertEquals(1, emailInvocations);
    }

    // Verifies that a non-success response triggers a failure email.
    @IsTest
    static void notifySubmittingUserAfterHttp400() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();

        // Simulates a body validation error returned by Sequantis.
        Test.setMock(
            HttpCalloutMock.class,
            new SequantisCalloutMock(400, 'Invalid registration request.', false)
        );

        Test.startTest();
        RegistrationCountryActionController.SubmitResult result =
            RegistrationCountryActionController.submitRegistrationCountryRequest(
                shareClassId,
                new List<String>{ activeCountry },
                new List<String>(),
                new List<String>(),
                'Failure email comment'
            );
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, result.failed);
        System.assertEquals(false, result.submitted);
        System.assertEquals(400, result.statusCode);
        System.assertEquals(1, emailInvocations);
    }

    // Verifies that an authentication or callout exception sends a failure email.
    @IsTest
    static void notifySubmittingUserAfterApiException() {
        String activeCountry = findFirstActiveCountryValue();
        Id shareClassId = prepareControllerOverrides();

        // Forces the service call to fail before receiving an HTTP response.
        Test.setMock(
            HttpCalloutMock.class,
            new SequantisCalloutMock(null, null, true)
        );

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
        System.assertEquals(false, result.submitted);
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

    // Creates test overrides for Share Class and registration queries.
    private static Id prepareControllerOverrides() {
        Id shareClassId = buildUnknownShareClassId();
        RegistrationCountryActionController.shareClassNameOverride = 'Test Share Class';
        RegistrationCountryActionController.registeredCountriesOverride =
            new Set<String>();
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

    // Builds a valid but non-existing Share Class identifier.
    private static Id buildUnknownShareClassId() {
        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get('Share_Class__c');
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

        System.assert(
            false,
            'Country__c.Country__c must contain one active value.'
        );
        return null;
    }
}