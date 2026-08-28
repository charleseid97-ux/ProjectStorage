@IsTest
private class RegistrationCountryApiServiceTest {
    // Verifies that the integration remains explicitly disabled before mappings exist.
    @IsTest
    static void returnNotConfiguredResponse() {
        RegistrationCountryApiService.Request request =
            new RegistrationCountryApiService.Request();
        request.shareClassId = buildUnknownShareClassId();
        request.shareClassName = 'Test Share Class';
        request.countriesByType = new Map<String, List<String>>();
        request.comment = 'Test comment';

        RegistrationCountryApiService.Response response =
            RegistrationCountryApiService.sendRequest(request);

        System.assertEquals(false, response.configured);
        System.assertEquals(null, response.statusCode);
    }

    // Builds a valid Share Class identifier without inserting org-specific data.
    private static Id buildUnknownShareClassId() {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get('Share_Class__c');
        String keyPrefix = objectType.getDescribe().getKeyPrefix();
        return (Id) (keyPrefix + '000000000000');
    }
}
