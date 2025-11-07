public without sharing class RecordCloneHelper {

    private static Map<String,Set<String>> EXCLUDED_FIELDS_CACHE;
    private static Boolean isProjectModification = false;

    @TestVisible private static void resetExcludedCache() {
        EXCLUDED_FIELDS_CACHE = null;
    }

    private static Set<String> standardFieldsToExclude = new Set<String>{
        'id', 'name', 'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid', 'systemmodstamp', 'isdeleted', 'ownerid', 'recordtypeid', 'lastactivitydate', 'lastvieweddate', 'lastreferenceddate'
    };
    /**
     * Charge (une fois) la liste des champs à exclure depuis la CMDT.
     * Utilise SOQL pour éviter la troncature 255 chars de getAll().
     */
    private static Map<String,Set<String>> loadExcludedFields() {
        system.debug('loadExcludedFields');
         Map<String,Set<String>> out = new  Map<String,Set<String>>();
        // 1 seule requête, même s'il y a plusieurs enregistrements CMDT
        for (PMTExclusionsField__mdt r :
             [SELECT DeveloperName, FieldsToExclude__c FROM PMTExclusionsField__mdt]) {
                out.put(r.DeveloperName, new Set<String>());

            if (String.isBlank(r.FieldsToExclude__c)) continue;

            // Normalisation robuste : ; , retours ligne / tab
            String normalized = r.FieldsToExclude__c.replace('\r',';')
                                                    .replace('\n',';')
                                                    .replace('\t',';')
                                                    .replace(',', ';');
            for (String token : normalized.split(';')) {
                if (String.isNotBlank(token)) {
                    out.get(r.DeveloperName).add(token.trim().toLowerCase());
                }
            }
        }
        return out;
    }

    /**
     * Récupère l'ensemble global des champs à exclure (défauts + metadata) sans distinction d'objet. (PMTExclusionsField__mdt) 
     * @return Un Set<String> de champs à exclure.
     */
    private static Map<String,Set<String>> getExcludedFields() {
        if (EXCLUDED_FIELDS_CACHE == null) {
            EXCLUDED_FIELDS_CACHE = loadExcludedFields(); // 1 SOQL max / transaction
        }
        return EXCLUDED_FIELDS_CACHE;
        /*Set<String> excludedFields = new Set<String>();

        //for (PMTExclusionsField__mdt exclusion : [SELECT FieldsToExclude__c FROM PMTExclusionsField__mdt]) {
        for(PMTExclusionsField__mdt exclusion : PMTExclusionsField__mdt.getAll().values()){
        if (String.isNotBlank(exclusion.FieldsToExclude__c)) {
                List<String> additionalFields = exclusion.FieldsToExclude__c.split(';');
                for (String field : additionalFields) {
                    excludedFields.add(field.trim().toLowerCase());
                }
            }
        }

        return excludedFields;*/
    }

    /**
     * Dynamically fetches all fields of an object and returns them as a comma-separated string.
     *
     * @param objectName The API name of the object.
     * @return A comma-separated string of field API names.
     */
    public static String getAllFieldNames(String objectName) {
        Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
        List<String> fieldNames = new List<String>();

        for (Schema.SObjectField field : objDescribe.fields.getMap().values()) {
            fieldNames.add(field.getDescribe().getName());
        }

        return String.join(fieldNames, ',');
    }

    /**
     * Clones values from a source record (different object) to a target record,
     * considering fields defined in custom metadata to exclude dynamically.
     *
     * @param sourceRecord Le record source à cloner.
     * @param targetRecord Le record cible à remplir.
     */
    public static SObject cloneRecordFields(SObject sourceRecord, SObject targetRecord) {
        system.debug('========cloneRecordFields method started ========');
        if (sourceRecord == null) {
            throw new IllegalArgumentException('Source record is null.');
        }
        // Retrieve the RecordTypeId for the 'FundShareClassModification' record type
        Id projectModificationRTId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();

        String exclusionListName;
        Boolean isEdit = false;
        String baseName;
        String debugsourceRecordType = sourceRecord.getSObjectType().getDescribe().getName();
        String debugtargetRecordType = targetRecord.getSObjectType().getDescribe().getName();
        system.debug( 'Cloning from ' + debugsourceRecordType + ' to ' + debugtargetRecordType);
        // Determine the object type and whether it's for "edit" or "create"
        switch on String.valueOf(targetRecord.getSObjectType()) {
            when 'ProjectProduct__c' {
            ProjectProduct__c pp = (ProjectProduct__c) targetRecord;
            baseName = 'ProjectProduct';
                isProjectModification = (pp.RecordTypeId == projectModificationRTId);
            }
            when 'ProjectShareclass__c' {
            baseName = 'ProjectShareclass';
            }
            when 'ProjectProductChild__c' {
            baseName = 'ProjectProduct';
            }
            when 'ProjectShareclassChild__c' {
            baseName = 'ProjectShareclass';
            }
            when else {
                // Optional: handle unexpected record types
                System.debug('============Unexpected record type: ' + targetRecord.getSObjectType());
            }
        }

        // Build the exclusion list name dynamically
        exclusionListName = baseName + (isProjectModification ? '_edit' : '');
        System.debug('=======isProjectModification======== ' + isProjectModification);
        System.debug('=======exclusionListName======== ' + exclusionListName);
        try {
            System.debug('Nombre de requêtes SOQL exécutées before: ' + Limits.getQueries());
            Set<String> excludedFields = getExcludedFields().get(exclusionListName);            
            System.debug('Nombre de requêtes SOQL exécutées after: ' + Limits.getQueries());
            Schema.DescribeSObjectResult targetDescribe = targetRecord.getSObjectType().getDescribe();
            Map<String, Schema.SObjectField> targetFields = targetDescribe.fields.getMap();
            for (String fieldNameBrut : sourceRecord.getPopulatedFieldsAsMap().keySet()) {
                String fieldName = fieldNameBrut.toLowerCase();
                system.debug('*************debugsourceRecordType : '+debugsourceRecordType+' fieldNameBrut: ' + fieldNameBrut);
                if (targetFields.containsKey(fieldName) && !excludedFields.contains(fieldName)) {
                    if (!targetFields.get(fieldName).getDescribe().isCalculated()) {
                        System.debug('*************cloned field : '+debugsourceRecordType+' ' + fieldName+' : '+sourceRecord.get(fieldName));
                        targetRecord.put(fieldName, sourceRecord.get(fieldName));
                    }
                }
            }
        } catch (Exception e) {
            throw new IllegalArgumentException('Cloning failed: ' + e.getMessage());
        }
        return targetRecord;
    }
   /**
     * Clones values from a source record (different object) to a target record,
     * considering fields defined in custom metadata to exclude dynamically.
     *
     * @param sourceRecord Le record source à cloner.
     * @param targetRecord Le record cible à remplir.
     */
    public static SObject batchCloneRecordFields(SObject sourceRecord, SObject targetRecord) {
        if (sourceRecord == null) {
            throw new IllegalArgumentException('Source record is null.');
        }
    
        try {
            Schema.DescribeSObjectResult targetDescribe = targetRecord.getSObjectType().getDescribe();
            Map<String, Schema.SObjectField> targetFields = targetDescribe.fields.getMap();
    
            for (String fieldNameBrut : sourceRecord.getPopulatedFieldsAsMap().keySet()) {
                String fieldName = fieldNameBrut.toLowerCase();
                
                if (targetFields.containsKey(fieldName)  && !standardFieldsToExclude.contains(fieldName)) {
                    if (!targetFields.get(fieldName).getDescribe().isCalculated()) {
                        System.debug('*************cloned field : ' + fieldName);
                        targetRecord.put(fieldName, sourceRecord.get(fieldName));
                    }
                }
            }
        } catch (Exception e) {
            throw new IllegalArgumentException('Cloning failed: ' + e.getMessage());
        }
        return targetRecord;
    }
}