public class displayProjectChildReadOnlyController {
    /**
    * Récupère la liste des API Names des Permission Sets associés à l'utilisateur actuel.
    * @return Liste des API Names des Permission Sets.
    */
    @AuraEnabled(cacheable=true)
    public static List<String> getUserPermissionSets() {
        try {
            List<String> userPermissionSets = new List<String>();
 
            // Query pour récupérer les permission sets assignés à l'utilisateur actuel
            List<PermissionSetAssignment> assignments = [
                SELECT PermissionSet.Name 
                FROM PermissionSetAssignment 
                WHERE AssigneeId = :UserInfo.getUserId()
            ];
 
            // Extraire les noms des permission sets
            for (PermissionSetAssignment assignment : assignments) {
                userPermissionSets.add(assignment.PermissionSet.Name);
            }
 
            return userPermissionSets;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la récupération des permission sets : ' + e.getMessage());
        }
    }

    /**
     * Récupère les champs accessibles en lecture pour une Permission Set spécifique
     * et leurs valeurs pour un enregistrement spécifique.
     * @param permissionSetApiName API Name de la Permission Set.
     * @param recordId ID de l'enregistrement pour lequel récupérer les valeurs.
     * @return Liste de champs avec labels, API Names et leurs valeurs.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getFields(String permissionSetApiName, String recordId) {
        List<Map<String, Object>> fields = new List<Map<String, Object>>();

        // Récupérer les permissions de champ
        List<FieldPermissions> fieldPermissions = [
            SELECT SObjectType, Field, PermissionsRead 
            FROM FieldPermissions 
            WHERE Parent.Name = :permissionSetApiName
        ];
        System.debug('permissionSetApiName:' + permissionSetApiName);

        if (fieldPermissions.isEmpty()) {
            System.debug('Aucun champ trouvé pour la Permission Set.');
            throw new AuraHandledException('Aucun champ trouvé pour la Permission Set.');
        }

        // Construire une requête dynamique avec les champs récupérés
        Set<String> fieldsToQuery = new Set<String>();
        String sObjectType = null;

        for (FieldPermissions perm : fieldPermissions) {
            if (perm.PermissionsRead) {
                System.debug('perm.Field:' + perm.Field);
                fieldsToQuery.add(String.valueOf(perm.Field).replace(perm.SObjectType + '.', ''));
                sObjectType = perm.SObjectType;
            }
        }
        

        if (sObjectType == null) {
            throw new AuraHandledException('Impossible de déterminer le SObjectType.');
        }

        // Générer la requête dynamique
        String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') +
            ' FROM ' + sObjectType + 
            ' WHERE Id = '+'\''+recordId+'\''+' LIMIT 1';

            System.debug('query:' + query);
        List<ProjectProductChild__c> records = Database.query(query);
        System.debug('records:' + records);
        if (!records.isEmpty()) {
            ProjectProductChild__c record = records[0];
               // Récupérer les métadonnées de l'objet pour obtenir les labels des champs
               Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
               .get(sObjectType)
               .getDescribe()
               .fields
               .getMap();
            for (String fieldApi : fieldsToQuery) {
                System.debug('fieldApi:' + fieldApi);
                Map<String, Object> fieldInfo = new Map<String, Object>();
                if (fieldMap.containsKey(fieldApi)) {
                    String label = fieldMap.get(fieldApi).getDescribe().getLabel();
                    fieldInfo.put('label', label); // Label lisible du champ
                } else {
                    fieldInfo.put('label', fieldApi); // Fallback au nom API si le label n'est pas trouvé
                }

                fieldInfo.put('apiName', fieldApi);
                
                fieldInfo.put('value', record.get(fieldApi)); // Valeur du champ
                System.debug('value:' + record.get(fieldApi));
                fields.add(fieldInfo);
            }
        }

        return fields;
    }
}