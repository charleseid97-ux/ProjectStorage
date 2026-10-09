/** ──────────────────────────────────────
 * @description Apex controller for the PMT LWCs layoutEditableFields and projectChildTeamValidation: editable fields
 *                  from the user's PRP permission set, editability/modification conditions of a record, its fields and
 *                  record type, and the required fields of the PMT matrix (getFields, read from PMTMatrix since FIX-20178).
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass PageLayoutControllerTest
 * @coverage 92%   [09-10-26]
 ────────────────────────────────────── */
public without sharing class PageLayoutController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getEditableFields(String objectApiName, String teamView,Boolean viewAll) {
        Map<String, Boolean> fieldPermissions = new Map<String, Boolean>();
        if(objectApiName == 'ProjectShareclass__c') objectApiName = 'ProjectShareclassChild__c';
        
        try {    
            // View all: every field of PRPMinimumAccess (editable or not), otherwise only the fields the team can edit
            String permissionSetName = viewAll ? 'PRPMinimumAccess' : teamView;
            for (FieldPermissions perm : [SELECT Field, PermissionsEdit FROM FieldPermissions WHERE SObjectType = :objectApiName AND Parent.Name = :permissionSetName]) {
                if (viewAll || perm.PermissionsEdit) fieldPermissions.put(perm.Field, perm.PermissionsEdit);
            }
            if (teamView == 'PRPProductStrategy' && objectApiName == 'ProjectShareclassChild__c') fieldPermissions.put('ProjectShareclassChild__c.CurrencyIsoCode', !viewAll);
        } 
        catch (Exception e) {
            System.debug('❌ Error retrieving field permissions: ' + e.getMessage());
        }
    
        return fieldPermissions;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAllFieldsByRecordId(String recordId) {
        // Determine the SObject type from the Id prefix
        String objectPrefix = String.valueOf(recordId).substring(0, 3);
        String sObjectType;

        // Get all global describe
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (Schema.SObjectType type : globalDescribe.values()) {
            if((type.getDescribe().getKeyPrefix()) != null){
                if ( (type.getDescribe().getKeyPrefix()).equals(objectPrefix)) {
                    sObjectType = type.getDescribe().getName();
                    break;
                }
            }
        }

        if (String.isBlank(sObjectType)) throw new AuraHandledException('Unsupported or unknown SObject type.');

        if(SObjectType == 'ProjectShareclassChild__c'){
            sObjectType = 'ProjectShareclass__c';
            recordId = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId].ProjectShareclasses__c; // Get the parent record Id
        } 
        else if(SObjectType == 'ProjectProductChild__c'){
            sObjectType = 'ProjectProduct__c';
            recordId = [SELECT ProjectProductParent__c FROM ProjectProductChild__c WHERE id =: recordId].ProjectProductParent__c; // Get the parent record Id
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
    public static Boolean getUserPermissionSet(String teamView) {
        try {
            List<PermissionSetAssignment> permSet = [SELECT PermissionSet.Name  FROM PermissionSetAssignment  WHERE AssigneeId = :UserInfo.getUserId()  AND PermissionSet.Name = :teamView LIMIT 1];
            return !permSet.isEmpty(); // Returns TRUE if user has permission set, FALSE otherwise
        } 
        catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkEditableConidtions(String recordId, String objectApiName) {
        try {
            // return true;
            if(objectApiName == 'ProjectProductChild__c'){
                List<ProjectProductChild__c> project2 = [SELECT Id, ProjectProductParent__r.RecordType.DeveloperName, TECH_DoNotProcess__c
                                                         FROM ProjectProductChild__c
                                                         WHERE Id = :recordId
                                                         AND (TECH_DoNotProcess__c = false OR ProjectProductParent__r.RecordType.DeveloperName like '%Modification%')];
                return !project2.isEmpty(); //si modification return true
            }
            else if(objectApiName == 'ProjectShareclassChild__c'){
                List<ProjectShareclassChild__c> project2 = [SELECT Id, TECH_DoNotProcess__c
                                                            FROM ProjectShareclassChild__c
                                                            WHERE Id = :recordId
                                                            AND (TECH_DoNotProcess__c = false OR ProjectShareclasses__r.ProjectProduct__r.RecordType.DeveloperName like '%Modification%')];
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
            if(objectApiName == 'ProjectProductChild__c'){
                ProjectProductChild__c project2 = [SELECT Id, TECH_ProjectRecordType__c, TECH_DoNotProcess__c
                                                   FROM ProjectProductChild__c 
                                                   WHERE Id = :recordId LIMIT 1];
                return project2; //si modification return true
            }
            else if(objectApiName == 'ProjectShareclassChild__c'){
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
    public static string getRecordTypeId(String objectApiName, String recordId){
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

    @AuraEnabled(cacheable=true)
    public static List<String> getFields( String objectVar, String recordId) {
        PMTMatrix matrix = PMTMatrix.get(); // FIX-20178: required fields read from the PMT matrix (PMTFieldRule__mdt) instead of ProductProjectSettings__c

        if (matrix.rules.isEmpty()) throw new AuraHandledException('Aucun champ trouvé pour la Permission Set.');

        List<String> requiredFields = new List<String>();
        if (objectVar == 'ProjectProductChild__c') {
            requiredFields = matrix.getRequiredFields(true);
        } 
        else if (objectVar == 'ProjectShareclassChild__c') {
            requiredFields = matrix.getRequiredFields(false);
        }

        return requiredFields;
    }
}