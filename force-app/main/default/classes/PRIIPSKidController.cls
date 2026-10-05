/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the main PRIIPs/KID panel (priipsKid).
 *              Loads the PRIIPSField__mdt configuration for the current Project Product/Shareclass records,
 *                  resolves it against the project mode (creation/modification) and scope (PS/IS), and returns
 *                  field values grouped by team for display, flagging which are required and filled.
 *              Works in conjunction with PRIIPSKidHelper for field resolution, condition evaluation and formatting.
 * @author EL HITARY Achraf
 * @lastModifiedBy Charles EID   [05-10-26]
 * @testClass PRIIPSKidControllerTest
 * @coverage 79%   [05-10-26]
 ────────────────────────────────────── */
public with sharing class PRIIPSKidController {
    @TestVisible private static Id productIdOverride;
    @TestVisible private static String recordTypeDeveloperNameOverride;
    @TestVisible private static String projectScopeOverride;
    @TestVisible private static List<PRIIPSField__mdt> metadataRowsOverride;
    @TestVisible private static SObject productRecordOverride;
    @TestVisible private static List<SObject> shareclassRecordsOverride;

    public class PriipsKidResponse {
        @AuraEnabled public String projectMode;
        @AuraEnabled public String projectRecordType;
        @AuraEnabled public String warningMessage;
        @AuraEnabled public List<TeamSection> productTeams = new List<TeamSection>();
        @AuraEnabled public List<ShareclassView> shareclasses = new List<ShareclassView>();
    }

    public class ShareclassView {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean hasTeams = false;
        @AuraEnabled public List<TeamSection> teams = new List<TeamSection>();
    }

    public class TeamSection {
        @AuraEnabled public String key;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean hasFields = false;
        @AuraEnabled public List<FieldValue> fields = new List<FieldValue>();
    }

    public class FieldValue {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean required = false;
        @AuraEnabled public Boolean isFilled = false;
    }

    // Loads PRIIPs/KID fields for the current Project Product record page.
    @AuraEnabled(cacheable=true)
    public static PriipsKidResponse getPriipsKidData(Id recordId) {
        try {
            if (recordId == null && !(Test.isRunningTest() && productIdOverride != null)) {
                throw new AuraHandledException('Record Id is required.');
            }

            Id productId = resolveProductId(recordId);
            String recordTypeDeveloperName = getProductRecordTypeDeveloperName(productId);
            String projectMode = PRIIPSKidHelper.resolveProjectMode(recordTypeDeveloperName);
            String projectScope = getProjectScope(productId);

            Map<String, Schema.SObjectField> productFieldsDescribe = PRIIPSKidHelper.getFieldDescribeMap(PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME);
            Map<String, Schema.SObjectField> shareclassFieldsDescribe = PRIIPSKidHelper.getFieldDescribeMap(PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME);
            List<PRIIPSKidHelper.FieldConfig> configs = PRIIPSKidHelper.buildFieldConfigs(loadMetadataRows(), projectMode, projectScope, productFieldsDescribe, shareclassFieldsDescribe);

            Set<String> productFieldsToQuery = PRIIPSKidHelper.collectFieldsToQuery(configs, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME);
            Set<String> shareclassFieldsToQuery = PRIIPSKidHelper.collectFieldsToQuery(configs, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME);

            // Adds fields used only by DisplayCondition__c expressions.
            PRIIPSKidHelper.addConditionFieldsToQuery(configs, productFieldsToQuery, shareclassFieldsToQuery, productFieldsDescribe, shareclassFieldsDescribe);
            PRIIPSKidHelper.addShareclassIdentityFields(shareclassFieldsToQuery, shareclassFieldsDescribe);

            List<String> warnings = new List<String>();
            String productModifiedSourceField = projectMode == PRIIPSKidHelper.MODE_MODIFICATION ? PRIIPSKidHelper.getLocalSourceField(PRIIPSKidHelper.PRODUCT_MODIFIED_FIELDS_FIELD, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME, productFieldsDescribe, warnings) : null;
            String shareclassModifiedSourceField = projectMode == PRIIPSKidHelper.MODE_MODIFICATION ? PRIIPSKidHelper.getLocalSourceField(PRIIPSKidHelper.SHARECLASS_MODIFIED_FIELDS_FIELD, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME, shareclassFieldsDescribe, warnings) : null;

            PRIIPSKidHelper.addSourceField(productFieldsToQuery, productModifiedSourceField);
            PRIIPSKidHelper.addSourceField(shareclassFieldsToQuery, shareclassModifiedSourceField);

            SObject productRecord = queryProductRecord(productId, productFieldsToQuery);
            List<SObject> shareclassRecords = queryShareclassRecords(productId, shareclassFieldsToQuery, shareclassFieldsDescribe);
            Set<String> modifiedProductFields = PRIIPSKidHelper.getModifiedFieldsFromRecord(productRecord, productModifiedSourceField, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME);
            Map<String, Set<String>> modifiedShareclassFieldsByRow = PRIIPSKidHelper.buildModifiedFieldsByRow(shareclassRecords, shareclassModifiedSourceField, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME);

            addModificationWarning(projectMode, productModifiedSourceField, shareclassModifiedSourceField, warnings);

            return buildResponse(projectMode, recordTypeDeveloperName, warnings, configs, productRecord, shareclassRecords, modifiedProductFields, modifiedShareclassFieldsByRow, String.isNotBlank(productModifiedSourceField), String.isNotBlank(shareclassModifiedSourceField));
        }
        catch (AuraHandledException e) {
            throw e;
        }
        catch (Exception e) {
            throw new AuraHandledException('Unable to load PRIIPs/KID data: ' + e.getMessage());
        }
    }

    // Clears test overrides used to cover the controller without org data inserts.
    @TestVisible
    private static void resetOverridesForTest() {
        productIdOverride = null;
        recordTypeDeveloperNameOverride = null;
        projectScopeOverride = null;
        metadataRowsOverride = null;
        productRecordOverride = null;
        shareclassRecordsOverride = null;
    }

    // Resolves the Project Product Id from supported PMT record page contexts.
    private static Id resolveProductId(Id recordId) {
        if (Test.isRunningTest() && productIdOverride != null) return productIdOverride;

        String objectApiName = recordId.getSObjectType().getDescribe().getName();
        if (objectApiName == PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME) return recordId;

        if (objectApiName == PRIIPSKidHelper.PRODUCT_CHILD_OBJECT_API_NAME) {
            String soql = 'SELECT ' + PRIIPSKidHelper.PRODUCT_CHILD_PARENT_FIELD + ' FROM ' + PRIIPSKidHelper.PRODUCT_CHILD_OBJECT_API_NAME + ' WHERE Id = :recordId LIMIT 1';
            SObject productChild = Database.query(soql);
            return (Id) productChild.get(PRIIPSKidHelper.PRODUCT_CHILD_PARENT_FIELD);
        }

        throw new AuraHandledException('Unsupported record page object: ' + objectApiName);
    }

    // Gets the Project Product record type developer name to select the correct metadata flags.
    private static String getProductRecordTypeDeveloperName(Id productId) {
        if (Test.isRunningTest() && recordTypeDeveloperNameOverride != null) return recordTypeDeveloperNameOverride;

        String soql = 'SELECT RecordType.DeveloperName FROM ' + PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME + ' WHERE Id = :productId LIMIT 1';
        SObject productRecord = Database.query(soql);
        SObject recordType = productRecord.getSObject('RecordType');
        return recordType == null ? '' : (String) recordType.get('DeveloperName');
    }

    // US-20120: Gets the Project Product's Scope (PS/IS) to resolve team display names.
    private static String getProjectScope(Id productId) {
        if (Test.isRunningTest() && projectScopeOverride != null) return projectScopeOverride;

        String soql = 'SELECT Scope__c FROM ' + PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME + ' WHERE Id = :productId LIMIT 1';
        SObject productRecord = Database.query(soql);
        return (String) productRecord.get('Scope__c');
    }

    // Loads configured PRIIPs/KID fields from Custom Metadata.
    private static List<PRIIPSField__mdt> loadMetadataRows() {
        if (Test.isRunningTest() && metadataRowsOverride != null) return metadataRowsOverride;

        return [SELECT DeveloperName, MasterLabel, FieldApiName__c, Team__c, OtherTeams__c, ProductCreation__c, ShareclassCreation__c, ProductShareModification__c, DisplayCondition__c, Required__c, ExactValue__c
                FROM PRIIPSField__mdt
                ORDER BY Team__c, MasterLabel];
    }

    // Queries the Project Product record with only fields required by the UI.
    private static SObject queryProductRecord(Id productId, Set<String> fieldNames) {
        if (Test.isRunningTest() && productRecordOverride != null) return productRecordOverride;

        String soql = 'SELECT ' + String.join(PRIIPSKidHelper.sortFieldNames(fieldNames), ',') +
                      ' FROM ' + PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME +
                      ' WHERE Id = :productId LIMIT 1';
        List<SObject> records = Database.query(soql);

        if (records.isEmpty()) {
            throw new AuraHandledException('Project Product not found.');
        }
        return records[0];
    }

    // Queries all Shareclass records linked to the current Project Product.
    private static List<SObject> queryShareclassRecords(Id productId, Set<String> fieldNames, Map<String, Schema.SObjectField> shareclassFieldsDescribe) {
        if (Test.isRunningTest() && shareclassRecordsOverride != null) return shareclassRecordsOverride;

        if (!PRIIPSKidHelper.isReadableField(PRIIPSKidHelper.DEFAULT_SHARECLASS_LOOKUP_FIELD, shareclassFieldsDescribe)) {
            throw new AuraHandledException('Invalid Shareclass lookup field: ' + PRIIPSKidHelper.DEFAULT_SHARECLASS_LOOKUP_FIELD);
        }

        fieldNames.add(PRIIPSKidHelper.DEFAULT_SHARECLASS_LOOKUP_FIELD);
        String soql = 'SELECT ' + String.join(PRIIPSKidHelper.sortFieldNames(fieldNames), ',') +
                      ' FROM ' + PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME +
                      ' WHERE ' + PRIIPSKidHelper.DEFAULT_SHARECLASS_LOOKUP_FIELD + ' = :productId ORDER BY Name';
        return Database.query(soql);
    }

    // Adds a warning when modification filtering cannot be field-level precise.
    private static void addModificationWarning(String projectMode, String productModifiedSourceField, String shareclassModifiedSourceField, List<String> warnings) {
        if (projectMode != PRIIPSKidHelper.MODE_MODIFICATION) return;

        if (String.isBlank(productModifiedSourceField) && String.isBlank(shareclassModifiedSourceField)) {
            warnings.add('Modification project detected: no modified-fields source configured, so all metadata fields marked for modification are displayed.');
        }
    }

    // Builds the final DTO consumed by the LWC.
    private static PriipsKidResponse buildResponse(String projectMode, String recordTypeDeveloperName, List<String> warnings, List<PRIIPSKidHelper.FieldConfig> configs, SObject productRecord, List<SObject> shareclassRecords, Set<String> modifiedProductFields, Map<String, Set<String>> modifiedShareclassFieldsByRow, Boolean useProductModifiedSource, Boolean useShareclassModifiedSource) {
        PriipsKidResponse response = new PriipsKidResponse();
        response.projectMode = projectMode;
        response.projectRecordType = recordTypeDeveloperName;
        response.warningMessage = warnings.isEmpty() ? null : String.join(warnings, ' ');
        response.productTeams = buildProductTeams(configs, productRecord, modifiedProductFields, useProductModifiedSource, projectMode);
        response.shareclasses = buildShareclassViews(configs, productRecord, shareclassRecords, modifiedShareclassFieldsByRow, useShareclassModifiedSource, projectMode);
        return response;
    }

    // Builds Product-level fields grouped by team.
    private static List<TeamSection> buildProductTeams(List<PRIIPSKidHelper.FieldConfig> configs, SObject productRecord, Set<String> modifiedProductFields, Boolean useProductModifiedSource, String projectMode) {
        Map<String, TeamSection> sectionsByTeam = new Map<String, TeamSection>();

        for (PRIIPSKidHelper.FieldConfig config : configs) {
            if (config.objectApiName != PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME) continue;
            if (projectMode == PRIIPSKidHelper.MODE_MODIFICATION && useProductModifiedSource && !PRIIPSKidHelper.fieldWasSelected(modifiedProductFields, config)) continue;
            if (!PRIIPSKidHelper.shouldDisplayByCondition(config, productRecord, null)) continue;

            TeamSection section = getOrCreateTeamSection(sectionsByTeam, config.team);
            section.fields.add(createFieldValue(config, productRecord));
            section.hasFields = true;
        }

        return sortTeamSections(sectionsByTeam);
    }

    // Builds one Shareclass view with fields grouped by team for each Shareclass record.
    private static List<ShareclassView> buildShareclassViews(List<PRIIPSKidHelper.FieldConfig> configs, SObject productRecord, List<SObject> shareclassRecords, Map<String, Set<String>> modifiedShareclassFieldsByRow, Boolean useShareclassModifiedSource, String projectMode) {
        List<ShareclassView> shareclassViews = new List<ShareclassView>();

        for (Integer index = 0; index < shareclassRecords.size(); index++) {
            SObject shareclassRecord = shareclassRecords[index];
            String rowKey = PRIIPSKidHelper.getRowKey(shareclassRecord, index);
            Set<String> modifiedFields = modifiedShareclassFieldsByRow.get(rowKey);
            Map<String, TeamSection> sectionsByTeam = new Map<String, TeamSection>();

            // Applies modification and display-condition filters per Shareclass row.
            for (PRIIPSKidHelper.FieldConfig config : configs) {
                if (config.objectApiName != PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME) continue;
                if (projectMode == PRIIPSKidHelper.MODE_MODIFICATION && useShareclassModifiedSource && !PRIIPSKidHelper.fieldWasSelected(modifiedFields, config)) continue;
                if (!PRIIPSKidHelper.shouldDisplayByCondition(config, productRecord, shareclassRecord)) continue;

                TeamSection section = getOrCreateTeamSection(sectionsByTeam, config.team);
                section.fields.add(createFieldValue(config, shareclassRecord));
                section.hasFields = true;
            }

            ShareclassView view = new ShareclassView();
            view.id = rowKey;
            view.label = PRIIPSKidHelper.getShareclassDisplayName(shareclassRecord, index);
            view.teams = sortTeamSections(sectionsByTeam);
            view.hasTeams = !view.teams.isEmpty();

            if (view.hasTeams) shareclassViews.add(view);
        }

        return shareclassViews;
    }

    // Creates one UI field value from a field config and an SObject record.
    private static FieldValue createFieldValue(PRIIPSKidHelper.FieldConfig config, SObject record) {
        Object rawValue = PRIIPSKidHelper.getSObjectValue(record, config.fieldApiName);
        FieldValue fieldValue = new FieldValue();

        fieldValue.key = config.key;
        fieldValue.label = config.label;
        fieldValue.apiName = config.fullFieldApiName;
        fieldValue.value = formatValue(rawValue);
        fieldValue.required = config.required == true;
        fieldValue.isFilled = isFieldFilled(rawValue, config);
        return fieldValue;
    }

    // Returns true when a displayed field satisfies the completion rule.
    private static Boolean isFieldFilled(Object value, PRIIPSKidHelper.FieldConfig config) {
        if (value == null) return false;

        // ExactValue__c overrides the default non-empty completion rule.
        if (String.isNotBlank(config.exactValue)) return String.valueOf(value).trim() == config.exactValue.trim();

        // Default rule keeps text values strict and accepts non-null values.
        if (value instanceof String) return String.isNotBlank((String) value);

        return true;
    }

    // Gets or creates a team section in the response map.
    private static TeamSection getOrCreateTeamSection(Map<String, TeamSection> sectionsByTeam, String teamName) {
        if (!sectionsByTeam.containsKey(teamName)) {
            TeamSection section = new TeamSection();
            section.name = teamName;
            section.key = PRIIPSKidHelper.makeSafeKey(teamName);
            sectionsByTeam.put(teamName, section);
        }

        return sectionsByTeam.get(teamName);
    }

    // Formats field values for a read-only UI display.
    private static String formatValue(Object value) {
        if (value == null) return '';
        if (value instanceof Boolean) return ((Boolean) value) ? 'Yes' : 'No';
        if (value instanceof Date) return ((Date) value).format();
        if (value instanceof Datetime) return ((Datetime) value).format();

        return String.valueOf(value).replace(';', '; ');
    }

    // Sorts team sections using the expected PMT team order.
    private static List<TeamSection> sortTeamSections(Map<String, TeamSection> sectionsByTeam) {
        List<String> sortableKeys = new List<String>();
        Map<String, TeamSection> sortableKeyToSection = new Map<String, TeamSection>();

        for (String teamName : sectionsByTeam.keySet()) {
            String sortableKey = String.valueOf(100 + PRIIPSKidHelper.getTeamOrder(teamName)) + '|' + teamName;
            sortableKeys.add(sortableKey);
            sortableKeyToSection.put(sortableKey, sectionsByTeam.get(teamName));
        }

        sortableKeys.sort();
        List<TeamSection> sortedSections = new List<TeamSection>();
        for (String sortableKey : sortableKeys) {
            sortedSections.add(sortableKeyToSection.get(sortableKey));
        }

        return sortedSections;
    }
}
