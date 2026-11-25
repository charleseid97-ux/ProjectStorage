/** ──────────────────────────────────────
 * @description Shared utility class for the PRIIPs/KID completion widgets.
 *              Provides common functionality for resolving project mode and scope (PS/IS), parsing PRIIPSField__mdt
 *                  configuration into typed field configs, evaluating DisplayCondition__c expressions, and
 *                  reading/formatting record field values for both the detail view and completion calculation.
 *              Extracted from PRIIPSKidController and PRIIPSKidCompletionController, which independently
 *                  duplicated this exact set of helpers - single source of truth for both.
 * @author EL HITARY Achraf
 * @lastModifiedBy Charles EID   [05-10-26]
 * @testClass PRIIPSKidControllerTest, PRIIPSKidCompletionControllerTest
 * @coverage 92% (Combined coverage across both test classes)   [05-10-26]
 ────────────────────────────────────── */
public with sharing class PRIIPSKidHelper {
    public static final String PRODUCT_OBJECT_API_NAME = 'ProjectProduct__c';
    public static final String PRODUCT_CHILD_OBJECT_API_NAME = 'ProjectProductChild__c';
    public static final String SHARECLASS_OBJECT_API_NAME = 'ProjectShareclass__c';
    public static final String PRODUCT_CHILD_PARENT_FIELD = 'ProjectProductParent__c';
    public static final String DEFAULT_SHARECLASS_LOOKUP_FIELD = 'ProjectProduct__c';
    public static final String PRODUCT_MODIFIED_FIELDS_FIELD = 'TECH_FieldsToModify__c';
    public static final String SHARECLASS_MODIFIED_FIELDS_FIELD = 'TECH_FieldsToModify__c';
    public static final String MODE_PRODUCT_CREATION = 'Product Creation';
    public static final String MODE_SHARECLASS_CREATION = 'Shareclass Creation';
    public static final String MODE_MODIFICATION = 'Modification';

    public static final List<String> SHARECLASS_IDENTITY_FIELDS = new List<String>{'Name__c', 'Share_Class_Name__c', 'Name', 'ISIN__c'};

    public static final List<String> TEAM_ORDER = new List<String>{'Product Strategy', 'Investment Solutions', 'Investment Performance', 'Operations', 'Legal', 'Risk Management'};

    // US-20120: display name used in place of a "Product Strategy" PRIIPSField__mdt row's
    // team when the project's Scope__c is IS and the row opted in via OtherTeams__c.
    public static final String INVESTMENT_SOLUTIONS_TEAM = 'Investment Solutions';
    public static final String PRODUCT_STRATEGY_TEAM = 'Product Strategy';
    public static final String SCOPE_IS = 'IS';

    public class FieldReference {
        public String objectApiName;
        public String fieldApiName;
    }

    public class FieldConfig {
        public String key;
        public String fullFieldApiName;
        public String objectApiName;
        public String fieldApiName;
        public String team;
        public String label;
        public String displayCondition;
        public String exactValue;
        public Boolean required;
    }

    // Converts a record type developer name into the functional project mode.
    public static String resolveProjectMode(String recordTypeDeveloperName) {
        String safeRecordType = String.isBlank(recordTypeDeveloperName) ? '' : recordTypeDeveloperName.toLowerCase();

        if (safeRecordType.contains('modification')) return MODE_MODIFICATION;
        if (safeRecordType.contains('shareclass') || safeRecordType.contains('share_class')) return MODE_SHARECLASS_CREATION;

        return MODE_PRODUCT_CREATION;
    }

    // US-20120: a "Product Strategy" row also applies to Investment Solutions when its semicolon-delimited OtherTeams__c list names it - scales to future teams with no schema change.
    public static Boolean appliesToTeam(String delimitedTeams, String teamName) {
        if (String.isBlank(delimitedTeams)) return false;
        for (String team : delimitedTeams.split(';')) {
            if (team.trim().equalsIgnoreCase(teamName)) return true;
        }
        return false;
    }

    // Builds strongly typed field configs and skips invalid metadata rows safely.
    public static List<FieldConfig> buildFieldConfigs(List<PRIIPSField__mdt> metadataRows, String projectMode, String projectScope, Map<String, Schema.SObjectField> productFieldsDescribe, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        List<FieldConfig> configs = new List<FieldConfig>();

        for (PRIIPSField__mdt metadataRow : metadataRows) {
            if (!shouldDisplayForMode(metadataRow, projectMode)) continue;

            FieldReference reference = parseFieldReference(metadataRow.FieldApiName__c, productFieldsDescribe, shareclassFieldsDescribe);
            if (reference == null || String.isBlank(metadataRow.Team__c)) continue;

            // US-20120: for an IS-scoped project, only "Product Strategy" rows that opted in via OtherTeams__c are shown, rendered under "Investment Solutions" instead.
            String effectiveTeam = metadataRow.Team__c;
            if (projectScope == SCOPE_IS && effectiveTeam == PRODUCT_STRATEGY_TEAM) {
                if (!appliesToTeam(metadataRow.OtherTeams__c, INVESTMENT_SOLUTIONS_TEAM)) continue;
                effectiveTeam = INVESTMENT_SOLUTIONS_TEAM;
            }

            FieldConfig config = new FieldConfig();
            config.objectApiName = reference.objectApiName;
            config.fieldApiName = reference.fieldApiName;
            config.fullFieldApiName = reference.objectApiName + '.' + reference.fieldApiName;
            config.team = effectiveTeam;
            config.label = getDisplayLabel(metadataRow.MasterLabel, reference, productFieldsDescribe, shareclassFieldsDescribe);
            config.displayCondition = metadataRow.DisplayCondition__c;
            config.exactValue = metadataRow.ExactValue__c;
            config.required = metadataRow.Required__c == true;
            config.key = makeColumnKey(config.fullFieldApiName);
            configs.add(config);
        }

        return configs;
    }

    // Applies the Custom Metadata flags for creation or modification projects.
    public static Boolean shouldDisplayForMode(PRIIPSField__mdt metadataRow, String projectMode) {
        if (projectMode == MODE_MODIFICATION) return metadataRow.ProductShareModification__c == true;
        if (projectMode == MODE_SHARECLASS_CREATION) return metadataRow.ShareclassCreation__c == true;
        return metadataRow.ProductCreation__c == true;
    }

    // Parses object-qualified or local field names from metadata.
    public static FieldReference parseFieldReference(String configuredFieldApiName, Map<String, Schema.SObjectField> productFieldsDescribe, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        if (String.isBlank(configuredFieldApiName)) return null;

        String safeField = configuredFieldApiName.trim();
        List<String> parts = safeField.split('\\.');
        if (parts.size() == 2) return buildReference(parts[0].trim(), parts[1].trim(), productFieldsDescribe, shareclassFieldsDescribe);
        if (parts.size() == 1) return inferReferenceFromLocalField(safeField, productFieldsDescribe, shareclassFieldsDescribe);

        return null;
    }

    // Creates a field reference only when the object and field are readable.
    public static FieldReference buildReference(String objectApiName, String fieldApiName, Map<String, Schema.SObjectField> productFieldsDescribe, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        if (objectApiName == PRODUCT_OBJECT_API_NAME && isReadableField(fieldApiName, productFieldsDescribe)) return createReference(PRODUCT_OBJECT_API_NAME, fieldApiName);
        if (objectApiName == SHARECLASS_OBJECT_API_NAME && isReadableField(fieldApiName, shareclassFieldsDescribe)) return createReference(SHARECLASS_OBJECT_API_NAME, fieldApiName);
        return null;
    }

    // Infers the object when metadata contains only the local field API name.
    public static FieldReference inferReferenceFromLocalField(String fieldApiName, Map<String, Schema.SObjectField> productFieldsDescribe, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        if (isReadableField(fieldApiName, productFieldsDescribe)) return createReference(PRODUCT_OBJECT_API_NAME, fieldApiName);
        if (isReadableField(fieldApiName, shareclassFieldsDescribe)) return createReference(SHARECLASS_OBJECT_API_NAME, fieldApiName);
        return null;
    }

    // Creates a lightweight field reference object.
    public static FieldReference createReference(String objectApiName, String fieldApiName) {
        FieldReference reference = new FieldReference();
        reference.objectApiName = objectApiName;
        reference.fieldApiName = fieldApiName;
        return reference;
    }

    // Gets the display label from metadata first, then from the field describe.
    public static String getDisplayLabel(String metadataLabel, FieldReference reference, Map<String, Schema.SObjectField> productFieldsDescribe, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        if (String.isNotBlank(metadataLabel)) return metadataLabel;

        Map<String, Schema.SObjectField> fieldsDescribe = reference.objectApiName == PRODUCT_OBJECT_API_NAME ? productFieldsDescribe : shareclassFieldsDescribe;
        return fieldsDescribe.get(reference.fieldApiName).getDescribe().getLabel();
    }

    // Gets a readable field describe map for the given object API name.
    public static Map<String, Schema.SObjectField> getFieldDescribeMap(String objectApiName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null || !objectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Object is not accessible: ' + objectApiName);
        }

        return objectType.getDescribe().fields.getMap();
    }

    // Checks field existence and field-level read access.
    public static Boolean isReadableField(String fieldApiName, Map<String, Schema.SObjectField> fieldsDescribe) {
        if (String.isBlank(fieldApiName) || !fieldsDescribe.containsKey(fieldApiName)) return false;

        return fieldsDescribe.get(fieldApiName).getDescribe().isAccessible();
    }

    // Collects fields needed by the dynamic SOQL query for one object.
    public static Set<String> collectFieldsToQuery(List<FieldConfig> configs, String objectApiName) {
        Set<String> fieldNames = new Set<String>{ 'Id' };

        for (FieldConfig config : configs) {
            if (config.objectApiName == objectApiName) fieldNames.add(config.fieldApiName);
        }

        return fieldNames;
    }

    // Adds standard row identity fields to every Shareclass query.
    public static void addShareclassIdentityFields(Set<String> fieldNames, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        for (String identityField : SHARECLASS_IDENTITY_FIELDS) {
            if (isReadableField(identityField, shareclassFieldsDescribe)) fieldNames.add(identityField);
        }
    }

    // Adds all fields referenced by DisplayCondition__c to the dynamic SOQL queries.
    public static void addConditionFieldsToQuery(List<FieldConfig> configs, Set<String> productFieldsToQuery, Set<String> shareclassFieldsToQuery, Map<String, Schema.SObjectField> productFieldsDescribe, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        Pattern fieldPattern = Pattern.compile('(ProjectProduct__c|ProjectShareclass__c)\\.([a-zA-Z0-9_]+)');

        for (FieldConfig config : configs) {
            if (String.isBlank(config.displayCondition)) continue;

            Matcher matcher = fieldPattern.matcher(config.displayCondition);
            while (matcher.find()) {
                String objectApiName = matcher.group(1);
                String fieldApiName = matcher.group(2);

                // Adds only valid readable fields to avoid dynamic SOQL errors.
                if (objectApiName == PRODUCT_OBJECT_API_NAME && isReadableField(fieldApiName, productFieldsDescribe)) productFieldsToQuery.add(fieldApiName);
                if (objectApiName == SHARECLASS_OBJECT_API_NAME && isReadableField(fieldApiName, shareclassFieldsDescribe)) shareclassFieldsToQuery.add(fieldApiName);
            }
        }
    }

    // Adds an optional source field to the dynamic SOQL query.
    public static void addSourceField(Set<String> fieldNames, String sourceFieldApiName) {
        if (String.isNotBlank(sourceFieldApiName)) fieldNames.add(sourceFieldApiName);
    }

    // Validates a configured source field and returns its local API name.
    public static String getLocalSourceField(String configuredSourceField, String objectApiName, Map<String, Schema.SObjectField> fieldsDescribe, List<String> warnings) {
        if (String.isBlank(configuredSourceField)) return null;

        String safeField = configuredSourceField.trim();
        List<String> parts = safeField.split('\\.');
        String localField = parts.size() == 2 && parts[0] == objectApiName ? parts[1] : safeField;

        if (isReadableField(localField, fieldsDescribe)) return localField;

        warnings.add('Invalid modified-fields source: ' + configuredSourceField);
        return null;
    }

    // Sorts field names to keep dynamic SOQL stable.
    public static List<String> sortFieldNames(Set<String> fieldNames) {
        List<String> sortedFields = new List<String>(fieldNames);
        sortedFields.sort();
        return sortedFields;
    }

    // Parses semicolon, comma, or line-break lists of modified fields.
    public static Set<String> parseModifiedFields(String rawValue, String objectApiName) {
        Set<String> modifiedFields = new Set<String>();
        if (String.isBlank(rawValue)) return modifiedFields;

        String normalizedValue = rawValue.replace(',', ';').replace('\n', ';').replace('\r', ';');
        for (String token : normalizedValue.split(';')) {
            String cleanToken = token.trim();
            if (String.isBlank(cleanToken)) continue;

            modifiedFields.add(cleanToken);
            if (cleanToken.contains('.')) {
                List<String> parts = cleanToken.split('\\.');
                if (parts.size() == 2 && parts[0] == objectApiName) modifiedFields.add(parts[1]);
            }
            else {
                modifiedFields.add(objectApiName + '.' + cleanToken);
            }
        }

        return modifiedFields;
    }

    // Reads a modified-fields source value from one record.
    public static Set<String> getModifiedFieldsFromRecord(SObject record, String sourceFieldApiName, String objectApiName) {
        if (String.isBlank(sourceFieldApiName)) return new Set<String>();

        Object rawValue = getSObjectValue(record, sourceFieldApiName);
        String rawText = rawValue == null ? null : String.valueOf(rawValue);
        return parseModifiedFields(rawText, objectApiName);
    }

    // Builds a row-keyed map of selected fields for Shareclass modification projects.
    public static Map<String, Set<String>> buildModifiedFieldsByRow(List<SObject> records, String sourceFieldApiName, String objectApiName) {
        Map<String, Set<String>> modifiedFieldsByRow = new Map<String, Set<String>>();
        if (String.isBlank(sourceFieldApiName)) return modifiedFieldsByRow;

        for (Integer index = 0; index < records.size(); index++) {
            SObject record = records[index];
            modifiedFieldsByRow.put(getRowKey(record, index), getModifiedFieldsFromRecord(record, sourceFieldApiName, objectApiName));
        }

        return modifiedFieldsByRow;
    }

    // Evaluates DisplayCondition__c against the current Product and Shareclass records.
    public static Boolean shouldDisplayByCondition(FieldConfig config, SObject productRecord, SObject shareclassRecord) {
        if (String.isBlank(config.displayCondition)) return true;

        return evaluateDisplayCondition(config.displayCondition, productRecord, shareclassRecord);
    }

    // Evaluates a simple expression with || and && operators.
    public static Boolean evaluateDisplayCondition(String expression, SObject productRecord, SObject shareclassRecord) {
        for (String orPart : expression.split('\\|\\|')) {
            if (evaluateAndConditionGroup(orPart, productRecord, shareclassRecord)) return true;
        }

        return false;
    }

    // Evaluates all && conditions inside one expression group.
    public static Boolean evaluateAndConditionGroup(String expressionGroup, SObject productRecord, SObject shareclassRecord) {
        for (String token : expressionGroup.split('&&')) {
            if (!evaluateConditionToken(token, productRecord, shareclassRecord)) return false;
        }

        return true;
    }

    // Evaluates one condition token: =, !=, ISBLANK(), or !ISBLANK().
    public static Boolean evaluateConditionToken(String rawToken, SObject productRecord, SObject shareclassRecord) {
        String token = String.isBlank(rawToken) ? '' : rawToken.trim();
        if (String.isBlank(token)) return true;

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
    public static Object getConditionValue(String fieldReference, SObject productRecord, SObject shareclassRecord) {
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
    public static Boolean isBlankConditionValue(Object value) {
        return value == null || String.isBlank(String.valueOf(value));
    }

    // Normalizes string literals used in DisplayCondition__c.
    public static String normalizeExpectedValue(String rawValue) {
        String value = String.isBlank(rawValue) ? '' : rawValue.trim();

        if ((value.startsWith('\'') && value.endsWith('\'')) ||
            (value.startsWith('"') && value.endsWith('"'))) {
            return value.substring(1, value.length() - 1);
        }

        return value;
    }

    // Checks whether a field is in the modification selection for the current record.
    public static Boolean fieldWasSelected(Set<String> selectedFields, FieldConfig config) {
        return selectedFields != null && (selectedFields.contains(config.fieldApiName) || selectedFields.contains(config.fullFieldApiName));
    }

    // Safely reads a field value from queried or test-created SObjects.
    public static Object getSObjectValue(SObject record, String fieldApiName) {
        try {
            return record == null || String.isBlank(fieldApiName) ? null : record.get(fieldApiName);
        }
        catch (Exception e) {
            return null;
        }
    }

    // Gets a readable Shareclass label for the picklist and Shareclass header.
    public static String getShareclassDisplayName(SObject shareclassRecord, Integer rowIndex) {
        for (String identityField : SHARECLASS_IDENTITY_FIELDS) {
            Object value = getSObjectValue(shareclassRecord, identityField);
            if (value != null && String.isNotBlank(String.valueOf(value))) return String.valueOf(value);
        }

        return 'Shareclass ' + String.valueOf(rowIndex + 1);
    }

    // Returns a stable key for rows even in tests without persisted records.
    public static String getRowKey(SObject record, Integer rowIndex) {
        Object idValue = getSObjectValue(record, 'Id');
        return idValue == null ? 'row-' + String.valueOf(rowIndex) : String.valueOf(idValue);
    }

    // Returns the configured team order index or a default value for unknown teams.
    public static Integer getTeamOrder(String teamName) {
        for (Integer index = 0; index < TEAM_ORDER.size(); index++) {
            if (TEAM_ORDER[index] == teamName) return index;
        }

        return 99;
    }

    // Creates a safe key for accordion sections and UI loops.
    public static String makeSafeKey(String value) {
        String safeValue = String.isBlank(value) ? 'Unknown' : value.trim();
        return safeValue.replaceAll('[^a-zA-Z0-9_]', '_');
    }

    // Creates a UI-compatible key from an object-qualified field API name.
    public static String makeColumnKey(String value) {
        return makeSafeKey(value);
    }
}