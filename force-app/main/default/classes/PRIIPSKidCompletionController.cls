public with sharing class PRIIPSKidCompletionController {
    private static final String PRODUCT_OBJECT_API_NAME = 'ProjectProduct__c';
    private static final String PRODUCT_CHILD_OBJECT_API_NAME = 'ProjectProductChild__c';
    private static final String SHARECLASS_OBJECT_API_NAME = 'ProjectShareclass__c';
    private static final String PRODUCT_CHILD_PARENT_FIELD = 'ProjectProductParent__c';
    private static final String DEFAULT_SHARECLASS_LOOKUP_FIELD = 'ProjectProduct__c';
    private static final String PRODUCT_MODIFIED_FIELDS_FIELD = 'TECH_FieldsToModify__c';
    private static final String SHARECLASS_MODIFIED_FIELDS_FIELD = 'TECH_FieldsToModify__c';
    private static final String MODE_PRODUCT_CREATION = 'Product Creation';
    private static final String MODE_SHARECLASS_CREATION = 'Shareclass Creation';
    private static final String MODE_MODIFICATION = 'Modification';

    private static final List<String> SHARECLASS_IDENTITY_FIELDS = new List<String>{
        'Name__c',
        'Share_Class_Name__c',
        'Name',
        'ISIN__c'
    };

    private static final List<String> TEAM_ORDER = new List<String>{
        'Product Strategy',
        'Investment Performance',
        'Operations',
        'Legal',
        'Risk Management'
    };

    @TestVisible private static Id productIdOverride;
    @TestVisible private static String recordTypeDeveloperNameOverride;
    @TestVisible private static List<PRIIPSField__mdt> metadataRowsOverride;
    @TestVisible private static SObject productRecordOverride;
    @TestVisible private static List<SObject> shareclassRecordsOverride;

    public class CompletionResponse {
        @AuraEnabled public String projectMode;
        @AuraEnabled public String projectRecordType;
        @AuraEnabled public String warningMessage;
        @AuraEnabled public List<TeamCompletion> teams = new List<TeamCompletion>();
    }

    public class TeamCompletion {
        @AuraEnabled public String key;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Integer completed = 0;
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer percentage = 0;
        @AuraEnabled public List<CompletionDetail> details = new List<CompletionDetail>();
    }

    public class CompletionDetail {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Integer completed = 0;
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer percentage = 0;
    }

    private class FieldReference {
        String objectApiName;
        String fieldApiName;
    }

    private class FieldConfig {
        String key;
        String fullFieldApiName;
        String objectApiName;
        String fieldApiName;
        String team;
        String label;
        String displayCondition;
        Boolean required;
    }
    // Loads completion indicators by team for the current Project Product record page.
    @AuraEnabled(cacheable=true)
    public static CompletionResponse getCompletionData(Id recordId) {
        try {
            if (recordId == null && !(Test.isRunningTest() && productIdOverride != null)) {
                throw new AuraHandledException('Record Id is required.');
            }

            Id productId = resolveProductId(recordId);
            String recordTypeDeveloperName = getProductRecordTypeDeveloperName(productId);
            String projectMode = resolveProjectMode(recordTypeDeveloperName);

            Map<String, Schema.SObjectField> productFieldsDescribe = getFieldDescribeMap(PRODUCT_OBJECT_API_NAME);
            Map<String, Schema.SObjectField> shareclassFieldsDescribe = getFieldDescribeMap(SHARECLASS_OBJECT_API_NAME);
            List<FieldConfig> configs = buildFieldConfigs(loadMetadataRows(), projectMode, productFieldsDescribe, shareclassFieldsDescribe);

            List<String> warnings = new List<String>();
            Set<String> productFieldsToQuery = collectFieldsToQuery(configs, PRODUCT_OBJECT_API_NAME);
            Set<String> shareclassFieldsToQuery = collectFieldsToQuery(configs, SHARECLASS_OBJECT_API_NAME);

            // Adds fields used only by DisplayCondition__c expressions.
            addConditionFieldsToQuery(configs, productFieldsToQuery, shareclassFieldsToQuery, productFieldsDescribe, shareclassFieldsDescribe);

            String productModifiedSourceField = projectMode == MODE_MODIFICATION
                ? getLocalSourceField(PRODUCT_MODIFIED_FIELDS_FIELD, PRODUCT_OBJECT_API_NAME, productFieldsDescribe, warnings)
                : null;
            String shareclassModifiedSourceField = projectMode == MODE_MODIFICATION
                ? getLocalSourceField(SHARECLASS_MODIFIED_FIELDS_FIELD, SHARECLASS_OBJECT_API_NAME, shareclassFieldsDescribe, warnings)
                : null;

            addSourceField(productFieldsToQuery, productModifiedSourceField);
            addSourceField(shareclassFieldsToQuery, shareclassModifiedSourceField);
            addShareclassIdentityFields(shareclassFieldsToQuery, shareclassFieldsDescribe);

            SObject productRecord = queryProductRecord(productId, productFieldsToQuery);
            List<SObject> shareclassRecords = queryShareclassRecords(productId, shareclassFieldsToQuery, shareclassFieldsDescribe);
            Set<String> modifiedProductFields = getModifiedFieldsFromRecord(productRecord, productModifiedSourceField, PRODUCT_OBJECT_API_NAME);
            Map<String, Set<String>> modifiedShareclassFieldsByRow = buildModifiedFieldsByRow(shareclassRecords, shareclassModifiedSourceField, SHARECLASS_OBJECT_API_NAME);

            return buildResponse(
                projectMode,
                recordTypeDeveloperName,
                warnings,
                configs,
                productRecord,
                shareclassRecords,
                modifiedProductFields,
                modifiedShareclassFieldsByRow,
                String.isNotBlank(productModifiedSourceField),
                String.isNotBlank(shareclassModifiedSourceField)
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load PRIIPs/KID completion: ' + e.getMessage());
        }
    }

    // Clears test overrides used to cover the calculation without org data inserts.
    @TestVisible
    private static void resetOverridesForTest() {
        productIdOverride = null;
        recordTypeDeveloperNameOverride = null;
        metadataRowsOverride = null;
        productRecordOverride = null;
        shareclassRecordsOverride = null;
    }

    // Resolves the Project Product Id from supported PMT record page contexts.
    private static Id resolveProductId(Id recordId) {
        if (Test.isRunningTest() && productIdOverride != null) {
            return productIdOverride;
        }

        String objectApiName = recordId.getSObjectType().getDescribe().getName();
        if (objectApiName == PRODUCT_OBJECT_API_NAME) {
            return recordId;
        }

        if (objectApiName == PRODUCT_CHILD_OBJECT_API_NAME) {
            String soql = 'SELECT ' + PRODUCT_CHILD_PARENT_FIELD + ' FROM ' + PRODUCT_CHILD_OBJECT_API_NAME + ' WHERE Id = :recordId LIMIT 1';
            SObject productChild = Database.query(soql);
            return (Id) productChild.get(PRODUCT_CHILD_PARENT_FIELD);
        }

        throw new AuraHandledException('Unsupported record page object: ' + objectApiName);
    }

    // Gets the product record type developer name to select the correct metadata flags.
    private static String getProductRecordTypeDeveloperName(Id productId) {
        if (Test.isRunningTest() && recordTypeDeveloperNameOverride != null) {
            return recordTypeDeveloperNameOverride;
        }

        String soql = 'SELECT RecordType.DeveloperName FROM ' + PRODUCT_OBJECT_API_NAME + ' WHERE Id = :productId LIMIT 1';
        SObject productRecord = Database.query(soql);
        SObject recordType = productRecord.getSObject('RecordType');
        return recordType == null ? '' : (String) recordType.get('DeveloperName');
    }

    // Converts a record type developer name into the functional project mode.
    @TestVisible
    private static String resolveProjectMode(String recordTypeDeveloperName) {
        String safeRecordType = String.isBlank(recordTypeDeveloperName) ? '' : recordTypeDeveloperName.toLowerCase();

        if (safeRecordType.contains('modification')) {
            return MODE_MODIFICATION;
        }
        if (safeRecordType.contains('shareclass') || safeRecordType.contains('share_class')) {
            return MODE_SHARECLASS_CREATION;
        }

        return MODE_PRODUCT_CREATION;
    }

    // Loads configured PRIIPs/KID fields from Custom Metadata.
    private static List<PRIIPSField__mdt> loadMetadataRows() {
        if (Test.isRunningTest() && metadataRowsOverride != null) {
            return metadataRowsOverride;
        }

        return [
            SELECT DeveloperName,
                   MasterLabel,
                   FieldApiName__c,
                   Team__c,
                   ProductCreation__c,
                   ShareclassCreation__c,
                   ProductShareModification__c,
                   DisplayCondition__c,
                   Required__c
            FROM PRIIPSField__mdt
            ORDER BY Team__c, MasterLabel
        ];
    }

    // Builds strongly typed field configs and skips invalid metadata rows safely.
    @TestVisible
    private static List<FieldConfig> buildFieldConfigs(
        List<PRIIPSField__mdt> metadataRows,
        String projectMode,
        Map<String, Schema.SObjectField> productFieldsDescribe,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        List<FieldConfig> configs = new List<FieldConfig>();

        for (PRIIPSField__mdt metadataRow : metadataRows) {
            if (!shouldDisplayForMode(metadataRow, projectMode)) {
                continue;
            }

            FieldReference reference = parseFieldReference(metadataRow.FieldApiName__c, productFieldsDescribe, shareclassFieldsDescribe);
            if (reference == null || String.isBlank(metadataRow.Team__c)) {
                continue;
            }

            FieldConfig config = new FieldConfig();
            config.objectApiName = reference.objectApiName;
            config.fieldApiName = reference.fieldApiName;
            config.fullFieldApiName = reference.objectApiName + '.' + reference.fieldApiName;
            config.team = metadataRow.Team__c;
            config.label = getDisplayLabel(metadataRow.MasterLabel, reference, productFieldsDescribe, shareclassFieldsDescribe);
            config.displayCondition = metadataRow.DisplayCondition__c;
            config.required = metadataRow.Required__c == true;
            config.key = makeColumnKey(config.fullFieldApiName);
            configs.add(config);
        }

        return configs;
    }

    // Applies the Custom Metadata flags for creation or modification projects.
    @TestVisible
    private static Boolean shouldDisplayForMode(PRIIPSField__mdt metadataRow, String projectMode) {
        if (projectMode == MODE_MODIFICATION) {
            return metadataRow.ProductShareModification__c == true;
        }
        if (projectMode == MODE_SHARECLASS_CREATION) {
            return metadataRow.ShareclassCreation__c == true;
        }

        return metadataRow.ProductCreation__c == true;
    }

    // Parses object-qualified or local field names from metadata.
    private static FieldReference parseFieldReference(
        String configuredFieldApiName,
        Map<String, Schema.SObjectField> productFieldsDescribe,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        if (String.isBlank(configuredFieldApiName)) {
            return null;
        }

        String safeField = configuredFieldApiName.trim();
        List<String> parts = safeField.split('\\.');
        if (parts.size() == 2) {
            return buildReference(parts[0].trim(), parts[1].trim(), productFieldsDescribe, shareclassFieldsDescribe);
        }
        if (parts.size() == 1) {
            return inferReferenceFromLocalField(safeField, productFieldsDescribe, shareclassFieldsDescribe);
        }

        return null;
    }

    // Creates a field reference only when the object and field are readable.
    private static FieldReference buildReference(
        String objectApiName,
        String fieldApiName,
        Map<String, Schema.SObjectField> productFieldsDescribe,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        if (objectApiName == PRODUCT_OBJECT_API_NAME && isReadableField(fieldApiName, productFieldsDescribe)) {
            return createReference(PRODUCT_OBJECT_API_NAME, fieldApiName);
        }
        if (objectApiName == SHARECLASS_OBJECT_API_NAME && isReadableField(fieldApiName, shareclassFieldsDescribe)) {
            return createReference(SHARECLASS_OBJECT_API_NAME, fieldApiName);
        }

        return null;
    }

    // Infers the object when metadata contains only the local field API name.
    private static FieldReference inferReferenceFromLocalField(
        String fieldApiName,
        Map<String, Schema.SObjectField> productFieldsDescribe,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        if (isReadableField(fieldApiName, productFieldsDescribe)) {
            return createReference(PRODUCT_OBJECT_API_NAME, fieldApiName);
        }
        if (isReadableField(fieldApiName, shareclassFieldsDescribe)) {
            return createReference(SHARECLASS_OBJECT_API_NAME, fieldApiName);
        }

        return null;
    }

    // Creates a lightweight field reference object.
    private static FieldReference createReference(String objectApiName, String fieldApiName) {
        FieldReference reference = new FieldReference();
        reference.objectApiName = objectApiName;
        reference.fieldApiName = fieldApiName;
        return reference;
    }

    // Gets the display label from metadata first, then from the field describe.
    private static String getDisplayLabel(
        String metadataLabel,
        FieldReference reference,
        Map<String, Schema.SObjectField> productFieldsDescribe,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        if (String.isNotBlank(metadataLabel)) {
            return metadataLabel;
        }

        Map<String, Schema.SObjectField> fieldsDescribe = reference.objectApiName == PRODUCT_OBJECT_API_NAME
            ? productFieldsDescribe
            : shareclassFieldsDescribe;
        return fieldsDescribe.get(reference.fieldApiName).getDescribe().getLabel();
    }

    // Gets a readable field describe map for the given object API name.
    private static Map<String, Schema.SObjectField> getFieldDescribeMap(String objectApiName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null || !objectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Object is not accessible: ' + objectApiName);
        }

        return objectType.getDescribe().fields.getMap();
    }

    // Checks field existence and field-level read access.
    private static Boolean isReadableField(String fieldApiName, Map<String, Schema.SObjectField> fieldsDescribe) {
        if (String.isBlank(fieldApiName) || !fieldsDescribe.containsKey(fieldApiName)) {
            return false;
        }

        return fieldsDescribe.get(fieldApiName).getDescribe().isAccessible();
    }

    // Collects fields needed by the dynamic SOQL query for one object.
    private static Set<String> collectFieldsToQuery(List<FieldConfig> configs, String objectApiName) {
        Set<String> fieldNames = new Set<String>{ 'Id' };

        for (FieldConfig config : configs) {
            if (config.objectApiName == objectApiName) {
                fieldNames.add(config.fieldApiName);
            }
        }

        return fieldNames;
    }

    // Adds standard row identity fields to every shareclass query.
    private static void addShareclassIdentityFields(Set<String> fieldNames, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        for (String identityField : SHARECLASS_IDENTITY_FIELDS) {
            if (isReadableField(identityField, shareclassFieldsDescribe)) {
                fieldNames.add(identityField);
            }
        }
    }

    // Adds an optional source field to the dynamic SOQL query.
    private static void addSourceField(Set<String> fieldNames, String sourceFieldApiName) {
        if (String.isNotBlank(sourceFieldApiName)) {
            fieldNames.add(sourceFieldApiName);
        }
    }

    // Validates a configured source field and returns its local API name.
    private static String getLocalSourceField(
        String configuredSourceField,
        String objectApiName,
        Map<String, Schema.SObjectField> fieldsDescribe,
        List<String> warnings
    ) {
        if (String.isBlank(configuredSourceField)) {
            return null;
        }

        String safeField = configuredSourceField.trim();
        List<String> parts = safeField.split('\\.');
        String localField = parts.size() == 2 && parts[0] == objectApiName ? parts[1] : safeField;

        if (isReadableField(localField, fieldsDescribe)) {
            return localField;
        }

        warnings.add('Invalid modified-fields source: ' + configuredSourceField);
        return null;
    }

    // Queries the Project Product record with only fields required by the UI.
    private static SObject queryProductRecord(Id productId, Set<String> fieldNames) {
        if (Test.isRunningTest() && productRecordOverride != null) {
            return productRecordOverride;
        }

        String soql = 'SELECT ' + String.join(sortFieldNames(fieldNames), ',') +
            ' FROM ' + PRODUCT_OBJECT_API_NAME + ' WHERE Id = :productId LIMIT 1';
        List<SObject> records = Database.query(soql);

        if (records.isEmpty()) {
            throw new AuraHandledException('Project Product not found.');
        }
        return records[0];
    }

    // Queries all shareclass records linked to the current Project Product.
    private static List<SObject> queryShareclassRecords(
        Id productId,
        Set<String> fieldNames,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        if (Test.isRunningTest() && shareclassRecordsOverride != null) {
            return shareclassRecordsOverride;
        }

        if (!isReadableField(DEFAULT_SHARECLASS_LOOKUP_FIELD, shareclassFieldsDescribe)) {
            throw new AuraHandledException('Invalid Shareclass lookup field: ' + DEFAULT_SHARECLASS_LOOKUP_FIELD);
        }

        fieldNames.add(DEFAULT_SHARECLASS_LOOKUP_FIELD);
        String soql = 'SELECT ' + String.join(sortFieldNames(fieldNames), ',') +
            ' FROM ' + SHARECLASS_OBJECT_API_NAME + ' WHERE ' + DEFAULT_SHARECLASS_LOOKUP_FIELD + ' = :productId ORDER BY Name';
        return Database.query(soql);
    }

    // Sorts field names to keep dynamic SOQL stable.
    private static List<String> sortFieldNames(Set<String> fieldNames) {
        List<String> sortedFields = new List<String>(fieldNames);
        sortedFields.sort();
        return sortedFields;
    }

    // Parses semicolon, comma, or line-break lists of modified fields.
    @TestVisible
    private static Set<String> parseModifiedFields(String rawValue, String objectApiName) {
        Set<String> modifiedFields = new Set<String>();
        if (String.isBlank(rawValue)) {
            return modifiedFields;
        }

        String normalizedValue = rawValue.replace(',', ';').replace('\n', ';').replace('\r', ';');
        for (String token : normalizedValue.split(';')) {
            String cleanToken = token.trim();
            if (String.isBlank(cleanToken)) {
                continue;
            }

            modifiedFields.add(cleanToken);
            if (cleanToken.contains('.')) {
                List<String> parts = cleanToken.split('\\.');
                if (parts.size() == 2 && parts[0] == objectApiName) {
                    modifiedFields.add(parts[1]);
                }
            } else {
                modifiedFields.add(objectApiName + '.' + cleanToken);
            }
        }

        return modifiedFields;
    }

    // Reads a modified-fields source value from one record.
    private static Set<String> getModifiedFieldsFromRecord(SObject record, String sourceFieldApiName, String objectApiName) {
        if (String.isBlank(sourceFieldApiName)) {
            return new Set<String>();
        }

        Object rawValue = getSObjectValue(record, sourceFieldApiName);
        String rawText = rawValue == null ? null : String.valueOf(rawValue);
        return parseModifiedFields(rawText, objectApiName);
    }

    // Builds a row-keyed map of selected fields for shareclass modification projects.
    private static Map<String, Set<String>> buildModifiedFieldsByRow(
        List<SObject> records,
        String sourceFieldApiName,
        String objectApiName
    ) {
        Map<String, Set<String>> modifiedFieldsByRow = new Map<String, Set<String>>();
        if (String.isBlank(sourceFieldApiName)) {
            return modifiedFieldsByRow;
        }

        for (Integer index = 0; index < records.size(); index++) {
            SObject record = records[index];
            modifiedFieldsByRow.put(getRowKey(record, index), getModifiedFieldsFromRecord(record, sourceFieldApiName, objectApiName));
        }

        return modifiedFieldsByRow;
    }

    // Builds the final DTO consumed by the LWC.
    private static CompletionResponse buildResponse(
        String projectMode,
        String recordTypeDeveloperName,
        List<String> warnings,
        List<FieldConfig> configs,
        SObject productRecord,
        List<SObject> shareclassRecords,
        Set<String> modifiedProductFields,
        Map<String, Set<String>> modifiedShareclassFieldsByRow,
        Boolean useProductModifiedSource,
        Boolean useShareclassModifiedSource
    ) {
        CompletionResponse response = new CompletionResponse();
        response.projectMode = projectMode;
        response.projectRecordType = recordTypeDeveloperName;
        response.warningMessage = warnings.isEmpty() ? null : String.join(warnings, ' ');

        Map<String, TeamCompletion> teamsByName = new Map<String, TeamCompletion>();
        addProductDetails(teamsByName, configs, productRecord, modifiedProductFields, useProductModifiedSource, projectMode);
        addShareclassDetails(teamsByName, configs, productRecord, shareclassRecords, modifiedShareclassFieldsByRow, useShareclassModifiedSource, projectMode);
        response.teams = sortTeams(teamsByName);
        return response;
    }

    // Adds one product-level detail line per team.
    private static void addProductDetails(
        Map<String, TeamCompletion> teamsByName,
        List<FieldConfig> configs,
        SObject productRecord,
        Set<String> modifiedProductFields,
        Boolean useProductModifiedSource,
        String projectMode
    ) {
        Map<String, List<FieldConfig>> configsByTeam = groupConfigsByTeam(configs, PRODUCT_OBJECT_API_NAME);

        for (String teamName : configsByTeam.keySet()) {
            List<FieldConfig> selectedConfigs = new List<FieldConfig>();
            for (FieldConfig config : configsByTeam.get(teamName)) {
                // Completion is calculated only on mandatory PRIIPs fields.
                if (!config.required) {
                    continue;
                }

                if (projectMode == MODE_MODIFICATION && useProductModifiedSource && !fieldWasSelected(modifiedProductFields, config)) {
                    continue;
                }

                // Ignores the field when its DisplayCondition__c evaluates to false.
                if (!shouldDisplayByCondition(config, productRecord, null)) {
                    continue;
                }

                selectedConfigs.add(config);
            }

            CompletionDetail detail = calculateDetail('Produit', productRecord, selectedConfigs, 'product');
            if (detail.total > 0) {
                addDetailToTeam(getOrCreateTeam(teamsByName, teamName), detail);
            }
        }
    }

    // Adds one shareclass detail line per team and per shareclass row.
    private static void addShareclassDetails(
        Map<String, TeamCompletion> teamsByName,
        List<FieldConfig> configs,
        SObject productRecord,
        List<SObject> shareclassRecords,
        Map<String, Set<String>> modifiedShareclassFieldsByRow,
        Boolean useShareclassModifiedSource,
        String projectMode
    ) {
        Map<String, List<FieldConfig>> configsByTeam = groupConfigsByTeam(configs, SHARECLASS_OBJECT_API_NAME);

        for (String teamName : configsByTeam.keySet()) {
            for (Integer index = 0; index < shareclassRecords.size(); index++) {
                SObject shareclassRecord = shareclassRecords[index];
                Set<String> modifiedFields = modifiedShareclassFieldsByRow.get(getRowKey(shareclassRecord, index));
                List<FieldConfig> selectedConfigs = new List<FieldConfig>();

                for (FieldConfig config : configsByTeam.get(teamName)) {
                    if (projectMode == MODE_MODIFICATION && useShareclassModifiedSource && !fieldWasSelected(modifiedFields, config)) {
                        continue;
                    }

                    // Ignores the field for this row when its DisplayCondition__c is false.
                    if (!shouldDisplayByCondition(config, productRecord, shareclassRecord)) {
                        continue;
                    }

                    selectedConfigs.add(config);
                }

                CompletionDetail detail = calculateDetail(getShareclassDisplayName(shareclassRecord, index), shareclassRecord, selectedConfigs, getRowKey(shareclassRecord, index));
                if (detail.total > 0) {
                    addDetailToTeam(getOrCreateTeam(teamsByName, teamName), detail);
                }
            }
        }
    }


    // Adds all fields referenced by DisplayCondition__c to the dynamic SOQL queries.
    private static void addConditionFieldsToQuery(
        List<FieldConfig> configs,
        Set<String> productFieldsToQuery,
        Set<String> shareclassFieldsToQuery,
        Map<String, Schema.SObjectField> productFieldsDescribe,
        Map<String, Schema.SObjectField> shareclassFieldsDescribe
    ) {
        Pattern fieldPattern = Pattern.compile('(ProjectProduct__c|ProjectShareclass__c)\\.([a-zA-Z0-9_]+)');

        for (FieldConfig config : configs) {
            if (String.isBlank(config.displayCondition)) {
                continue;
            }

            Matcher matcher = fieldPattern.matcher(config.displayCondition);
            while (matcher.find()) {
                String objectApiName = matcher.group(1);
                String fieldApiName = matcher.group(2);

                // Adds only valid readable fields to avoid dynamic SOQL errors.
                if (objectApiName == PRODUCT_OBJECT_API_NAME && isReadableField(fieldApiName, productFieldsDescribe)) {
                    productFieldsToQuery.add(fieldApiName);
                }
                if (objectApiName == SHARECLASS_OBJECT_API_NAME && isReadableField(fieldApiName, shareclassFieldsDescribe)) {
                    shareclassFieldsToQuery.add(fieldApiName);
                }
            }
        }
    }

    // Evaluates DisplayCondition__c against the current Product and Shareclass records.
    private static Boolean shouldDisplayByCondition(
        FieldConfig config,
        SObject productRecord,
        SObject shareclassRecord
    ) {
        if (String.isBlank(config.displayCondition)) {
            return true;
        }

        return evaluateDisplayCondition(config.displayCondition, productRecord, shareclassRecord);
    }

    // Evaluates a simple expression with || and && operators.
    private static Boolean evaluateDisplayCondition(
        String expression,
        SObject productRecord,
        SObject shareclassRecord
    ) {
        for (String orPart : expression.split('\\|\\|')) {
            if (evaluateAndConditionGroup(orPart, productRecord, shareclassRecord)) {
                return true;
            }
        }

        return false;
    }

    // Evaluates all && conditions inside one expression group.
    private static Boolean evaluateAndConditionGroup(
        String expressionGroup,
        SObject productRecord,
        SObject shareclassRecord
    ) {
        for (String token : expressionGroup.split('&&')) {
            if (!evaluateConditionToken(token, productRecord, shareclassRecord)) {
                return false;
            }
        }

        return true;
    }

    // Evaluates one condition token: =, !=, ISBLANK(), or !ISBLANK().
    private static Boolean evaluateConditionToken(
        String rawToken,
        SObject productRecord,
        SObject shareclassRecord
    ) {
        String token = String.isBlank(rawToken) ? '' : rawToken.trim();
        if (String.isBlank(token)) {
            return true;
        }

        if (token.startsWith('ISBLANK(') && token.endsWith(')')) {
            String fieldReference = token.substring('ISBLANK('.length(), token.length() - 1);
            return isBlankConditionValue(getConditionValue(fieldReference, productRecord, shareclassRecord));
        }

        if (token.startsWith('!ISBLANK(') && token.endsWith(')')) {
            String fieldReference = token.substring('!ISBLANK('.length(), token.length() - 1);
            return !isBlankConditionValue(getConditionValue(fieldReference, productRecord, shareclassRecord));
        }

        Integer notEqualsIndex = token.indexOf('!=');
        if (notEqualsIndex >= 0) {
            String fieldReference = token.substring(0, notEqualsIndex).trim();
            String expectedValue = normalizeExpectedValue(token.substring(notEqualsIndex + 2));
            Object actualValue = getConditionValue(fieldReference, productRecord, shareclassRecord);
            return String.valueOf(actualValue) != expectedValue;
        }

        Integer equalsIndex = token.indexOf('=');
        if (equalsIndex >= 0) {
            String fieldReference = token.substring(0, equalsIndex).trim();
            String expectedValue = normalizeExpectedValue(token.substring(equalsIndex + 1));
            Object actualValue = getConditionValue(fieldReference, productRecord, shareclassRecord);
            return String.valueOf(actualValue) == expectedValue;
        }

        return false;
    }

    // Reads the field value referenced by a DisplayCondition__c expression.
    private static Object getConditionValue(
        String fieldReference,
        SObject productRecord,
        SObject shareclassRecord
    ) {
        String safeReference = String.isBlank(fieldReference) ? '' : fieldReference.trim();

        if (safeReference.startsWith(PRODUCT_OBJECT_API_NAME + '.')) {
            String fieldApiName = safeReference.substring((PRODUCT_OBJECT_API_NAME + '.').length());
            return getSObjectValue(productRecord, fieldApiName);
        }

        if (safeReference.startsWith(SHARECLASS_OBJECT_API_NAME + '.')) {
            String fieldApiName = safeReference.substring((SHARECLASS_OBJECT_API_NAME + '.').length());
            return getSObjectValue(shareclassRecord, fieldApiName);
        }

        return null;
    }

    // Returns true when a condition value is empty.
    private static Boolean isBlankConditionValue(Object value) {
        return value == null || String.isBlank(String.valueOf(value));
    }

    // Normalizes string literals used in DisplayCondition__c.
    private static String normalizeExpectedValue(String rawValue) {
        String value = String.isBlank(rawValue) ? '' : rawValue.trim();

        if ((value.startsWith('\'') && value.endsWith('\'')) ||
            (value.startsWith('"') && value.endsWith('"'))) {
            return value.substring(1, value.length() - 1);
        }

        return value;
    }

    // Groups field configs by team for the requested object.
    private static Map<String, List<FieldConfig>> groupConfigsByTeam(List<FieldConfig> configs, String objectApiName) {
        Map<String, List<FieldConfig>> configsByTeam = new Map<String, List<FieldConfig>>();

        for (FieldConfig config : configs) {
            if (config.objectApiName != objectApiName) {
                continue;
            }
            if (!configsByTeam.containsKey(config.team)) {
                configsByTeam.put(config.team, new List<FieldConfig>());
            }
            configsByTeam.get(config.team).add(config);
        }

        return configsByTeam;
    }

    // Calculates completed and expected fields for one detail line.
    private static CompletionDetail calculateDetail(String label, SObject record, List<FieldConfig> configs, String keySuffix) {
        CompletionDetail detail = new CompletionDetail();
        detail.label = label;
        detail.key = makeSafeKey(label + '_' + keySuffix);
        detail.total = configs.size();

        for (FieldConfig config : configs) {
            if (hasCompletionValue(record, config.fieldApiName)) {
                detail.completed++;
            }
        }

        applyPercentageAndStatus(detail);
        return detail;
    }

    // Adds a detail line to a team and updates the aggregated team ratio.
    private static void addDetailToTeam(TeamCompletion team, CompletionDetail detail) {
        team.details.add(detail);
        team.completed += detail.completed;
        team.total += detail.total;
        applyPercentageAndStatus(team);
    }

    // Gets or creates the aggregated completion row for one team.
    private static TeamCompletion getOrCreateTeam(Map<String, TeamCompletion> teamsByName, String teamName) {
        if (!teamsByName.containsKey(teamName)) {
            TeamCompletion team = new TeamCompletion();
            team.name = teamName;
            team.key = makeSafeKey(teamName);
            teamsByName.put(teamName, team);
        }

        return teamsByName.get(teamName);
    }

    // Applies percentage and traffic-light status to a team row.
    private static void applyPercentageAndStatus(TeamCompletion team) {
        team.percentage = calculatePercentage(team.completed, team.total);
        team.status = calculateStatus(team.percentage);
    }

    // Applies percentage and traffic-light status to a detail row.
    private static void applyPercentageAndStatus(CompletionDetail detail) {
        detail.percentage = calculatePercentage(detail.completed, detail.total);
        detail.status = calculateStatus(detail.percentage);
    }

    // Calculates a rounded percentage from completed and expected counts.
    private static Integer calculatePercentage(Integer completed, Integer total) {
        if (total == null || total == 0) {
            return 0;
        }

        Decimal value = (Decimal.valueOf(completed) / Decimal.valueOf(total)) * 100;
        return Integer.valueOf(String.valueOf(Math.round(value)));
    }

    // Converts a percentage into the color status expected by the LWC.
    private static String calculateStatus(Integer percentage) {
        if (percentage == null || percentage < 50) {
            return 'red';
        }
        if (percentage < 80) {
            return 'orange';
        }

        return 'green';
    }

    // Checks whether a field is in the modification selection for the current record.
    private static Boolean fieldWasSelected(Set<String> selectedFields, FieldConfig config) {
        return selectedFields != null &&
            (selectedFields.contains(config.fieldApiName) || selectedFields.contains(config.fullFieldApiName));
    }

    // Returns true when a field value counts as completed.
    private static Boolean hasCompletionValue(SObject record, String fieldApiName) {
        Object value = getSObjectValue(record, fieldApiName);
        if (value == null) {
            return false;
        }
        if (value instanceof String) {
            return String.isNotBlank((String) value);
        }

        return true;
    }

    // Safely reads a field value from queried or test-created SObjects.
    private static Object getSObjectValue(SObject record, String fieldApiName) {
        try {
            return record == null || String.isBlank(fieldApiName) ? null : record.get(fieldApiName);
        } catch (Exception e) {
            return null;
        }
    }

    // Gets a readable shareclass label for the detail area.
    private static String getShareclassDisplayName(SObject shareclassRecord, Integer rowIndex) {
        for (String identityField : SHARECLASS_IDENTITY_FIELDS) {
            Object value = getSObjectValue(shareclassRecord, identityField);
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }

        return 'Shareclass ' + String.valueOf(rowIndex + 1);
    }

    // Returns a stable key for detail rows even in tests without persisted records.
    private static String getRowKey(SObject record, Integer rowIndex) {
        Object idValue = getSObjectValue(record, 'Id');
        return idValue == null ? 'row-' + String.valueOf(rowIndex) : String.valueOf(idValue);
    }

    // Sorts teams using the expected PMT team order, then by team name.
    private static List<TeamCompletion> sortTeams(Map<String, TeamCompletion> teamsByName) {
        List<String> sortableKeys = new List<String>();
        Map<String, TeamCompletion> sortableKeyToTeam = new Map<String, TeamCompletion>();

        for (String teamName : teamsByName.keySet()) {
            String sortableKey = String.valueOf(100 + getTeamOrder(teamName)) + '|' + teamName;
            sortableKeys.add(sortableKey);
            sortableKeyToTeam.put(sortableKey, teamsByName.get(teamName));
        }

        sortableKeys.sort();
        List<TeamCompletion> sortedTeams = new List<TeamCompletion>();
        for (String sortableKey : sortableKeys) {
            sortedTeams.add(sortableKeyToTeam.get(sortableKey));
        }

        return sortedTeams;
    }

    // Returns the configured team order index or a default value for unknown teams.
    private static Integer getTeamOrder(String teamName) {
        for (Integer index = 0; index < TEAM_ORDER.size(); index++) {
            if (TEAM_ORDER[index] == teamName) {
                return index;
            }
        }

        return 99;
    }

    // Creates a safe key for accordion sections and UI loops.
    private static String makeSafeKey(String value) {
        String safeValue = String.isBlank(value) ? 'Unknown' : value.trim();
        return safeValue.replaceAll('[^a-zA-Z0-9_]', '_');
    }

    // Creates a UI-compatible key from an object-qualified field API name.
    private static String makeColumnKey(String value) {
        return makeSafeKey(value);
    }
}
