public with sharing class GenericExternalIdService {
    public class ExternalIdServiceException extends Exception {}

    /**
     * Populates the External ID field when it is blank.
     *
     * This method is compatible with before insert
     * and before update trigger contexts.
     */
    public static void populate(
        List<SObject> records,
        String fieldApiName
    ) {
        if (records == null || records.isEmpty()) {
            return;
        }

        if (String.isBlank(fieldApiName)) {
            throw new ExternalIdServiceException(
                'The External ID field API name is required.'
            );
        }

        Schema.SObjectType objectType =
            records[0].getSObjectType();

        validateField(
            objectType,
            fieldApiName
        );

        String objectName =
            buildCamelCaseObjectName(objectType);

        for (SObject record : records) {
            Object currentValue =
                record.get(fieldApiName);

            /*
             * Preserve values provided by integrations
             * or other business processes.
             */
            if (currentValue == null ||
                String.isBlank(String.valueOf(currentValue))) {

                record.put(
                    fieldApiName,
                    createExternalId(objectName)
                );
            }
        }
    }

    /**
     * Generates an External ID using the following format:
     *
     * AccountPlan_73918274650192837
     */
    @TestVisible
    private static String createExternalId(
        String objectName
    ) {
        Long randomNumber =
            Crypto.getRandomLong();

        String numericPart =
            String.valueOf(randomNumber)
                .replace('-', '');

        return objectName + '_' + numericPart;
    }

    /**
     * Converts a Salesforce API name into CamelCase.
     *
     * Account_Plan__c becomes AccountPlan.
     * Opportunity becomes Opportunity.
     * My_Object__c becomes MyObject.
     */
    @TestVisible
    private static String buildCamelCaseObjectName(
        Schema.SObjectType objectType
    ) {
        String apiName =
            objectType.getDescribe().getName();

        /*
         * Remove the custom object suffix.
         */
        if (apiName.endsWith('__c')) {
            apiName = apiName.substring(
                0,
                apiName.length() - 3
            );
        }

        /*
         * Split the API name on underscores or
         * other non-alphanumeric characters.
         */
        List<String> parts =
            apiName.split('[^A-Za-z0-9]+');

        String camelCaseName = '';

        for (String part : parts) {
            if (!String.isBlank(part)) {
                camelCaseName +=
                    part.substring(0, 1).toUpperCase()
                    + part.substring(1);
            }
        }

        if (String.isBlank(camelCaseName)) {
            return 'Object';
        }

        return camelCaseName;
    }

    /**
     * Validates that the field exists and can be populated.
     */
    private static void validateField(
        Schema.SObjectType objectType,
        String fieldApiName
    ) {
        Map<String, Schema.SObjectField> fields =
            objectType.getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            throw new ExternalIdServiceException(
                'The field ' + fieldApiName +
                ' does not exist on object ' +
                objectType.getDescribe().getName() + '.'
            );
        }

        Schema.DescribeFieldResult fieldDescribe =
            fields.get(fieldApiName).getDescribe();

        if (!fieldDescribe.isCreateable() &&
            !fieldDescribe.isUpdateable()) {

            throw new ExternalIdServiceException(
                'The field ' + fieldApiName +
                ' cannot be populated.'
            );
        }
    }
}