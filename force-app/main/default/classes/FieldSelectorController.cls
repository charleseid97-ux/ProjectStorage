/** ──────────────────────────────────────
 * @description Controller of the fieldSelector LWC (PMT modification projects).
 *              Lists the selectable fields and their dependent fields (PMTField__mdt.IsSensitive__c and DependentFields__c, US-20194 V1.2,
 *              formerly Sensitive_field__mdt and FieldDisplayRule__mdt), and saves the selection in TECH_FieldsToModify__c on the
 *              Project Product or Project Share Class.
 *              Save errors (e.g. phase already validated) are returned to the LWC as an AuraHandledException.
 * @testClass Test_FieldSelectorController
 * @coverage 100%   [28-10-26]
 * @lastModifiedBy Charles EID   [28-10-26]
 ────────────────────────────────────── */
public without sharing class FieldSelectorController {
    private static final String VALIDATION_ERROR_PREFIX = 'FIELD_CUSTOM_VALIDATION_EXCEPTION, ';

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDependentFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        String catalogObject = getCatalogObject(objectApiName);
        for (PMTField__mdt field : [SELECT FieldApiName__c, DependentFields__c
                                    FROM PMTField__mdt
                                    WHERE Object__c = :catalogObject AND DependentFields__c != null ORDER BY DeveloperName]) {
            fieldList.add(new Map<String, String>{
                'controllingField' => field.FieldApiName__c,
                'dependentFields' => field.DependentFields__c
            });
        }
        return fieldList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMetadataFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        String catalogObject = getCatalogObject(objectApiName);
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(catalogObject).getDescribe().fields.getMap();
        for (PMTField__mdt field : [SELECT FieldApiName__c
                                    FROM PMTField__mdt
                                    WHERE Object__c = :catalogObject AND IsSensitive__c = true ORDER BY DeveloperName]) {
            if (!fieldMap.containsKey(field.FieldApiName__c)) continue;
            Schema.DescribeFieldResult fieldDesc = fieldMap.get(field.FieldApiName__c).getDescribe();
            fieldList.add(new Map<String, String>{
                'value' => fieldDesc.getName(),
                'label' => fieldDesc.getLabel(),
                'type' => String.valueOf(fieldDesc.getType())
            });
        }
        return fieldList;
    }

    // PMTField__mdt.Object__c of the LWC's object: Product__c, or Share_Class__c (passed as Parent_Share_Class__c or Share_Class__c).
    private static String getCatalogObject(String objectApiName) {
        return objectApiName == 'Product__c' ? 'Product__c' : 'Share_Class__c';
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSelectedFields(Id recordId, String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        String fieldsToModify;
        if (objectApiName == 'Parent_Share_Class__c') {
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :recordId LIMIT 1].TECH_FieldsToModify__c;
            objectApiName = 'Share_Class__c';
        }
        else if (objectApiName == 'Share_Class__c') {
            ProjectShareclassChild__c parentRecord = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId LIMIT 1];
            fieldsToModify = [SELECT TECH_FieldsToModify__c
                              FROM ProjectShareclass__c
                              WHERE Id = :parentRecord.ProjectShareclasses__c LIMIT 1].TECH_FieldsToModify__c;
        }
        else {
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectProduct__c WHERE Id = :recordId LIMIT 1].TECH_FieldsToModify__c;
        }

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
            }
        }
        return fieldList;
    }

    @AuraEnabled
    public static void updateSelectedFields(Id recordId, List<String> selectedFields, String objectApiName) {
        String fieldsString = String.join(selectedFields, ';');

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
            if (startIndex != -1) message = message.substring(startIndex + VALIDATION_ERROR_PREFIX.length()).substringBefore(': [');
            AuraHandledException auraException = new AuraHandledException(message);
            auraException.setMessage(message);
            throw auraException;
        }
    }
}