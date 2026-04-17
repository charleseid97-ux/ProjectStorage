/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 20-02-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public class ShareClassViewAllController  { 

        public class FieldMetadata {
            @AuraEnabled public String apiName;
            @AuraEnabled public String label;
            @AuraEnabled public Object value;
        
            public FieldMetadata(String apiName, String label, Object value) {
                this.apiName = apiName;
                this.label = label;
                this.value = value;
            }
        }
        public class ShareClassWrapper {
            @AuraEnabled public Id recordId;
            @AuraEnabled public String name;
            @AuraEnabled public List<FieldMetadata> fields;
        
            public ShareClassWrapper(Id recordId, String name, List<FieldMetadata> fields) {
                this.recordId = recordId;
                this.name = name;
                this.fields = fields;
            }
        }
       
        @AuraEnabled(cacheable=true)
        public static List<ShareClassWrapper> getProjectShareclasses(Id parentId) {
            try {
                List<ProjectChildJunction__c> junctions = [ SELECT Id, ProjectShareclass__c FROM ProjectChildJunction__c WHERE ProjectProductChild__r.ProjectProductParent__c = :parentId ]; 
                // Extraire les IDs des ProjectShareclass__c 
                Set<Id> shareClassIds = new Set<Id>(); 
                for(ProjectChildJunction__c junction : junctions) { 
                    if(junction.ProjectShareclass__c != null) { 
                        shareClassIds.add(junction.ProjectShareclass__c); 
                    } 
                } 

                // Récupérer les métadonnées des champs
                Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ProjectShareclass__c.fields.getMap();
                List<String> fieldsToQuery = new List<String>();
                Map<String, String> fieldLabels = new Map<String, String>();
            
                for(String fieldName : fieldMap.keySet()) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                    if(
                    !fieldName.equalsIgnoreCase('IsDeleted') &&
                    !fieldName.equalsIgnoreCase('CreatedDate') &&
                    !fieldName.equalsIgnoreCase('CreatedById') &&
                    !fieldName.equalsIgnoreCase('LastModifiedDate') &&
                    !fieldName.equalsIgnoreCase('LastModifiedById') &&
                    !fieldName.equalsIgnoreCase('SystemModstamp') &&
                    !fieldName.equalsIgnoreCase('LastActivityDate') &&
                    !fieldName.equalsIgnoreCase('LastViewedDate') &&
                    !fieldName.equalsIgnoreCase('LastReferencedDate') &&
                    !fieldName.equalsIgnoreCase('OwnerId')) {
                
                        fieldsToQuery.add(fieldName);
                        fieldLabels.put(fieldName, fieldDescribe.getLabel());
                        System.debug('field : '+fieldName + '=> ' + fieldDescribe.getLabel());
                    }
                }
            
                // Construire et exécuter la requête SOQL
                String query = 'SELECT ' + String.join(fieldsToQuery, ',');
                query += ' FROM ProjectShareclass__c';
                query += ' WHERE Id IN :shareClassIds';
            
                List<SObject> records = Database.query(query);
                List<ShareClassWrapper> wrappers = new List<ShareClassWrapper>();
            
                // Créer les wrappers avec les métadonnées
                for(SObject record : records) {
                    List<FieldMetadata> fields = new List<FieldMetadata>();
                
                    for(String fieldName : fieldsToQuery) {
                        if(fieldName != 'Id' && fieldName != 'Name') {
                            System.debug('value : '+fieldName + ' , ' + fieldLabels.get(fieldName) + ' => ' + record.get(fieldName));
                            fields.add(new FieldMetadata(
                                fieldName,
                                fieldLabels.get(fieldName),
                                record.get(fieldName)
                            ));
                        }
                    }
                
                    wrappers.add(new ShareClassWrapper(
                        (Id)record.get('Id'),
                        (String)record.get('Share_Class_Name__c'),
                        fields
                    ));
                }
            
                return wrappers;
            } catch(Exception e) {
                throw new AuraHandledException('Erreur lors de la récupération des données: ' + e.getMessage());
            }
        }
    /*
    @AuraEnabled(cacheable=true) 
    public static List<ProjectShareclass__c> getProjectShareclasses(Id parentId) { 
        List<ProjectShareclass__c> shareClasses = new List<ProjectShareclass__c>(); 
        try { 
            // Récupérer tous les ProjectChildJunction__c liés au parent 
            List<ProjectChildJunction__c> junctions = [ SELECT Id, ProjectShareclass__c FROM ProjectChildJunction__c WHERE ProjectProductChild__r.ProjectProductParent__c = :parentId ]; 
            // Extraire les IDs des ProjectShareclass__c 
            Set<Id> shareClassIds = new Set<Id>(); 
            for(ProjectChildJunction__c junction : junctions) { 
                if(junction.ProjectShareclass__c != null) { 
                    shareClassIds.add(junction.ProjectShareclass__c); 
                } 
            } 
            // Récupérer tous les champs de l'objet ProjectShareclass__c
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ProjectShareclass__c.fields.getMap();
            
            // Créer une liste de champs en excluant les champs système
            Set<String> fieldsToQuery = new Set<String>();  // On garde toujours Id et Name
            
            for(String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                // Exclure les champs système
                if(
                   !fieldName.equalsIgnoreCase('IsDeleted') &&
                   !fieldName.equalsIgnoreCase('CreatedDate') &&
                   !fieldName.equalsIgnoreCase('CreatedById') &&
                   !fieldName.equalsIgnoreCase('LastModifiedDate') &&
                   !fieldName.equalsIgnoreCase('LastModifiedById') &&
                   !fieldName.equalsIgnoreCase('SystemModstamp') &&
                   !fieldName.equalsIgnoreCase('LastActivityDate') &&
                   !fieldName.equalsIgnoreCase('LastViewedDate') &&
                   !fieldName.equalsIgnoreCase('LastReferencedDate') &&
                   !fieldName.equalsIgnoreCase('OwnerId')) {
                    fieldsToQuery.add(fieldName);
                    system.debug('field : '+fieldName);
                }
            }
            // Récupérer les détails des ProjectShareclass__c 
            if(!shareClassIds.isEmpty()) { 
                String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ',');
                query += ' FROM ProjectShareclass__c';
                query += ' WHERE Id IN :shareClassIds';
                shareClasses = Database.query(query); 
            } 
        } 
        catch(Exception e) { 
            throw new AuraHandledException('Erreur lors de la récupération des données: ' + e.getMessage()); 
        } 
        system.debug('shareClasses : '+shareClasses[0].DecimalsMaxShares__c);
        return shareClasses; 
    } */
}