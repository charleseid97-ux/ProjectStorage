/** ──────────────────────────────────────
 * @description Controller of the fieldSelector LWC (PMT modification projects).
 *              Lists the selectable fields (Sensitive_field__mdt) and their dependent fields (FieldDisplayRule__mdt),
 *              and saves the selection in TECH_FieldsToModify__c on the Project Product or Project Share Class.
 *              Save errors (e.g. phase already validated) are returned to the LWC as an AuraHandledException.
 * @testClass Test_FieldSelectorController
 * @coverage 99%   [12-10-26]
 * @lastModifiedBy Charles EID   [12-10-26]
 ────────────────────────────────────── */
public without sharing class FieldSelectorController {
    private static final String VALIDATION_ERROR_PREFIX = 'FIELD_CUSTOM_VALIDATION_EXCEPTION, ';

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDependentFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        System.debug('objectApiName: ' + objectApiName);
        if (objectApiName == 'Parent_Share_Class__c') {
            objectApiName = 'Share_Class';
        }
        else if (objectApiName == 'Product__c') {
            objectApiName = 'Product';
        }

        for (FieldDisplayRule__mdt fieldRecord : [SELECT ObjectApiName__c, FieldApiName__c, DependentFields__c
                                                  FROM FieldDisplayRule__mdt
                                                  WHERE ObjectApiName__c = :objectApiName]) {
            if (fieldRecord.DependentFields__c != null) {
                fieldList.add(new Map<String, String>{
                    'controllingField' => fieldRecord.FieldApiName__c + '__c',
                    'dependentFields'  => fieldRecord.DependentFields__c
                });
            }
        }
        System.debug('fieldList: ' + fieldList);
        return fieldList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMetadataFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        System.debug('objectApiName: ' + objectApiName);
        if (objectApiName == 'Parent_Share_Class__c') {
            objectApiName = 'Share_Class__c';
        }

        Schema.DescribeFieldResult fieldDesc;
        for (Sensitive_field__mdt fieldRecord : [SELECT Object__c, Fields__c FROM Sensitive_field__mdt WHERE Object__c = :objectApiName]) {
            System.debug('fieldRecord: ' + fieldRecord);
            for (String fieldApiName : fieldRecord.Fields__c.split(';')) {
                try {
                    System.debug('Field API Name: ' + fieldApiName);
                    fieldDesc = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().get(fieldApiName).getDescribe();
                    fieldList.add(new Map<String, String>{
                        'value' => fieldApiName,
                        'label' => fieldDesc.getLabel(),
                        'type'  => String.valueOf(fieldDesc.getType())
                    });
                }
                catch (Exception e) {
                    System.debug('Field not found: ' + fieldApiName);
                }
            }
        }
        System.debug('fieldList: ' + fieldList);
        return fieldList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSelectedFields(Id recordId, String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        String modificationField = 'TECH_FieldsToModify__c';
        String fieldsToModify;
        if (objectApiName == 'Parent_Share_Class__c') {
            modificationField = 'TECH_FieldsToModify__c';
            System.debug('modificationField: ' + modificationField);
            System.debug('recordId: ' + recordId);
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :recordId LIMIT 1].TECH_FieldsToModify__c;
            objectApiName = 'Share_Class__c';
        }
        else if (objectApiName == 'Share_Class__c') {
            modificationField = 'TECH_FieldsToModify__c';
            System.debug('modificationField: ' + modificationField);
            System.debug('recordId: ' + recordId);
            ProjectShareclassChild__c parentRecord = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId LIMIT 1];
            fieldsToModify = [SELECT TECH_FieldsToModify__c
                              FROM ProjectShareclass__c
                              WHERE Id = :parentRecord.ProjectShareclasses__c LIMIT 1].TECH_FieldsToModify__c;
        }
        else {
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectProduct__c WHERE Id = :recordId LIMIT 1].TECH_FieldsToModify__c;
        }
        System.debug('fieldsToModify: ' + fieldsToModify);

        if (String.isNotBlank(fieldsToModify)) {
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
            for (String fieldApiName : fieldsToModify.split(';')) {
                if (fieldMap.containsKey(fieldApiName)) {
                    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldApiName).getDescribe();
                    fieldList.add(new Map<String, String>{
                        'value' => fieldApiName,
                        'label' => fieldDesc.getLabel()
                    });
                }
                else {
                    System.debug('Field not found: ' + fieldApiName);
                }
            }
        }
        System.debug('fieldList: ' + fieldList);
        return fieldList;
    }

    @AuraEnabled
    public static void updateSelectedFields(Id recordId, List<String> selectedFields, String objectApiName) {
        String fieldsString = String.join(selectedFields, ';');
        System.debug('fieldsString: ' + fieldsString);

        SObject record;
        if (objectApiName == 'Parent_Share_Class__c') {
            record = new ProjectShareclass__c(Id = recordId, TECH_FieldsToModify__c = fieldsString);
        }
        else if (objectApiName == 'Share_Class__c') {
            ProjectShareclassChild__c recordChild = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId LIMIT 1];
            record = new ProjectShareclass__c(Id = recordChild.ProjectShareclasses__c, TECH_FieldsToModify__c = fieldsString);
        }
        else {
            record = new ProjectProduct__c(Id = recordId, TECH_FieldsToModify__c = fieldsString);
        }

        // FIX-20269: sans ce catch, l'erreur DML (ex. phase déjà validée) n'arrivait jamais à l'utilisateur
        try {
            update record;
        }
        catch (DmlException e) {
            // Les addError des enfants (ex. PMT_PhaseAlreadyValidated) remontent imbriqués dans l'erreur du trigger parent : on ne garde que le texte du dernier FIELD_CUSTOM_VALIDATION_EXCEPTION
            String message = e.getDmlMessage(0);
            Integer startIndex = message.lastIndexOf(VALIDATION_ERROR_PREFIX);
            if (startIndex != -1) {
                message = message.substring(startIndex + VALIDATION_ERROR_PREFIX.length()).substringBefore(': [');
            }
            AuraHandledException auraException = new AuraHandledException(message);
            auraException.setMessage(message);
            throw auraException;
        }
    }
}