public with sharing class RoadToMarketFormController {
    /**
     * Méthode principale pour recuperer RoadTomarket
     * @param recordId
     */
    @AuraEnabled(Cacheable=false)
    public static RoadToMarket__c  getRoadToMarketrecordById(ID recordId){
        RoadToMarket__c roadtomarket=[SELECT Id , StartDate__c , EndDate__c , RoadToMarketStatus__c , Parent_Project__c FROM RoadToMarket__c where Parent_Project__c= :recordId limit 1];
      return   roadtomarket;
    }
    /**
     * Méthode Get SETUP du projet
     * @param recordId
     */
    @AuraEnabled
    public static List<Map<String, Object>> getStepsWithMilestones(ID recordId) {
        // Liste pour contenir les étapes avec leurs jalons (milestones)
        List<Map<String, Object>> steps = new List<Map<String, Object>>();

        // Requête SOQL pour récupérer les étapes (ChildProject) et leurs jalons (Milestones)
        List<ProjectProductChild__c> projects = [
            SELECT Id, Name, StartDate__c, EndDate__c, Status__c, CompletionRateStep__c,
                   (SELECT Id, Name, StartDate__c , 	Status__c  FROM Milestones__r)
            FROM ProjectProductChild__c where ProjectProductParent__c= :recordId
        ];

        // Transformer les données pour les envoyer au LWC
        for (ProjectProductChild__c project : projects) {
            Map<String, Object> step = new Map<String, Object>();
            step.put('id', project.Id);
            step.put('name', project.Name);
            step.put('startDate', project.StartDate__c);
            step.put('endDate', project.EndDate__c);
            step.put('status', project.Status__c);
            step.put('progress', project.CompletionRateStep__c);

            // Préparer les jalons (milestones) pour chaque étape
            List<Map<String, Object>> milestones = new List<Map<String, Object>>();
            for (Milestone__c milestone : project.Milestones__r) {
                milestones.add(new Map<String, Object>{
                    'id' => milestone.Id,
                    'name' => milestone.Name,
                    'status' => milestone.Status__c ,
                    'date' => milestone.StartDate__c
                });
            }
            step.put('milestones', milestones);

            // Ajouter l'étape complète à la liste
            steps.add(step);
        }

        return steps;
    }
}