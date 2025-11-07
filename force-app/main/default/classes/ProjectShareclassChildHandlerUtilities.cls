public class ProjectShareclassChildHandlerUtilities {

    /*
    //
    public static List<ProjectProductChild__c> getAllFieldsForProjectProductChild(Set<Id> recordIds) {
        if (recordIds.isEmpty()) return new List<ProjectProductChild__c>();
     
        Map<String, Schema.SObjectField> fieldMap = ProjectProductChild__c.SObjectType.getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());
     
        if (!fieldNames.contains('RecordType.DeveloperName')) {
            fieldNames.add('RecordType.DeveloperName');
        }
     
        String query = 'SELECT ' + String.join(fieldNames, ',') +
                       ' FROM ProjectProductChild__c WHERE Id IN :recordIds';
     
        return (List<ProjectProductChild__c>) Database.query(query);
    }    
    
 
    //
    public static List<ProjectShareclassChild__c> getAllFieldsForShareClass(Set<Id> shareClassIds) {
        if (shareClassIds.isEmpty()) return new List<ProjectShareclassChild__c>();
     
        // Récupérer dynamiquement tous les champs de l'objet
        Map<String, Schema.SObjectField> fieldMap = ProjectShareclassChild__c.SObjectType.getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());
     
        // 🔹 Assurer que `RecordType.DeveloperName` est bien présent
        if (!fieldNames.contains('RecordType.DeveloperName')) {
            fieldNames.add('RecordType.DeveloperName');
        }
     
        // Construire la requête SOQL dynamique pour récupérer **tous les champs**
        String query = 'SELECT ' + String.join(fieldNames, ',') +
            ' FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c IN :shareClassIds';
     
        return Database.query(query);
    }
 
    //
    // 🔹 Extraction des IDs de ShareClass depuis une liste de ProjectShareclassChild
    public static Set<Id> getShareClassIds(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild) {
        Set<Id> shareClasses = new Set<Id>();
        for (ProjectShareclassChild__c child : m_newProjectShareclassChild.values()) {
            if (child.ProjectShareclasses__c != null) {
                shareClasses.add(child.ProjectShareclasses__c);
            }
        }
        return shareClasses;
    }
 
    //
    public static Map<Id, Decimal> calculateShareClassCompletion(
        List<ProjectShareclassChild__c> shareClassChildren,
        Map<String, List<String>> requiredFieldsByStage
    ) {
    
        Map<Id, Decimal> completionRates = new Map<Id, Decimal>();
     
        for (ProjectShareclassChild__c shareClassChild : shareClassChildren) {
            // Vérification que `RecordType.DeveloperName` est bien récupéré
            if (shareClassChild.RecordType == null || shareClassChild.RecordType.DeveloperName == null) {
                System.debug('⚠️ WARNING: RecordType.DeveloperName is null for ShareClassChild with ID ' + shareClassChild.Id);
                continue; // Évite l'erreur et passe au suivant
            }
     
            // 🔹 La matrice nous donne les champs à vérifier
            List<String> requiredFields = requiredFieldsByStage.get(shareClassChild.RecordType.DeveloperName);
            if (requiredFields == null) continue;
     
            Integer completedFields = 0;
            Integer totalFields = requiredFields.size();
     
            // 🔹 On vérifie TOUS les champs définis dans la matrice
            for (String field : requiredFields) {
                if (shareClassChild.get(field) != null) {
                    completedFields++;
                }
            }
     
            // 🔹 Calcul du taux de complétion
            Decimal completionRate = (totalFields > 0) ?
                (Decimal.valueOf(completedFields) / totalFields) * 100 : 0;
     
            // 🔹 Stockage du taux pour la `Shareclass`
            completionRates.put(shareClassChild.ProjectShareclasses__c, completionRate.setScale(2));
        }
     
        return completionRates;
    } */
}