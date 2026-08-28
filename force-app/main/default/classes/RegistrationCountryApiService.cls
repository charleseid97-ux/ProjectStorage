public with sharing class RegistrationCountryApiService {
    // Allows tests to simulate configured API responses without a real callout.
    @TestVisible private static Response responseOverride;
    @TestVisible private static Boolean throwExceptionOverride;

    // Provides a controlled exception used by the callout handling tests.
    private class ApiServiceException extends Exception {
    }

    // Contains the complete confirmed request sent by the LWC.
    public class Request {
        public Id shareClassId;
        public String shareClassName;
        public Map<String, List<String>> countriesByType;
        public String comment;
    }

    // Contains sanitized metadata returned by the future external call.
    public class Response {
        public Boolean configured;
        public Integer statusCode;
        public String externalId;
        public String message;
    }

    // Sends the request after the endpoint, authentication, and mappings are known.
    public static Response sendRequest(Request request) {
        if (Test.isRunningTest() && throwExceptionOverride == true) {
            throw new ApiServiceException('Simulated external service exception.');
        }
        if (Test.isRunningTest() && responseOverride != null) {
            return responseOverride;
        }

        // TODO: build the payload and perform the authenticated HTTP callout.
        // TODO: return configured=true with the HTTP status and external identifier.
        Response response = new Response();
        response.configured = false;
        response.message = 'External web service mappings are not configured.';
        return response;
    }
}
