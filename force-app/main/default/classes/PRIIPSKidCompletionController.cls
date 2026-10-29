/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the PRIIPs/KID completion bar widget (priipsKidCompletion).
 *              Loads the PRIIPSField__mdt configuration for the current Project Product/Shareclass records,
 *                  resolves it against the project mode (creation/modification) and scope (PS/IS), and aggregates
 *                  mandatory field completion into per-team percentages and traffic-light status.
 *              Works in conjunction with PRIIPSKidHelper for field resolution, condition evaluation and formatting.
 * @author EL HITARY Achraf
 * @lastModifiedBy Charles EID   [05-10-26]
 * @testClass PRIIPSKidCompletionControllerTest
 * @coverage 86%   [05-10-26]
 ────────────────────────────────────── */
public with sharing class PRIIPSKidCompletionController {
    @TestVisible private static Id productIdOverride;
    @TestVisible private static String recordTypeDeveloperNameOverride;
    @TestVisible private static String projectScopeOverride;
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

    // Loads completion indicators by team for the current Project Product record page.
    @AuraEnabled(cacheable=true)
    public static CompletionResponse getCompletionData(Id recordId) {
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

            List<String> warnings = new List<String>();
            Set<String> productFieldsToQuery = PRIIPSKidHelper.collectFieldsToQuery(configs, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME);
            Set<String> shareclassFieldsToQuery = PRIIPSKidHelper.collectFieldsToQuery(configs, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME);

            // Adds fields used only by DisplayCondition__c expressions.
            PRIIPSKidHelper.addConditionFieldsToQuery(configs, productFieldsToQuery, shareclassFieldsToQuery, productFieldsDescribe, shareclassFieldsDescribe);

            String productModifiedSourceField = projectMode == PRIIPSKidHelper.MODE_MODIFICATION ? PRIIPSKidHelper.getLocalSourceField(PRIIPSKidHelper.PRODUCT_MODIFIED_FIELDS_FIELD, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME, productFieldsDescribe, warnings) : null;
            String shareclassModifiedSourceField = projectMode == PRIIPSKidHelper.MODE_MODIFICATION ? PRIIPSKidHelper.getLocalSourceField(PRIIPSKidHelper.SHARECLASS_MODIFIED_FIELDS_FIELD, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME, shareclassFieldsDescribe, warnings) : null;

            PRIIPSKidHelper.addSourceField(productFieldsToQuery, productModifiedSourceField);
            PRIIPSKidHelper.addSourceField(shareclassFieldsToQuery, shareclassModifiedSourceField);
            PRIIPSKidHelper.addShareclassIdentityFields(shareclassFieldsToQuery, shareclassFieldsDescribe);

            SObject productRecord = queryProductRecord(productId, productFieldsToQuery);
            List<SObject> shareclassRecords = queryShareclassRecords(productId, shareclassFieldsToQuery, shareclassFieldsDescribe);
            Set<String> modifiedProductFields = PRIIPSKidHelper.getModifiedFieldsFromRecord(productRecord, productModifiedSourceField, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME);
            Map<String, Set<String>> modifiedShareclassFieldsByRow = PRIIPSKidHelper.buildModifiedFieldsByRow(shareclassRecords, shareclassModifiedSourceField, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME);

            return buildResponse(projectMode, recordTypeDeveloperName, warnings, configs, productRecord, shareclassRecords, modifiedProductFields, modifiedShareclassFieldsByRow, String.isNotBlank(productModifiedSourceField), String.isNotBlank(shareclassModifiedSourceField));
        }
        catch (AuraHandledException e) {
            throw e;
        }
        catch (Exception e) {
            throw new AuraHandledException('Unable to load PRIIPs/KID completion: ' + e.getMessage());
        }
    }

    // Clears test overrides used to cover the calculation without org data inserts.
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
        if (objectApiName == PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME)  return recordId;

        if (objectApiName == PRIIPSKidHelper.PRODUCT_CHILD_OBJECT_API_NAME) {
            String soql = 'SELECT ' + PRIIPSKidHelper.PRODUCT_CHILD_PARENT_FIELD + ' FROM ' + PRIIPSKidHelper.PRODUCT_CHILD_OBJECT_API_NAME + ' WHERE Id = :recordId LIMIT 1';
            SObject productChild = Database.query(soql);
            return (Id) productChild.get(PRIIPSKidHelper.PRODUCT_CHILD_PARENT_FIELD);
        }

        throw new AuraHandledException('Unsupported record page object: ' + objectApiName);
    }

    // Gets the product record type developer name to select the correct metadata flags.
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
        if (Test.isRunningTest() && metadataRowsOverride != null) {
            return metadataRowsOverride;
        }

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

        if (records.isEmpty()) throw new AuraHandledException('Project Product not found.');
        return records[0];
    }

    // Queries all shareclass records linked to the current Project Product.
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

    // Builds the final DTO consumed by the LWC.
    private static CompletionResponse buildResponse(String projectMode, String recordTypeDeveloperName, List<String> warnings, List<PRIIPSKidHelper.FieldConfig> configs, SObject productRecord, List<SObject> shareclassRecords, Set<String> modifiedProductFields, Map<String, Set<String>> modifiedShareclassFieldsByRow, Boolean useProductModifiedSource, Boolean useShareclassModifiedSource) {
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
    private static void addProductDetails(Map<String, TeamCompletion> teamsByName, List<PRIIPSKidHelper.FieldConfig> configs, SObject productRecord, Set<String> modifiedProductFields, Boolean useProductModifiedSource, String projectMode) {
        Map<String, List<PRIIPSKidHelper.FieldConfig>> configsByTeam = groupConfigsByTeam(configs, PRIIPSKidHelper.PRODUCT_OBJECT_API_NAME);

        for (String teamName : configsByTeam.keySet()) {
            List<PRIIPSKidHelper.FieldConfig> selectedConfigs = new List<PRIIPSKidHelper.FieldConfig>();
            for (PRIIPSKidHelper.FieldConfig config : configsByTeam.get(teamName)) {
                // Completion is calculated only on mandatory PRIIPs fields.
                if (!config.required) continue;

                if (projectMode == PRIIPSKidHelper.MODE_MODIFICATION && useProductModifiedSource && !PRIIPSKidHelper.fieldWasSelected(modifiedProductFields, config)) continue;

                // Ignores the field when its DisplayCondition__c evaluates to false.
                if (!PRIIPSKidHelper.shouldDisplayByCondition(config, productRecord, null)) continue;

                selectedConfigs.add(config);
            }

            CompletionDetail detail = calculateDetail('Produit', productRecord, selectedConfigs, 'product');
            if (detail.total > 0) addDetailToTeam(getOrCreateTeam(teamsByName, teamName), detail);
        }
    }

    // Adds one shareclass detail line per team and per shareclass row.
    private static void addShareclassDetails(Map<String, TeamCompletion> teamsByName, List<PRIIPSKidHelper.FieldConfig> configs, SObject productRecord, List<SObject> shareclassRecords, Map<String, Set<String>> modifiedShareclassFieldsByRow, Boolean useShareclassModifiedSource, String projectMode) {
        Map<String, List<PRIIPSKidHelper.FieldConfig>> configsByTeam = groupConfigsByTeam(configs, PRIIPSKidHelper.SHARECLASS_OBJECT_API_NAME);

        for (String teamName : configsByTeam.keySet()) {
            for (Integer index = 0; index < shareclassRecords.size(); index++) {
                SObject shareclassRecord = shareclassRecords[index];
                Set<String> modifiedFields = modifiedShareclassFieldsByRow.get(PRIIPSKidHelper.getRowKey(shareclassRecord, index));
                List<PRIIPSKidHelper.FieldConfig> selectedConfigs = new List<PRIIPSKidHelper.FieldConfig>();

                for (PRIIPSKidHelper.FieldConfig config : configsByTeam.get(teamName)) {
                    // Completion is calculated only on mandatory PRIIPs fields.
                    if (!config.required) continue;

                    if (projectMode == PRIIPSKidHelper.MODE_MODIFICATION && useShareclassModifiedSource && !PRIIPSKidHelper.fieldWasSelected(modifiedFields, config)) continue;

                    // Ignores the field for this row when its DisplayCondition__c is false.
                    if (!PRIIPSKidHelper.shouldDisplayByCondition(config, productRecord, shareclassRecord)) continue;

                    selectedConfigs.add(config);
                }

                CompletionDetail detail = calculateDetail(PRIIPSKidHelper.getShareclassDisplayName(shareclassRecord, index), shareclassRecord, selectedConfigs, PRIIPSKidHelper.getRowKey(shareclassRecord, index));
                if (detail.total > 0) addDetailToTeam(getOrCreateTeam(teamsByName, teamName), detail);
            }
        }
    }

    // Groups field configs by team for the requested object.
    private static Map<String, List<PRIIPSKidHelper.FieldConfig>> groupConfigsByTeam(List<PRIIPSKidHelper.FieldConfig> configs, String objectApiName) {
        Map<String, List<PRIIPSKidHelper.FieldConfig>> configsByTeam = new Map<String, List<PRIIPSKidHelper.FieldConfig>>();

        for (PRIIPSKidHelper.FieldConfig config : configs) {
            if (config.objectApiName != objectApiName) continue;
            if (!configsByTeam.containsKey(config.team)) configsByTeam.put(config.team, new List<PRIIPSKidHelper.FieldConfig>());
            configsByTeam.get(config.team).add(config);
        }

        return configsByTeam;
    }

    // Calculates completed and expected fields for one detail line.
    private static CompletionDetail calculateDetail(String label, SObject record, List<PRIIPSKidHelper.FieldConfig> configs, String keySuffix) {
        CompletionDetail detail = new CompletionDetail();
        detail.label = label;
        detail.key = PRIIPSKidHelper.makeSafeKey(label + '_' + keySuffix);
        detail.total = configs.size();

        for (PRIIPSKidHelper.FieldConfig config : configs) {
            if (hasCompletionValue(record, config)) detail.completed++;
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
            team.key = PRIIPSKidHelper.makeSafeKey(teamName);
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
        if (total == null || total == 0) return 0;

        Decimal value = (Decimal.valueOf(completed) / Decimal.valueOf(total)) * 100;
        return Integer.valueOf(String.valueOf(Math.round(value)));
    }

    // Converts a percentage into the color status expected by the LWC.
    private static String calculateStatus(Integer percentage) {
        if (percentage == null || percentage < 50) return 'red';
        if (percentage < 80) return 'orange';
        return 'green';
    }

    // Returns true when a field value counts as completed.
    private static Boolean hasCompletionValue(SObject record, PRIIPSKidHelper.FieldConfig config) {
        Object value = PRIIPSKidHelper.getSObjectValue(record, config.fieldApiName);
        if (value == null) return false;

        // ExactValue__c forces the field to match a specific value.
        if (String.isNotBlank(config.exactValue)) return String.valueOf(value).trim() == config.exactValue.trim();

        // Default completion rule: text must be non-empty, other values count as filled.
        if (value instanceof String) return String.isNotBlank((String) value);

        return true;
    }

    // Sorts teams using the expected PMT team order, then by team name.
    private static List<TeamCompletion> sortTeams(Map<String, TeamCompletion> teamsByName) {
        List<String> sortableKeys = new List<String>();
        Map<String, TeamCompletion> sortableKeyToTeam = new Map<String, TeamCompletion>();

        for (String teamName : teamsByName.keySet()) {
            String sortableKey = String.valueOf(100 + PRIIPSKidHelper.getTeamOrder(teamName)) + '|' + teamName;
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
}