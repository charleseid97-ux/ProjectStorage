public class ExportProjectDataControllerUtilities {
    // ✅ Définition des champs à exclure pour ProjectProduct
    private static final Set<String> SYSTEM_FIELDS_PRODUCT = new Set<String>{
        'ownerid', 'isdeleted', 'currencyisocode', 'recordtypeid', 
        'createddate', 'createdbyid', 'lastmodifieddate', 
        'lastmodifiedbyid', 'systemmodstamp', 'lastactivitydate', 
        'lastvieweddate', 'lastreferenceddate', 'tech_recordlinkroadtomarket__c', 
        'datadicurl__c', 'tech_recordlink__c', 'tech_rtname__c'
    };
 
    private static final Set<String> DEV_FIELDS_PRODUCT = new Set<String>{
        'tech_adminacess__c', 'tech_isnew__c', 'communication__c', 
        'dco__c', 'dcr__c', 'esg__c', 'finance__c', 'investmentperf__c', 
        'is__c', 'legal__c', 'ops__c', 'productstrategy__c', 
        'risk__c', 'tax__c', 'technology__c'
    };
 
    // ✅ Définition des champs à exclure pour ProjectShareclass
    private static final Set<String> SYSTEM_FIELDS_SHARECLASS = new Set<String>{
        'ownerid', 'isdeleted', 'createddate', 'createdbyid', 
        'lastmodifieddate', 'lastmodifiedbyid', 'systemmodstamp', 
        'lastactivitydate'
    };
 
    public static List<String> getExportableFields(String objectName, Map<String, String> fieldLabels) {
        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        List<String> exportableFields = new List<String>();
 
        // Sélection des champs en excluant les champs systèmes et techniques
        for (String fieldName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult fieldDesc = fieldsMap.get(fieldName).getDescribe();
            String lowerFieldName = fieldName.toLowerCase();
 
            if (objectName == 'ProjectProduct__c' && !SYSTEM_FIELDS_PRODUCT.contains(lowerFieldName) && !DEV_FIELDS_PRODUCT.contains(lowerFieldName)) {
                exportableFields.add(fieldName);
                fieldLabels.put(fieldName, fieldDesc.getLabel());
            }
            else if (objectName == 'ProjectShareclass__c' && !SYSTEM_FIELDS_SHARECLASS.contains(lowerFieldName)) {
                exportableFields.add(fieldName);
                fieldLabels.put(fieldName, fieldDesc.getLabel());
            }
        }
 
        return exportableFields;
    }
 
    public static ProjectProduct__c getProjectProduct(Id recordId, List<String> fields) {
        if (fields.isEmpty()) {
            System.debug('⚠️ Aucun champ disponible pour ProjectProduct__c');
            return null;
        }
 
        String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ProjectProduct__c WHERE Id = :recordId LIMIT 1';
        List<ProjectProduct__c> results = Database.query(query);
        return results.isEmpty() ? null : results[0];
    }
 
    public static List<ProjectShareclass__c> getProjectShareclasses(Id projectProductId, List<String> fields) {
        if (fields.isEmpty()) {
            System.debug('⚠️ Aucun champ disponible pour ProjectShareclass__c');
            return new List<ProjectShareclass__c>();
        }
 
        String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ProjectShareclass__c WHERE ProjectProduct__c = :projectProductId';
        return Database.query(query);
    }
}