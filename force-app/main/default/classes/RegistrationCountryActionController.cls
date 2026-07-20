public with sharing class RegistrationCountryActionController {
    // Defines the source object and stable operation names used by logging.
    private static final String SHARE_CLASS_OBJECT_API_NAME = 'Share_Class__c';
    private static final String API_OPERATION_NAME = 'RegistrationCountryRequestSending';
    private static final String EMAIL_OPERATION_NAME = 'RegistrationCountryNotificationSending';

    // Defines the registration types displayed by the component.
    private static final String TYPE_RETAIL = 'Retail';
    private static final String TYPE_INSTITUTIONAL = 'Institutional';
    private static final String TYPE_SEMI_PRO = 'Semi-Pro';

    // Keeps the two required blocking messages unchanged.
    private static final String EXCLUSIVITY_ERROR =
        'The same country cannot be selected in Country Reg Needed Institutional, Country Reg Needed Retail and Country Reg Needed Semi-Pro at the same time. Please remove the duplicate country before submitting the request.';
    private static final String REGISTERED_COUNTRIES_ERROR =
        'One or more selected countries are already registered for this share class. Please remove the registered countries before saving.';

    // Allows tests to exercise the full submission flow without org-specific record creation.
    @TestVisible private static String shareClassNameOverride;
    @TestVisible private static Set<String> registeredCountriesOverride;

    // Represents one dual-listbox option returned to the LWC.
    public class CountryOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        // Creates one country option from an active picklist entry.
        public CountryOption(String optionLabel, String optionValue) {
            label = optionLabel;
            value = optionValue;
        }
    }

    // Contains the data required when the quick action opens.
    public class ContextResult {
        @AuraEnabled public List<CountryOption> countryOptions;
    }

    // Stores the Share Class data required by validation and notifications.
    private class ShareClassContext {
        Id recordId;
        String recordName;

        // Creates an immutable context from the queried Share Class.
        ShareClassContext(Id shareClassId, String shareClassName) {
            recordId = shareClassId;
            recordName = shareClassName;
        }
    }

    // Contains the result returned after the confirmed submission.
    public class SubmitResult {
        @AuraEnabled public Boolean submitted;
        @AuraEnabled public Boolean pendingMappings;
        @AuraEnabled public Boolean failed;
        @AuraEnabled public Boolean notificationSent;
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String message;
    }

    // Contains the three country selections serialized by the LWC.
    private class CountrySelectionPayload {
        public List<String> retailCountries;
        public List<String> institutionalCountries;
        public List<String> semiProCountries;
    }

    // Separates expected input validation from unexpected technical failures.
    private class BusinessValidationException extends Exception {
    }

    // Identifies missing or invalid Salesforce metadata configuration.
    private class ConfigurationException extends Exception {
    }

    // Validates the Share Class and loads active CountryRegNeeded values.
    @AuraEnabled(cacheable=true)
    public static ContextResult getContext(Id shareClassId) {
        try {
            validateShareClassId(shareClassId);

            // Confirms record access before returning the country options.
            loadShareClass(shareClassId);
            ContextResult result = new ContextResult();
            result.countryOptions = buildCountryOptions();
            return result;
        } catch (BusinessValidationException exceptionValue) {
            throw new AuraHandledException(exceptionValue.getMessage());
        } catch (ConfigurationException exceptionValue) {
            throw new AuraHandledException(exceptionValue.getMessage());
        } catch (Exception exceptionValue) {
            throw new AuraHandledException('Unable to load registration country request data.');
        }
    }

    // Receives the complete LWC selection as one serialized JSON payload.
    @AuraEnabled
    public static SubmitResult submitRegistrationCountryRequestJson(
        Id shareClassId,
        String countriesByTypeJson,
        String comment
    ) {
        CountrySelectionPayload selectionPayload =
            deserializeCountrySelectionPayload(countriesByTypeJson);

        // Reuses the existing validation, logging, and future API process.
        return submitRegistrationCountryRequest(
            shareClassId,
            selectionPayload.retailCountries,
            selectionPayload.institutionalCountries,
            selectionPayload.semiProCountries,
            comment
        );
    }

    // Validates and submits all populated registration types in one API request.
    @AuraEnabled
    public static SubmitResult submitRegistrationCountryRequest(
        Id shareClassId,
        List<String> retailCountries,
        List<String> institutionalCountries,
        List<String> semiProCountries,
        String comment
    ) {
        OperationLogService.setCorrelationId(buildCorrelationId());

        try {
            validateShareClassId(shareClassId);
            ShareClassContext shareClassRecord = loadShareClass(shareClassId);

            // Normalizes each type independently before cross-type validation.
            Map<String, List<String>> countriesByType = buildCountriesByType(
                retailCountries,
                institutionalCountries,
                semiProCountries
            );
            Set<String> allCountries = getAllCountries(countriesByType);
            validateAtLeastOneCountry(allCountries);

            // Validates active values, exclusivity, and current registrations.
            validateSelectedCountries(allCountries);
            validateCountryExclusivity(countriesByType);
            validateAlreadyRegistered(shareClassId, allCountries);

            // Builds the integration request without inventing endpoint mappings.
            RegistrationCountryApiService.Request apiRequest = buildApiRequest(
                shareClassRecord,
                countriesByType,
                comment
            );
            RegistrationCountryApiService.Response apiResponse;

            try {
                apiResponse = RegistrationCountryApiService.sendRequest(apiRequest);
            } catch (Exception exceptionValue) {
                logApiException(
                    shareClassId,
                    countriesByType,
                    apiRequest.comment,
                    exceptionValue
                );

                // Notifies the submitting user for authentication, timeout, or callout errors.
                Boolean emailSent = sendFailureNotificationSafely(
                    apiRequest,
                    null,
                    'A technical problem occurred while calling the external service.'
                );
                return buildFailureResult(null, emailSent);
            }

            // Logs and notifies the user when the external API is not configured.
            if (apiResponse == null || apiResponse.configured != true) {
                logApiNotConfigured(
                    shareClassId,
                    countriesByType,
                    apiRequest.comment
                );

                // Sends an API configuration failure email to the submitting user.
                Boolean emailSent = sendFailureNotificationSafely(
                    apiRequest,
                    apiResponse,
                    'The external Registration Country API is not configured.'
                );
                return buildApiNotConfiguredResult(emailSent);
            }

            // Treats HTTP 200 as the only successful external response.
            if (apiResponse.statusCode == 200) {
                Boolean emailSent = sendSuccessNotificationSafely(apiRequest, apiResponse);
                logApiSuccess(
                    shareClassId,
                    countriesByType,
                    apiRequest.comment,
                    apiResponse,
                    emailSent
                );
                return buildSuccessResult(apiResponse, emailSent);
            }

            // Logs every non-200 response and notifies the submitting user.
            logApiFailure(
                shareClassId,
                countriesByType,
                apiRequest.comment,
                apiResponse
            );
            String failureReason = apiResponse.statusCode == null
                ? 'The external service did not return an HTTP status.'
                : 'The external service returned HTTP ' + String.valueOf(apiResponse.statusCode) + '.';
            Boolean emailSent = sendFailureNotificationSafely(
                apiRequest,
                apiResponse,
                failureReason
            );
            return buildFailureResult(apiResponse.statusCode, emailSent);
        } catch (BusinessValidationException exceptionValue) {
            throw new AuraHandledException(exceptionValue.getMessage());
        } catch (Exception exceptionValue) {
            logUnexpectedError(shareClassId, exceptionValue);
            throw new AuraHandledException('Unable to submit the registration country request.');
        } finally {
            OperationLogService.flush();
        }
    }

    // Validates that the identifier belongs to a Share Class record.
    @TestVisible
    private static void validateShareClassId(Id shareClassId) {
        if (shareClassId == null) {
            throw new BusinessValidationException('Missing Share Class Id.');
        }

        String objectApiName = shareClassId.getSObjectType().getDescribe().getName();
        if (objectApiName != SHARE_CLASS_OBJECT_API_NAME) {
            throw new BusinessValidationException('Invalid Share Class Id.');
        }
    }

    // Loads one accessible Share Class record with the name used in notifications.
    private static ShareClassContext loadShareClass(Id shareClassId) {
        if (Test.isRunningTest() && shareClassNameOverride != null) {
            return new ShareClassContext(shareClassId, shareClassNameOverride);
        }

        List<Share_Class__c> records = [
            SELECT Id, Name
            FROM Share_Class__c
            WHERE Id = :shareClassId
            WITH USER_MODE
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new BusinessValidationException('Share Class not found.');
        }

        return new ShareClassContext(records[0].Id, records[0].Name);
    }

    // Builds active country options from Country__c.Country__c.
    private static List<CountryOption> buildCountryOptions() {
        Schema.DescribeFieldResult fieldDescribe =
            Schema.SObjectType.Country__c.fields.Country__c;

        // The picklist must remain readable by the current user.
        if (!fieldDescribe.isAccessible()) {
            throw new ConfigurationException('Country__c.Country__c is not accessible.');
        }

        List<CountryOption> options = new List<CountryOption>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new CountryOption(entry.getLabel(), entry.getValue()));
            }
        }

        if (options.isEmpty()) {
            throw new ConfigurationException('CountryRegNeeded does not contain active values.');
        }

        return options;
    }

    // Deserializes the three country selections sent by the LWC.
    private static CountrySelectionPayload deserializeCountrySelectionPayload(
        String countriesByTypeJson
    ) {
        if (String.isBlank(countriesByTypeJson)) {
            throw new AuraHandledException(
                'At least one registration country is required.'
            );
        }

        try {
            // Converts the primitive JSON parameter into the internal payload.
            CountrySelectionPayload selectionPayload =
                (CountrySelectionPayload) JSON.deserialize(
                    countriesByTypeJson,
                    CountrySelectionPayload.class
                );

            if (selectionPayload == null) {
                return new CountrySelectionPayload();
            }

            return selectionPayload;
        } catch (Exception exceptionValue) {
            throw new AuraHandledException(
                'Invalid registration country selection.'
            );
        }
    }

    // Normalizes all three country lists while preserving their original order.
    @TestVisible
    private static Map<String, List<String>> buildCountriesByType(
        List<String> retailCountries,
        List<String> institutionalCountries,
        List<String> semiProCountries
    ) {
        return new Map<String, List<String>>{
            TYPE_RETAIL => normalizeCountries(retailCountries),
            TYPE_INSTITUTIONAL => normalizeCountries(institutionalCountries),
            TYPE_SEMI_PRO => normalizeCountries(semiProCountries)
        };
    }

    // Removes blank and duplicate country values from one registration type.
    @TestVisible
    private static List<String> normalizeCountries(List<String> countries) {
        List<String> normalizedCountries = new List<String>();
        Set<String> seenCountries = new Set<String>();
        List<String> safeCountries = countries == null ? new List<String>() : countries;

        for (String country : safeCountries) {
            String safeCountry = String.isBlank(country) ? '' : country.trim();
            if (String.isBlank(safeCountry) || seenCountries.contains(safeCountry)) {
                continue;
            }

            seenCountries.add(safeCountry);
            normalizedCountries.add(safeCountry);
        }

        return normalizedCountries;
    }

    // Combines the three registration selections into one validation set.
    private static Set<String> getAllCountries(Map<String, List<String>> countriesByType) {
        Set<String> allCountries = new Set<String>();

        for (List<String> countries : countriesByType.values()) {
            allCountries.addAll(countries);
        }

        return allCountries;
    }

    // Requires at least one country across the three registration types.
    private static void validateAtLeastOneCountry(Set<String> allCountries) {
        if (allCountries.isEmpty()) {
            throw new BusinessValidationException('At least one registration country is required.');
        }
    }

    // Verifies that all submitted countries are active CountryRegNeeded values.
    private static void validateSelectedCountries(Set<String> selectedCountries) {
        Schema.DescribeFieldResult fieldDescribe =
            Schema.SObjectType.Country__c.fields.Country__c;
        Set<String> activeValues = new Set<String>();

        // Builds the list of values currently exposed by the shared value set.
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                activeValues.add(entry.getValue());
            }
        }

        for (String selectedCountry : selectedCountries) {
            if (!activeValues.contains(selectedCountry)) {
                throw new BusinessValidationException(
                    'One or more selected countries are not available in CountryRegNeeded.'
                );
            }
        }
    }

    // Blocks the same country when it is submitted for more than one type.
    @TestVisible
    private static void validateCountryExclusivity(
        Map<String, List<String>> countriesByType
    ) {
        Set<String> retailCountries = new Set<String>(countriesByType.get(TYPE_RETAIL));
        Set<String> institutionalCountries = new Set<String>(countriesByType.get(TYPE_INSTITUTIONAL));
        Set<String> semiProCountries = new Set<String>(countriesByType.get(TYPE_SEMI_PRO));

        // Checks each pair because every country must belong to one type only.
        if (
            hasIntersection(retailCountries, institutionalCountries) ||
            hasIntersection(retailCountries, semiProCountries) ||
            hasIntersection(institutionalCountries, semiProCountries)
        ) {
            throw new BusinessValidationException(EXCLUSIVITY_ERROR);
        }
    }

    // Blocks countries already registered for the selected Share Class.
    @TestVisible
    private static void validateAlreadyRegistered(
        Id shareClassId,
        Set<String> selectedCountries
    ) {
        if (Test.isRunningTest() && registeredCountriesOverride != null) {
            if (hasIntersection(selectedCountries, registeredCountriesOverride)) {
                throw new BusinessValidationException(REGISTERED_COUNTRIES_ERROR);
            }
            return;
        }

        List<Country__c> registeredCountries = [
            SELECT Id
            FROM Country__c
            WHERE ShareClass__c = :shareClassId
            AND Country__c IN :selectedCountries
            AND RegistrationStatus__c = 'REG'
            WITH USER_MODE
            LIMIT 1
        ];

        if (!registeredCountries.isEmpty()) {
            throw new BusinessValidationException(REGISTERED_COUNTRIES_ERROR);
        }
    }

    // Detects whether two country sets share at least one value.
    private static Boolean hasIntersection(Set<String> firstValues, Set<String> secondValues) {
        for (String value : firstValues) {
            if (secondValues.contains(value)) {
                return true;
            }
        }

        return false;
    }

    // Builds the request consumed by the future external API mapping.
    private static RegistrationCountryApiService.Request buildApiRequest(
        ShareClassContext shareClassRecord,
        Map<String, List<String>> countriesByType,
        String comment
    ) {
        RegistrationCountryApiService.Request request =
            new RegistrationCountryApiService.Request();
        request.shareClassId = shareClassRecord.recordId;
        request.shareClassName = shareClassRecord.recordName;
        request.countriesByType = countriesByType;
        request.comment = String.isBlank(comment) ? '' : comment.trim();
        return request;
    }

    // Sends the success email without changing the successful API outcome.
    private static Boolean sendSuccessNotificationSafely(
        RegistrationCountryApiService.Request request,
        RegistrationCountryApiService.Response response
    ) {
        try {
            RegistrationCountryNotificationService.sendSuccessEmail(request, response);
            return true;
        } catch (Exception exceptionValue) {
            logNotificationError(request.shareClassId, exceptionValue);
            return false;
        }
    }

    // Sends the failure email to the submitting user without masking the API error.
    private static Boolean sendFailureNotificationSafely(
        RegistrationCountryApiService.Request request,
        RegistrationCountryApiService.Response response,
        String failureReason
    ) {
        try {
            RegistrationCountryNotificationService.sendFailureEmail(
                request,
                response,
                failureReason
            );
            return true;
        } catch (Exception exceptionValue) {
            logNotificationError(request.shareClassId, exceptionValue);
            return false;
        }
    }

    // Returns an error result when the external API is not configured.
    private static SubmitResult buildApiNotConfiguredResult(Boolean emailSent) {
        SubmitResult result = new SubmitResult();
        result.submitted = false;
        result.pendingMappings = true;
        result.failed = true;
        result.notificationSent = emailSent;

        // Confirms whether the failure notification could be sent.
        result.message = emailSent
            ? 'The external Registration Country API is not configured. A failure notification email was sent to you.'
            : 'The external Registration Country API is not configured, and the failure notification email could not be sent.';
        return result;
    }

    // Returns the API success result and reports any notification problem.
    private static SubmitResult buildSuccessResult(
        RegistrationCountryApiService.Response response,
        Boolean emailSent
    ) {
        SubmitResult result = new SubmitResult();
        result.submitted = true;
        result.pendingMappings = false;
        result.failed = false;
        result.notificationSent = emailSent;
        result.statusCode = response.statusCode;
        result.message = emailSent
            ? 'Registration country request submitted successfully. The notification email was sent.'
            : 'Registration country request submitted successfully, but the notification email could not be sent.';
        return result;
    }

    // Returns an API failure result without rolling back its email notification.
    private static SubmitResult buildFailureResult(
        Integer statusCode,
        Boolean emailSent
    ) {
        SubmitResult result = new SubmitResult();
        result.submitted = false;
        result.pendingMappings = false;
        result.failed = true;
        result.notificationSent = emailSent;
        result.statusCode = statusCode;
        result.message = emailSent
            ? 'The Registration Country request could not be submitted. A notification email was sent to you.'
            : 'The Registration Country request could not be submitted, and the failure email could not be sent.';
        return result;
    }

    // Logs an error when the external Registration Country API is not configured.
    private static void logApiNotConfigured(
        Id shareClassId,
        Map<String, List<String>> countriesByType,
        String comment
    ) {
        Map<String, Object> context = buildLogContext(
            countriesByType,
            comment
        );
        context.put('result', 'API_NOT_CONFIGURED');

        // Records the missing API configuration as a blocking error.
        OperationLogService.Entry entry = buildLogEntry(
            shareClassId,
            OperationLogService.Level.ERROR,
            API_OPERATION_NAME,
            'The external Registration Country API is not configured.',
            context
        );
        OperationLogService.log(entry);
    }

    // Logs a successful HTTP 200 response from the external API.
    private static void logApiSuccess(
        Id shareClassId,
        Map<String, List<String>> countriesByType,
        String comment,
        RegistrationCountryApiService.Response response,
        Boolean emailSent
    ) {
        Map<String, Object> context = buildLogContext(
            countriesByType,
            comment
        );
        context.put('result', 'SUCCESS');
        context.put('statusCode', response.statusCode);
        context.put('externalId', response.externalId);
        context.put('notificationEmailSent', emailSent);

        OperationLogService.Entry entry = buildLogEntry(
            shareClassId,
            OperationLogService.Level.INFO,
            API_OPERATION_NAME,
            'Registration country request submitted successfully.',
            context
        );
        OperationLogService.log(entry);
    }

    // Logs a non-200 response without storing a confidential response payload.
    private static void logApiFailure(
        Id shareClassId,
        Map<String, List<String>> countriesByType,
        String comment,
        RegistrationCountryApiService.Response response
    ) {
        Map<String, Object> context = buildLogContext(
            countriesByType,
            comment
        );
        context.put('result', 'ERROR');
        context.put('statusCode', response.statusCode);
        context.put('externalId', response.externalId);

        OperationLogService.Entry entry = buildLogEntry(
            shareClassId,
            OperationLogService.Level.ERROR,
            API_OPERATION_NAME,
            'The external service returned an unsuccessful response.',
            context
        );
        OperationLogService.log(entry);
    }

    // Logs an authentication, timeout, callout, or unexpected API exception.
    private static void logApiException(
        Id shareClassId,
        Map<String, List<String>> countriesByType,
        String comment,
        Exception exceptionValue
    ) {
        Map<String, Object> context = buildLogContext(
            countriesByType,
            comment
        );
        context.put('result', 'EXCEPTION');

        OperationLogService.Entry entry = buildLogEntry(
            shareClassId,
            OperationLogService.Level.ERROR,
            API_OPERATION_NAME,
            'A technical exception occurred while calling the external service.',
            context
        );
        entry.exceptionValue = exceptionValue;
        OperationLogService.log(entry);
    }

    // Logs a notification failure without changing the API result.
    private static void logNotificationError(Id shareClassId, Exception exceptionValue) {
        OperationLogService.error(
            shareClassId,
            EMAIL_OPERATION_NAME,
            'The Registration Country notification email could not be sent.',
            exceptionValue
        );
    }

    // Logs an unexpected controller failure when the source record is available.
    private static void logUnexpectedError(Id shareClassId, Exception exceptionValue) {
        if (shareClassId == null) {
            return;
        }

        OperationLogService.error(
            shareClassId,
            API_OPERATION_NAME,
            'Registration country request submission failed unexpectedly.',
            exceptionValue
        );
    }

    // Builds the country and comment details shared by API log entries.
    private static Map<String, Object> buildLogContext(
        Map<String, List<String>> countriesByType,
        String comment
    ) {
        return new Map<String, Object>{
            'retailCountries' => countriesByType.get(TYPE_RETAIL),
            'institutionalCountries' => countriesByType.get(TYPE_INSTITUTIONAL),
            'semiProCountries' => countriesByType.get(TYPE_SEMI_PRO),
            'comment' => String.isBlank(comment) ? '' : comment.trim()
        };
    }

    // Creates one advanced log entry with standard retention and source metadata.
    private static OperationLogService.Entry buildLogEntry(
        Id shareClassId,
        OperationLogService.Level level,
        String operationName,
        String message,
        Map<String, Object> context
    ) {
        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = level;
        entry.sourceRecordId = String.valueOf(shareClassId);
        entry.sourceObjectApiName = SHARE_CLASS_OBJECT_API_NAME;
        entry.operation = operationName;
        entry.message = message;
        entry.contextJson = JSON.serialize(context);
        entry.expirationDate = Date.today().addDays(level == OperationLogService.Level.ERROR ? 365 : 100);
        entry.apexClass = 'RegistrationCountryActionController';
        entry.methodName = 'submitRegistrationCountryRequest';
        return entry;
    }

    // Builds one correlation identifier for every submission transaction.
    private static String buildCorrelationId() {
        return 'RegistrationCountry-' + String.valueOf(Datetime.now().getTime());
    }
}
