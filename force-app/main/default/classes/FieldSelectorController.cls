public without sharing class FieldSelectorController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDependentFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        System.debug('objectApiName: ' + objectApiName);
        if(objectApiName == 'Parent_Share_Class__c'){
            objectApiName = 'Share_Class';
        }else if(objectApiName == 'Product__c'){
            objectApiName = 'Product';
        }
        
        for (FieldDisplayRule__mdt fieldRecord : [
            SELECT ObjectApiName__c,FieldApiName__c,DependentFields__c FROM FieldDisplayRule__mdt WHERE ObjectApiName__c = :objectApiName
        ]) {
            if(fieldRecord.DependentFields__c != null){
                fieldList.add(new Map<String, String>{
                        'controllingField' => fieldRecord.FieldApiName__c+'__c',
                        'dependentFields' => fieldRecord.DependentFields__c
                });
            }
        }
        system.debug('fieldList: ' + fieldList);
        return fieldList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMetadataFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        System.debug('objectApiName: ' + objectApiName);
        if(objectApiName == 'Parent_Share_Class__c'){
            objectApiName = 'Share_Class__c';

        }
        // Query metadata records
        for (Sensitive_field__mdt fieldRecord : [
            SELECT Object__c,Fields__c FROM Sensitive_field__mdt WHERE Object__c = :objectApiName
        ]) {
            System.debug('fieldRecord: ' + fieldRecord);

            Schema.DescribeFieldResult fieldDesc ;
            for (String fieldApiName : fieldRecord.Fields__c.split(';')) {
                try {
                    System.debug('Field API Name: ' + fieldApiName);
                    fieldDesc = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().get(fieldApiName).getDescribe();
                    fieldList.add(new Map<String, String>{
                        'value' => fieldApiName,
                        'label' => fieldDesc.getLabel(),
                        'type'  => String.valueOf(fieldDesc.getType()) // Ajout du type
                    });
                } catch (Exception e) {
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
        if(objectApiName == 'Parent_Share_Class__c'){
            modificationField = 'TECH_FieldsToModify__c';
            System.debug('modificationField: ' + modificationField);
            System.debug('recordId: ' + recordId);
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :recordId LIMIT 1].TECH_FieldsToModify__c;
            objectApiName = 'Share_Class__c';

        } else if(objectApiName == 'Share_Class__c'){
            modificationField = 'TECH_FieldsToModify__c';
            System.debug('modificationField: ' + modificationField);
            System.debug('recordId: ' + recordId);
            ProjectShareclassChild__c parentRecord = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId LIMIT 1];
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :parentRecord.ProjectShareclasses__c LIMIT 1].TECH_FieldsToModify__c;

        } else{
            fieldsToModify = [SELECT TECH_FieldsToModify__c FROM ProjectProduct__c WHERE Id = :recordId LIMIT 1].TECH_FieldsToModify__c;

        }
        System.debug('fieldsToModify: ' + fieldsToModify);

        if (String.isNotBlank(fieldsToModify)) {
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

            for (String fieldApiName : (fieldsToModify).split(';')) {
                if (fieldMap.containsKey(fieldApiName)) {
                    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldApiName).getDescribe();
                    fieldList.add(new Map<String, String>{
                        'value' => fieldApiName,
                        'label' => fieldDesc.getLabel()
                    });
                } else {
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
        if(objectApiName == 'Parent_Share_Class__c'){
            ProjectShareclass__c record = new ProjectShareclass__c(Id = recordId);
            record.TECH_FieldsToModify__c = fieldsString;
            update record;
            // ProjectShareclassChild__c recordChildToUpdate = new ProjectShareclassChild__c(Id = recordId);
            // for(String field : selectedFields) {
            //     recordChildToUpdate.put(field, null);
            // }
            // update recordChildToUpdate;
        }
        else if(objectApiName == 'Share_Class__c'){
            ProjectShareclassChild__c recordChild = [SELECT ProjectShareclasses__c  FROM ProjectShareclassChild__c WHERE Id = :recordId LIMIT 1];
            ProjectShareclass__c record = new ProjectShareclass__c(Id = recordChild.ProjectShareclasses__c);
            record.TECH_FieldsToModify__c = fieldsString;
            update record;
            // ProjectShareclassChild__c recordChildToUpdate = new ProjectShareclassChild__c(Id = recordId);
            // for(String field : selectedFields) {
            //     recordChildToUpdate.put(field, null);
            // }
            // update recordChildToUpdate;
        }else {
                ProjectProduct__c record = new ProjectProduct__c(Id = recordId);
                record.TECH_FieldsToModify__c = fieldsString;
                update record;
                // List<ProjectProductChild__c> recordChildToUpdate = [SELECT id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :recordId];
                // for(ProjectProductChild__c recordChild : recordChildToUpdate) {
                //     // recordChild.put('Status__c', 'Draft');

                //     for(String field : selectedFields) {
                //         recordChild.put(field, null);
                //     }
                // }
                // update recordChildToUpdate;
            }
    }
}