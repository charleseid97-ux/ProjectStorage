public without sharing class TaskCompletionByTeamController {
   
    /**
     * 🔹 Récupère les étapes et équipes associées pour un projet donné
     */
    @AuraEnabled
    public static String getStepWithTeams(Id recordId) {
        System.debug('🔹 Fetching steps for record: ' + recordId);
 
        // Récupération des données via des fonctions utilitaires

        List<ProductProjectSettings__c> records = TaskCompletionByTeamControllerUtilities.getProjectStages();
        List<ProductProjectSettings__c> recordsteams = TaskCompletionByTeamControllerUtilities.getDesignTeams();
        
        Map<String, Id> mapteamowner = TaskCompletionByTeamControllerUtilities.getOwnerTeamId(recordId, recordsteams);
        
        Map<Id, String> mapownersName = TaskCompletionByTeamControllerUtilities.getOwnerTeamNameById(mapteamowner.values());
        Map<String, ProjectProductChild__c> stepsrecords = TaskCompletionByTeamControllerUtilities.getProjectChildren(recordId);
 
        // Construction des données
        Map<String, List<Map<String, String>>> stepMap = buildStepMap(records, mapteamowner, mapownersName, stepsrecords);
 
        // Transformation en JSON et retour
        return formatStepsAsJson(stepMap, stepsrecords);
    }
 
    /**
     * 🔹 Construit une map des étapes avec les équipes associées
     */
    private static Map<String, List<Map<String, String>>> buildStepMap(List<ProductProjectSettings__c> records, Map<String, Id> mapteamowner, Map<Id, String> mapownersName, Map<String, ProjectProductChild__c> stepsrecords) {
        Map<String, List<Map<String, String>>> stepMap = new Map<String, List<Map<String, String>>>();
 
        for (ProductProjectSettings__c record : records) {
            String stepName = record.Stage__c;
            String teamName = record.Team__c;
            String teamNameSansSpaces = teamName.replaceAll('\\s', '');
       
            Id ownerId = mapteamowner.get(teamName);
            String owner = mapownersName.get(ownerId);
            ProjectProductChild__c idrecord = stepsrecords.get(stepName);
            if (idrecord == null) continue;
 
            Map<String, String> teamData = createTeamData(record.Id, teamName, owner, idrecord, teamNameSansSpaces);
       
            if (!stepMap.containsKey(stepName)) {
                stepMap.put(stepName, new List<Map<String, String>>());
            }
            stepMap.get(stepName).add(teamData);
        }
        return stepMap;
    }
 
    /**
     * 🔹 Crée une structure de données pour une équipe
     */
    private static Map<String, String> createTeamData(Id recordId, String teamName, String owner, ProjectProductChild__c idrecord, String teamNameSansSpaces) {
        String status = 'Draft';
        String iconName = '🟠';
 
        if (!String.isBlank(idrecord.TECH_TeamValidation__c) && idrecord.TECH_TeamValidation__c.contains(teamNameSansSpaces)) {
            status = 'Completed';
            iconName = '✅';
        } else if (Date.today().daysBetween(idrecord.EndDate__c) <= Math.round(idrecord.StartDate__c.daysBetween(idrecord.EndDate__c) * 0.3)) {
            iconName = '⚠️';
        } else if (Date.today().daysBetween(idrecord.EndDate__c) < 0) {
            iconName = '🚨';
        }
 
        return new Map<String, String>{
            'id' => recordId,
            'name' => teamName,
            'owner' => owner,
            'status' => status,
            'dynamicIcon' => iconName
        };
    }
 
    /**
     * 🔹 Transforme les données en JSON
     */
    private static String formatStepsAsJson(Map<String, List<Map<String, String>>> stepMap, Map<String, ProjectProductChild__c> stepsrecords) {
        List<Map<String, Object>> steps = new List<Map<String, Object>>();
 
        for (String stepName : stepMap.keySet()) {
            ProjectProductChild__c idrecord = stepsrecords.get(stepName);
            if (idrecord == null) continue;
 
            String stepNameFormatted = (stepName == 'Proposal') ? 'Design & Proposal' : stepName;
            if (stepName == 'Design') continue;
 
            steps.add(new Map<String, Object>{
                'id' => idrecord.Id,
                'name' => stepNameFormatted,
                'statustep' => idrecord.Status__c,
                'teams' => stepMap.get(stepName)
            });
        }
 
        String stepsJson = JSON.serialize(steps);
        System.debug('🔹 Steps JSON: ' + stepsJson);
        return stepsJson;
    }
 
    @AuraEnabled
    public static List<TeamCompletionWrapper> getCompletionRatesBulk(List<Id> recordIds, List<String> stepNames, List<String> teamNames) { 
        List<TeamCompletionWrapper> results = new List<TeamCompletionWrapper>(); 
        if (recordIds.isEmpty() || stepNames.isEmpty() || teamNames.isEmpty()) {
            return results;
        }

        // 1. Charger les settings des champs requis
        Map<String, ProductProjectSettings__c> settingsMap = new Map<String, ProductProjectSettings__c>();
        Set<String> allRequiredFields = new Set<String>();
        Set<String> allRequiredFieldsShareclass = new Set<String>();
        for (ProductProjectSettings__c setting : [SELECT Stage__c, Team__c, RequiredFields__c, RequiredFieldsShareClass__c  
                                                    FROM ProductProjectSettings__c 
                                                    WHERE ProjectType__c = 'Creation']) 
        {
            settingsMap.put(setting.Stage__c + '-' + setting.Team__c, setting);
          
            if (setting.RequiredFields__c != null) {
                allRequiredFields.addAll(setting.RequiredFields__c.split(';'));
            }
            if (setting.RequiredFieldsShareClass__c != null) {
                allRequiredFieldsShareclass.addAll(setting.RequiredFieldsShareClass__c.split(';'));
            }
        }
         
        // 2. Récupérer les ProjectProductChild avec les bons champs
        String fieldsQuery = 'Id, Name, RecordType.DeveloperName, ProjectProductParent__c, Status__c, CompletionRateStep__c';
        if (!allRequiredFields.isEmpty()) {
            fieldsQuery += ', ' + String.join(new List<String>(allRequiredFields), ',');
        }

        List<SObject> rawChildren = Database.query('SELECT ' + fieldsQuery + ' FROM ProjectProductChild__c WHERE Id IN :recordIds');
        Map<Id, ProjectProductChild__c> projectProductChildMap = new Map<Id, ProjectProductChild__c>();
        for (SObject s : rawChildren) {
            ProjectProductChild__c child = (ProjectProductChild__c) s;
            projectProductChildMap.put(child.Id, child);
        }
    
         
        // 3. Récupérer les infos de shareclass child
        Set<Id> ppcIds = new Set<Id>(recordIds);
        Map<Id, String> recordTypeById = TaskCompletionByTeamControllerUtilities.getRecordTypeName(ppcIds);
        Map<Id, Set<Id>> ppcToShareclassMap = TaskCompletionByTeamControllerUtilities.getProjectChildShareClasses(ppcIds);
        Map<Id, List<ProjectShareclassChild__c>> shareclassChildrenMap = TaskCompletionByTeamControllerUtilities.getProjectShareclassChildren(ppcToShareclassMap, new List<String>(allRequiredFieldsShareclass));
         
        // 4. Calcul du taux
        for (Integer i = 0; i < recordIds.size(); i++) {
            Id ppcId = recordIds[i];
            String step = stepNames[i];
            String team = teamNames[i];
            String key = step + '-' + team;
         
            ProductProjectSettings__c setting = settingsMap.get(key);
            ProjectProductChild__c projectChild = projectProductChildMap.get(ppcId);
            if (setting == null || projectChild == null) continue;
         
            List<String> requiredFields = (setting.RequiredFields__c != null) ? setting.RequiredFields__c.split(';') : new List<String>();
            Integer completedFields = 0;
            Integer totalFields = requiredFields.size();
         
            for (String field : requiredFields) {
                if (projectChild.get(field) != null) completedFields++;
            }
         
            // Ajout des champs shareclass si pertinents

            List<String> requiredFieldsShareclass = (setting.RequiredFieldsShareClass__c != null) ? setting.RequiredFieldsShareClass__c.split(';') : new List<String>();
            Set<Id> shareClassIds = ppcToShareclassMap.containsKey(ppcId) ? ppcToShareclassMap.get(ppcId) : new Set<Id>();
            if (!shareClassIds.isEmpty()) {
                for (Id shareClassId : shareClassIds) {
                    List<ProjectShareclassChild__c> children = shareclassChildrenMap.get(shareClassId);
                    if (children == null) continue;
                    for (ProjectShareclassChild__c child : children) {
                        if (child.RecordType != null && child.RecordType.DeveloperName == recordTypeById.get(ppcId)) {
                            for (String field : requiredFieldsShareclass) {
                                if (child.get(field) != null) completedFields++;
                            }
                            totalFields += requiredFieldsShareclass.size();
                        }
                    }
                }
            }
         
            Decimal completionRate = (totalFields > 0) ? Decimal.valueOf(completedFields) / totalFields : 0;
 
         
            if (projectChild.Status__c == 'Completed' || totalFields == 0) {
                completionRate = 1;
            }
            results.add(new TeamCompletionWrapper(ppcId, step, team, completionRate.setScale(2)));
        }
        return results;
         
        }
 
    public class TeamCompletionWrapper {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String stepName;
        @AuraEnabled public String teamName;
        @AuraEnabled public Decimal completionRate;
 
        public TeamCompletionWrapper(Id recordId, String stepName, String teamName, Decimal completionRate) {
            this.recordId = recordId;
            this.stepName = stepName;
            this.teamName = teamName;
            this.completionRate = completionRate;
        }
    }
}