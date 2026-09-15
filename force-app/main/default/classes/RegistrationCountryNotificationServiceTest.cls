@IsTest
private class RegistrationCountryNotificationServiceTest {
    // Verifies that the component comment and all types are included in the recap.
    @IsTest
    static void buildEmailDetailsWithComment() {
        RegistrationCountryApiService.Request request = buildRequest();

        String details =
            RegistrationCountryNotificationService.buildRequestDetails(request);

        System.assert(details.contains('Retail: FR'));
        System.assert(details.contains('Institutional: DE'));
        System.assert(details.contains('Semi-Pro: CH'));
        System.assert(details.contains('Comment: Email notification comment'));
    }

    // Verifies the success email path with a controlled internal recipient.
    @IsTest
    static void sendSuccessEmail() {
        RegistrationCountryNotificationService.recipientEmailsOverride =
            new Set<String>{ getCurrentUserEmail() };
        RegistrationCountryApiService.Response response =
            new RegistrationCountryApiService.Response();
        response.configured = true;
        response.statusCode = 200;
        response.externalId = 'EXT-200';

        Test.startTest();
        RegistrationCountryNotificationService.sendSuccessEmail(buildRequest(), response);
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailInvocations);
    }

    // Verifies the failure email path addressed to the submitting user.
    @IsTest
    static void sendFailureEmail() {
        RegistrationCountryApiService.Response response =
            new RegistrationCountryApiService.Response();
        response.configured = true;
        response.statusCode = 500;

        Test.startTest();
        RegistrationCountryNotificationService.sendFailureEmail(
            buildRequest(),
            response,
            'The external service returned HTTP 500.'
        );
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailInvocations);
    }

    // Builds one complete notification request shared by the email tests.
    private static RegistrationCountryApiService.Request buildRequest() {
        RegistrationCountryApiService.Request request =
            new RegistrationCountryApiService.Request();
        request.shareClassId = buildUnknownShareClassId();
        request.shareClassName = 'Test Share Class';
        request.countriesByType = new Map<String, List<String>>{
            'Retail' => new List<String>{ 'FR' },
            'Institutional' => new List<String>{ 'DE' },
            'Semi-Pro' => new List<String>{ 'CH' }
        };
        request.comment = 'Email notification comment';
        return request;
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

    // Builds a valid Share Class identifier without inserting org-specific data.
    private static Id buildUnknownShareClassId() {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get('Share_Class__c');
        String keyPrefix = objectType.getDescribe().getKeyPrefix();
        return (Id) (keyPrefix + '000000000000');
    }
}
