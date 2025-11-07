public without sharing class PageLayoutController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getEditableFields(String objectApiName, String teamView,Boolean viewAll) {
        Map<String, Boolean> fieldPermissions = new Map<String, Boolean>();
        System.debug('teamView: ' + teamView);
        System.debug('viewAll: ' + viewAll);
        System.debug('UserInfo.getUserId() : ' + UserInfo.getUserId() );
        if(objectApiName == 'ProjectShareclass__c'){
            objectApiName = 'ProjectShareclassChild__c';
        }
        
        try {    
            // Fetch Field Permissions based on the appropriate permission set
            List<FieldPermissions> permissions = new List<FieldPermissions>();

            if(viewAll){
                permissions = [
                    SELECT Field, PermissionsEdit, Parent.Name
                    FROM FieldPermissions 
                    WHERE SObjectType = :objectApiName
                    AND Parent.Name = 'PRPMinimumAccess'
                ];
            } else{

                permissions = [
                    SELECT Field, PermissionsEdit, Parent.Name
                    FROM FieldPermissions 
                    WHERE SObjectType = :objectApiName
                    AND PermissionsEdit = true 
                    AND Parent.Name = :teamView
                ];
               
            }
            System.debug('Permissions Retrieved: ' + permissions);
            for (FieldPermissions perm : permissions) {
                fieldPermissions.put(perm.Field, perm.PermissionsEdit);
            }
            if (!viewAll && teamView == 'PRPProductStrategy' && objectApiName == 'ProjectShareclassChild__c') {
                fieldPermissions.put('ProjectShareclassChild__c.CurrencyIsoCode', true);
            }
            if (viewAll && teamView == 'PRPProductStrategy' && objectApiName == 'ProjectShareclassChild__c') {
                fieldPermissions.put('ProjectShareclassChild__c.CurrencyIsoCode', false);
            }
    
        } catch (Exception e) {
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
            System.debug('(type.getDescribe().getKeyPrefix()) => '+(type.getDescribe().getKeyPrefix()));
            System.debug('objectPrefix) => '+objectPrefix);
            if((type.getDescribe().getKeyPrefix()) != null){
                if ( (type.getDescribe().getKeyPrefix()).equals(objectPrefix)) {
                    sObjectType = type.getDescribe().getName();
                    break;
                }
            }
        }

        if (String.isBlank(sObjectType)) {
            throw new AuraHandledException('Unsupported or unknown SObject type.');
        }
        if(SObjectType == 'ProjectShareclassChild__c'){
            sObjectType = 'ProjectShareclass__c';
            recordId = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId].ProjectShareclasses__c; // Get the parent record Id
        } else if(SObjectType == 'ProjectProductChild__c'){
            sObjectType = 'ProjectProduct__c';
            recordId = [SELECT ProjectProductParent__c FROM ProjectProductChild__c WHERE id =: recordId].ProjectProductParent__c; // Get the parent record Id

        }
        // Describe fields for the object
        Schema.SObjectType objType = globalDescribe.get(sObjectType);
        
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        System.debug('fieldsMap: ' + fieldsMap.values());

        String soqlFields = String.join(new List<String>(fieldsMap.keySet()), ',');

        // Dynamically build SOQL and query
        String soql = 'SELECT ' + soqlFields + ' FROM ' + sObjectType + ' WHERE Id = :recordId';
        SObject record = Database.query(soql);

        // Return fields as a Map<String, Object>
        Map<String, Object> result = new Map<String, Object>();
        for (String fieldName : fieldsMap.keySet()) {
            // System.debug('fieldsMap.get(fieldName): ' + fieldsMap.get(fieldName));
            result.put(fieldsMap.get(fieldName).getDescribe().getName(), record.get(fieldName));
        }
        System.debug('Retrieved fields: ' + result);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean getUserPermissionSet(String teamView) {
        System.debug('teamView getUserPermissionSet: ' + teamView);

        try {
            List<PermissionSetAssignment> permSet = [
                SELECT PermissionSet.Name 
                FROM PermissionSetAssignment 
                WHERE AssigneeId = :UserInfo.getUserId() 
                AND PermissionSet.Name = :teamView
                LIMIT 1
            ];

            return !permSet.isEmpty(); // Returns TRUE if user has permission set, FALSE otherwise
        } catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkEditableConidtions(String recordId, String objectApiName) {

        try {
            // return true;
            if(objectApiName == 'ProjectProductChild__c'){
                List<ProjectProductChild__c> project2 = [
                    SELECT id , ProjectProductParent__r.RecordType.DeveloperName,TECH_DoNotProcess__c
                    FROM ProjectProductChild__c 
                    WHERE Id = :recordId AND (TECH_DoNotProcess__c = false OR ProjectProductParent__r.RecordType.DeveloperName like '%Modification%' ) // AND 
                ];
                return !project2.isEmpty(); //si modification return true
            }
            else if(objectApiName == 'ProjectShareclassChild__c'){
                List<ProjectShareclassChild__c> project2 = [
                    SELECT id ,TECH_DoNotProcess__c
                    FROM ProjectShareclassChild__c 
                    WHERE Id = :recordId  AND (TECH_DoNotProcess__c = false OR ProjectShareclasses__r.ProjectProduct__r.RecordType.DeveloperName like '%Modification%' ) //AND  
                ];
                return !project2.isEmpty(); //si modification return true

            }
            return false;
        } catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static SObject checkModificationConidtions(String recordId, String objectApiName) {

        try {
            // return true;
            if(objectApiName == 'ProjectProductChild__c'){
                ProjectProductChild__c project2 = [
                    SELECT id , TECH_ProjectRecordType__c,TECH_DoNotProcess__c
                    FROM ProjectProductChild__c 
                    WHERE Id = :recordId LIMIT 1
                ];
                return project2; //si modification return true
            }

            else if(objectApiName == 'ProjectShareclassChild__c'){
                ProjectShareclassChild__c project2 = [
                    SELECT id ,TECH_DoNotProcess__c , TECH_ProjectRecordType__c
                    FROM ProjectShareclassChild__c 
                    WHERE Id = :recordId LIMIT 1
                ];
                return project2; //si modification return true
            }
            return null;
        } catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            return null;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getEditableFieldsFromSourceField(String editableFieldSource, String objectApiName, String recordId) {
        try {
            System.debug('editableFieldSource: ' + editableFieldSource);
            System.debug('objectApiName: ' + objectApiName);
            System.debug('recordId: ' + recordId);
    
            // Check if the field is a relationship field
            Boolean isRelationship = editableFieldSource.contains('.');
    
            String query = 'SELECT ' + editableFieldSource + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
            System.debug('query ' + query);
    
            SObject obj = Database.query(query);
            System.debug('obj => ' + obj);
    
            String fieldValue;
    
            if (isRelationship) {
                // Extract the parent relationship name and field dynamically
                List<String> parts = editableFieldSource.split('\\.');
                String parentRelationship = parts[0];
                String parentField = parts[1];
    
                SObject parentObj = obj.getSObject(parentRelationship);
                if (parentObj != null) {
                    fieldValue = (String) parentObj.get(parentField);
                } else {
                    System.debug('Parent object is null');
                    return new List<String>();
                }
            } else {
                fieldValue = (String) obj.get(editableFieldSource);
            }
    
            System.debug('Field Value: ' + fieldValue);
    
            if (String.isNotBlank(fieldValue)) {
                return fieldValue.split(';');
            }
    
            return new List<String>();
        } catch (Exception e) {
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
            // If the record has no RecordTypeId, get the Master Record Type Id
            
        } catch (Exception e) {
            System.debug('❌ Error fetching user permission set: ' + e.getMessage());
            

            return '012000000000000AAA';
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getFields( String objectVar, String recordId) {   
        List<ProductProjectSettings__c> prodProjectSettingsFields = [
            SELECT RequiredFields__c, RequiredFieldsShareClass__c
            FROM ProductProjectSettings__c 
        ];

        if (prodProjectSettingsFields.isEmpty()) {
            throw new AuraHandledException('Aucun champ trouvé pour la Permission Set.');
        }

        List<String> requiredFields = new List<String>();

        for (ProductProjectSettings__c prodSetting : prodProjectSettingsFields) {
            if (objectVar == 'ProjectProductChild__c') {
                if (prodSetting.RequiredFields__c != null) {
                    requiredFields.addAll(prodSetting.RequiredFields__c.split(';'));
                }
            } else if (objectVar == 'ProjectShareclassChild__c') {
                if (prodSetting.RequiredFieldsShareClass__c != null) {
                    requiredFields.addAll(prodSetting.RequiredFieldsShareClass__c.split(';'));
                }
            }
        }
    
        System.debug('Required Fields: ' + requiredFields);
        
        return requiredFields;
    }
}