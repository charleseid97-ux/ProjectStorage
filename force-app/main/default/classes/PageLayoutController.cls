/** ──────────────────────────────────────
 * @description Apex controller for the PMT LWCs layoutEditableFields and projectChildTeamValidation: a record's fields and record
 *                  type, its editability/modification conditions, and the fields of a team's screen (getFieldStates, US-20194 V1.2):
 *                  the team's PMT lines at the record's stage whose condition applies, required from the line, editable with the
 *                  team's custom permission.
 * @lastModifiedBy Charles EID   [24-10-26]
 * @testClass PageLayoutControllerTest
 * @coverage 97%   [24-10-26]
 ────────────────────────────────────── */
public without sharing class PageLayoutController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAllFieldsByRecordId(String recordId) {
        // Determine the SObject type from the Id prefix
        String objectPrefix = String.valueOf(recordId).substring(0, 3);
        String sObjectType;

        // Get all global describe
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (Schema.SObjectType type : globalDescribe.values()) {
            if ((type.getDescribe().getKeyPrefix()) != null) {
                if ((type.getDescribe().getKeyPrefix()).equals(objectPrefix)) {
                    sObjectType = type.getDescribe().getName();
                    break;
                }
            }
        }

        if (String.isBlank(sObjectType)) throw new AuraHandledException('Unsupported or unknown SObject type.');

        if (SObjectType == 'ProjectShareclassChild__c') {
            sObjectType = 'ProjectShareclass__c';
            recordId = [SELECT ProjectShareclasses__c
                        FROM ProjectShareclassChild__c
                        WHERE Id = :recordId].ProjectShareclasses__c; // Get the parent record Id
        }
        else if (SObjectType == 'ProjectProductChild__c') {
            sObjectType = 'ProjectProduct__c';
            recordId = [SELECT ProjectProductParent__c
                        FROM ProjectProductChild__c
                        WHERE id = :recordId].ProjectProductParent__c; // Get the parent record Id
        }

        Schema.SObjectType objType = globalDescribe.get(sObjectType);
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();

        String soqlFields = String.join(new List<String>(fieldsMap.keySet()), ',');

        // Dynamically build SOQL and query
        String soql = 'SELECT ' + soqlFields + ' FROM ' + sObjectType + ' WHERE Id = :recordId';
        SObject record = Database.query(soql);

        // Return fields as a Map<String, Object>
        Map<String, Object> result = new Map<String, Object>();
        for (String fieldName : fieldsMap.keySet()) {
            result.put(fieldsMap.get(fieldName).getDescribe().getName(), record.get(fieldName));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkEditableConidtions(String recordId, String objectApiName) {
        try {
            if (objectApiName == 'ProjectProductChild__c') {
                List<ProjectProductChild__c> project2 = [SELECT Id, ProjectProductParent__r.RecordType.DeveloperName, TECH_DoNotProcess__c
                                                         FROM ProjectProductChild__c
                                                         WHERE Id = :recordId AND (TECH_DoNotProcess__c = false OR ProjectProductParent__r.RecordType.DeveloperName like '%Modification%')];
                return !project2.isEmpty(); //si modification return true
            }
            else if (objectApiName == 'ProjectShareclassChild__c') {
                List<ProjectShareclassChild__c> project2 = [SELECT Id, TECH_DoNotProcess__c
                                                            FROM ProjectShareclassChild__c
                                                            WHERE Id = :recordId AND (TECH_DoNotProcess__c = false OR ProjectShareclasses__r.ProjectProduct__r.RecordType.DeveloperName like '%Modification%')];
                return !project2.isEmpty(); //si modification return true
            }
            return false;
        }
        catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static SObject checkModificationConidtions(String recordId, String objectApiName) {
        try {
            if (objectApiName == 'ProjectProductChild__c') {
                ProjectProductChild__c project2 = [SELECT Id, TECH_ProjectRecordType__c, TECH_DoNotProcess__c
                                                   FROM ProjectProductChild__c
                                                   WHERE Id = :recordId LIMIT 1];
                return project2; //si modification return true
            }
            else if (objectApiName == 'ProjectShareclassChild__c') {
                ProjectShareclassChild__c project2 = [SELECT Id, TECH_DoNotProcess__c, TECH_ProjectRecordType__c
                                                      FROM ProjectShareclassChild__c
                                                      WHERE Id = :recordId LIMIT 1];
                return project2; //si modification return true
            }
            return null;
        }
        catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getEditableFieldsFromSourceField(String editableFieldSource, String objectApiName, String recordId) {
        try {
            String query = 'SELECT ' + editableFieldSource + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
            SObject obj = Database.query(query);

            String fieldValue;
            Boolean isRelationship = editableFieldSource.contains('.'); // Check if the field is a relationship field
            if (isRelationship) {
                // Extract the parent relationship name and field dynamically
                List<String> parts = editableFieldSource.split('\\.');
                String parentRelationship = parts[0];
                String parentField = parts[1];

                SObject parentObj = obj.getSObject(parentRelationship);
                if (parentObj != null) {
                    fieldValue = (String) parentObj.get(parentField);
                }
                else {
                    return new List<String>();
                }
            }
            else {
                fieldValue = (String) obj.get(editableFieldSource);
            }

            if (String.isNotBlank(fieldValue)) return fieldValue.split(';');
            return new List<String>();
        }
        catch (Exception e) {
            System.debug('❌ Error fetching Parent editable fields: ' + e.getMessage());
            return new List<String>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static string getRecordTypeId(String objectApiName, String recordId) {
        try {
            String query = 'SELECT RecordTypeId FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
            SObject obj = Database.query(query);

            Id recordTypeId = (Id) obj.get('RecordTypeId');
            return recordTypeId;
        }
        catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return '012000000000000AAA'; // If the record has no RecordTypeId, get the Master Record Type Id
        }
    }

    // US-20194 V1.6: warning of the PMT screens naming the invalid PMT lines and owner rules, which are not used (null when none).
    @AuraEnabled(cacheable=true)
    public static String getPMTConfigurationWarning() {
        return PMTMatrix.getConfigurationWarning();
    }

    // US-20194 V1.2: fields of a team's screen (c__team) on a stage record: the team's lines at the record's stage whose Condition__c applies to the project and share class, as they are with the unsaved values (draftValues, field -> value) of the screen. Visible for everyone; required from the line (Requirement__c, RequiredCondition__c); editable when the user has the team's custom permission and can edit the field. Returns {fields: {api name: {required, editable}}, conditionFields: [fields whose change can change the states]}.
    @AuraEnabled
    public static Map<String, Object> getFieldStates(Id recordId, String teamView, Map<String, Object> draftValues) {
        if (PMTMatrix.getForScreen().rules.isEmpty()) throw new AuraHandledException('Aucun champ trouvé pour la Permission Set.');

        Schema.SObjectType recordType = recordId.getSObjectType();
        Boolean fund = recordType == ProjectProductChild__c.SObjectType;
        Set<String> stageNames = new Set<String>();
        Id projectId;
        Id shareClassId;
        if (fund) {
            ProjectProductChild__c phase = [SELECT ProjectProductParent__c, TECH_Childtype__c FROM ProjectProductChild__c WHERE Id = :recordId];
            projectId = phase.ProjectProductParent__c;
            stageNames = getStageNames(phase.TECH_Childtype__c);
        }
        else if (recordType == ProjectShareclassChild__c.SObjectType) {
            ProjectShareclassChild__c shareClassPhase = [SELECT ProjectShareclasses__c, ProjectShareclasses__r.ProjectProduct__c, TECH_Childtype__c
                                                         FROM ProjectShareclassChild__c
                                                         WHERE Id = :recordId];
            shareClassId = shareClassPhase.ProjectShareclasses__c;
            projectId = shareClassPhase.ProjectShareclasses__r.ProjectProduct__c;
            stageNames = getStageNames(shareClassPhase.TECH_Childtype__c);
        }
        else if (recordType == ProjectShareclass__c.SObjectType) {
            // Not a team screen (no stage): every stage of the team, read-only
            ProjectShareclass__c shareClass = [SELECT ProjectProduct__c FROM ProjectShareclass__c WHERE Id = :recordId];
            shareClassId = shareClass.Id;
            projectId = shareClass.ProjectProduct__c;
            for (PMTMatrix.Stage stage : PMTMatrix.get().stages) stageNames.add(stage.name);
        }

        Map<Id, ProjectProduct__c> projectById = PMTMatrix.loadProjects(new Set<Id>{ projectId });
        ProjectProduct__c project = projectById.get(projectId);
        Map<String, Object> result = new Map<String, Object>{ 'fields' => new Map<String, Object>(), 'conditionFields' => new List<String>() };
        if (project == null) return result;

        // The unsaved values of the screen count: a stage record's fields are copied to its project (Fund) or share class
        SObject draftTarget = project;
        if (shareClassId != null) {
            for (ProjectShareclass__c shareClass : project.ProjectShareclasses__r) {
                if (shareClass.Id == shareClassId) draftTarget = shareClass;
            }
        }
        applyDraftValues(draftTarget, draftValues);

        PMTMatrix matrix = PMTMatrix.forProject(project);
        if (shareClassId != null) matrix = matrix.forShareClass(shareClassId);

        // checkPermission fails (uncatchable) on a name that is not an API name, e.g. an empty or hand-typed c__team
        Boolean ownsFields = recordType != ProjectShareclass__c.SObjectType && teamView != null && Pattern.matches('[A-Za-z][A-Za-z0-9_]*', teamView) && FeatureManagement.checkPermission(teamView);
        Map<String, Schema.SObjectField> screenFields = recordType.getDescribe().fields.getMap();
        Map<String, Object> states = (Map<String, Object>) result.get('fields');
        String teamKey = teamView == null ? '' : teamView.removeStart('PRP');
        Map<String, Boolean> requiredByField = matrix.getTeamFieldStates(teamKey, stageNames, fund);
        for (String field : requiredByField.keySet()) {
            Schema.SObjectField screenField = screenFields.get(field.toLowerCase());
            Boolean editable = ownsFields && screenField != null && screenField.getDescribe().isUpdateable();
            states.put(field, new Map<String, Boolean>{ 'required' => requiredByField.get(field), 'editable' => editable });
        }

        Set<String> conditionFields = PMTMatrix.get().getConditionFields();
        conditionFields.addAll(PMTMatrix.get().getShareClassConditionFields());
        result.put('conditionFields', new List<String>(conditionFields));
        return result;
    }

    // PMT stages of a stage record type (TECH_Childtype__c): the DesignAndProposal record holds the Design and Proposal stages.
    private static Set<String> getStageNames(String childType) {
        return childType == 'DesignAndProposal' ? new Set<String>{ 'Design', 'Proposal' } : new Set<String>{ childType };
    }

    // Puts the screen's unsaved values on the in-memory record, typed like its fields; fields it doesn't have or can't take (formulas, auto numbers) are skipped.
    private static void applyDraftValues(SObject record, Map<String, Object> draftValues) {
        if (draftValues == null) return;

        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        for (String fieldName : draftValues.keySet()) {
            Schema.SObjectField field = fields.get(fieldName.toLowerCase());
            if (field == null || !field.getDescribe().isUpdateable()) continue;
            Object value = draftValues.get(fieldName);
            if (value instanceof List<Object>) value = String.join((List<Object>) value, ';');
            Schema.DisplayType fieldType = field.getDescribe().getType();
            if (value == null || value == '') record.put(field, fieldType == Schema.DisplayType.Boolean ? (Object) false : null);
            else if (fieldType == Schema.DisplayType.Boolean) record.put(field, Boolean.valueOf(String.valueOf(value)));
            else if (fieldType == Schema.DisplayType.Date) record.put(field, Date.valueOf(String.valueOf(value)));
            else if (fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) record.put(field, Decimal.valueOf(String.valueOf(value)));
            else if (fieldType == Schema.DisplayType.Integer) record.put(field, Integer.valueOf(String.valueOf(value)));
            else record.put(field, String.valueOf(value));
        }
    }
}