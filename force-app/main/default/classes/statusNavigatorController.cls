public class statusNavigatorController {
    @AuraEnabled(cacheable=true)
    public static Id getMatchingProjectProductChild(Id shareclassChildId) {
        try {
            ProjectShareclassChild__c shareclassChild = [
                SELECT ProjectShareclasses__c, TECH_Childtype__c 
                FROM ProjectShareclassChild__c 
                WHERE Id = :shareclassChildId 
                LIMIT 1
            ];
            if (shareclassChild == null || shareclassChild.ProjectShareclasses__c == null) {
                return null;
            }
 
            List<ProjectChildJunction__c> junctions = [
                SELECT ProjectProductChild__c 
                FROM ProjectChildJunction__c 
                WHERE ProjectShareclass__c = :shareclassChild.ProjectShareclasses__c
            ];
            if (junctions.isEmpty()) {
                return null;
            }
 
            Set<Id> projectProductChildIds = new Set<Id>();
            for (ProjectChildJunction__c junction : junctions) {
                projectProductChildIds.add(junction.ProjectProductChild__c);
            }
 
            for (ProjectProductChild__c step : [
                SELECT Id, TECH_Childtype__c, Name
                FROM ProjectProductChild__c 
                WHERE Id IN :projectProductChildIds
            ]) {
                if (step.TECH_Childtype__c == shareclassChild.TECH_Childtype__c) {
                    if (step.Name == 'Design') {
                        continue;
                    }
                    return step.Id;
                }
            }
        } catch (Exception e) {
            System.debug('❌ Erreur getMatchingProjectProductChild: ' + e.getMessage());
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static ProjectProduct__c getProjectProduct(Id projectChildId) {
        try {
            ProjectProductChild__c projectChild = [
                SELECT ProjectProductParent__c
                FROM ProjectProductChild__c
                WHERE Id = :projectChildId
                LIMIT 1
            ];
            
            if (projectChild == null || projectChild.ProjectProductParent__c == null) {
                return null;
            }
 
            return [
                SELECT Id, TECH_DoNotProcess__c, RecordType.DeveloperName
                FROM ProjectProduct__c
                WHERE Id = :projectChild.ProjectProductParent__c
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('❌ Erreur getProjectProduct: ' + e.getMessage());
            return null;
        }
    }

   @AuraEnabled(cacheable=true)
public static List<Map<String, Object>> getSteps(String recordId, String objectApiName) {
    List<Map<String, Object>> steps = new List<Map<String, Object>>();

    if (objectApiName == 'ProjectProductChild__c') {
        ProjectProductChild__c child = [
            SELECT ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (child.ProjectProductParent__c != null) {
            List<ProjectProductChild__c> records = [
                SELECT Id, Name, Status__c
                FROM ProjectProductChild__c
                WHERE ProjectProductParent__c = :child.ProjectProductParent__c
            ];

            for (ProjectProductChild__c record : records) {
                steps.add(new Map<String, Object>{
                    'id' => record.Id,
                    'name' => record.Name,
                    'status' => record.Status__c
                });
            }
        }
    } else if (objectApiName == 'ProjectShareclassChild__c') {
        // Étape 1️⃣ : récupérer le ProjectShareclass parent
        ProjectShareclassChild__c child = [
            SELECT ProjectShareclasses__c
            FROM ProjectShareclassChild__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (child.ProjectShareclasses__c != null) {
            // Étape 2️⃣ : récupérer les ShareclassChild avec leurs TECH_Childtype__c
            List<ProjectShareclassChild__c> shareclassSteps = [
                SELECT Id, Name, TECH_Childtype__c
                FROM ProjectShareclassChild__c
                WHERE ProjectShareclasses__c = :child.ProjectShareclasses__c
            ];

            // Étape 3️⃣ : récupérer les ProductChild correspondants via la table de jonction
            List<ProjectChildJunction__c> junctions = [
                SELECT ProjectShareclass__c, ProjectProductChild__r.Status__c, ProjectProductChild__r.TECH_Childtype__c
                FROM ProjectChildJunction__c
                WHERE ProjectShareclass__c = :child.ProjectShareclasses__c
            ];

            Map<String, String> productChildStatusByType = new Map<String, String>();
            for (ProjectChildJunction__c junc : junctions) {
                productChildStatusByType.put(junc.ProjectProductChild__r.TECH_Childtype__c, junc.ProjectProductChild__r.Status__c);
            }

            // Étape 4️⃣ : Construire les étapes avec les statuts du ProjectProductChild correspondant
            for (ProjectShareclassChild__c record : shareclassSteps) {
                String status = productChildStatusByType.get(record.TECH_Childtype__c);
                if (status == null) status = 'Not started';

                steps.add(new Map<String, Object>{
                    'id' => record.Id,
                    'name' => record.Name,
                    'status' => status
                });
            }
        }
    }
    return steps;
}

    @AuraEnabled(cacheable=true)
    public static Id getProposalStep(Id shareclassChildId) {
        try {
            // 1️⃣ Récupérer le ProjectShareclass associé au ProjectShareclassChild
            ProjectShareclassChild__c shareclassChild = [
                SELECT ProjectShareclasses__c
                FROM ProjectShareclassChild__c
                WHERE Id = :shareclassChildId
                LIMIT 1
            ];
     
            if (shareclassChild == null || shareclassChild.ProjectShareclasses__c == null) {
                return null; // Aucune association trouvée
            }
     
            // 2️⃣ Trouver le ProjectProductChild via ProjectChildJunction__c
            List<ProjectChildJunction__c> junctions = [
                SELECT ProjectProductChild__c
                FROM ProjectChildJunction__c
                WHERE ProjectShareclass__c = :shareclassChild.ProjectShareclasses__c
            ];
     
            if (junctions.isEmpty()) {
                return null; // Pas de lien trouvé
            }
     
            Set<Id> projectProductChildIds = new Set<Id>();
            for (ProjectChildJunction__c junction : junctions) {
                projectProductChildIds.add(junction.ProjectProductChild__c);
            }
     
            // 3️⃣ Trouver le ProjectProductChild qui correspond à Proposal
            for (ProjectProductChild__c step : [
                SELECT Id, Name
                FROM ProjectProductChild__c
                WHERE Id IN :projectProductChildIds
            ]) {
    if (step.Name == 'Proposal') {
    return step.Id; // ✅ On retourne l'ID du Proposal trouvé
                }
            }
     
        } catch (Exception e) {
            System.debug('❌ Erreur getProposalStep: ' + e.getMessage());
        }
     
        return null; // ❌ Aucun Proposal trouvé
    }
 
    @AuraEnabled(cacheable=true)
    public static Id getParentRecord(Id recordId, String objectApiName) {
        if (objectApiName == 'ProjectProductChild__c') {
            ProjectProductChild__c child = [SELECT ProjectProductParent__c FROM ProjectProductChild__c WHERE Id = :recordId LIMIT 1];
            return child.ProjectProductParent__c;
        }
        else if (objectApiName == 'ProjectShareclassChild__c') {
            ProjectShareclassChild__c child = [SELECT ProjectShareclasses__c FROM ProjectShareclassChild__c WHERE Id = :recordId LIMIT 1];
            ProjectChildJunction__c junction = [SELECT ProjectProductChild__c FROM ProjectChildJunction__c WHERE ProjectShareclass__c = :child.ProjectShareclasses__c LIMIT 1];
            return junction.ProjectProductChild__c;
        }
        return null;
    }
 
    @AuraEnabled(cacheable=true)
    public static String getCurrentStep(Id recordId, String objectApiName) {
        String step = null;
     
        if (objectApiName == 'ProjectProductChild__c') {
            ProjectProductChild__c projectChild = [
                SELECT TECH_Childtype__c 
                FROM ProjectProductChild__c 
                WHERE Id = :recordId LIMIT 1
            ];
            step = projectChild.TECH_Childtype__c;
        } else if (objectApiName == 'ProjectShareclassChild__c') {
            ProjectShareclassChild__c shareclassChild = [
                SELECT TECH_Childtype__c 
                FROM ProjectShareclassChild__c 
                WHERE Id = :recordId LIMIT 1
            ];
            step = shareclassChild.TECH_Childtype__c;
        }

        return step;
    }
}