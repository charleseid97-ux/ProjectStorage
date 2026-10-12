/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Team Completion widget (lwc_TaskCompletionByTeam).
 *              Builds the per-stage/per-team step data (owner, status, icon) for the current Project Product, from the
 *                  PMT matrix restricted to the project's Scope (PMTMatrix.forScope - only the "Product Strategy" or
 *                  "IS" team applies, the client never needs to know this rule), and bulk-calculates completion
 *                  percentages per step/team from the required fields of the PMT matrix (FIX-20178).
 *              Works in conjunction with TaskCompletionByTeamControllerUtilities for data retrieval.
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_TaskCompletionByTeamController
 * @coverage 99%   [09-10-26]
 ────────────────────────────────────── */
public without sharing class TaskCompletionByTeamController {

    // Récupère les étapes et équipes associées pour un projet donné
    @AuraEnabled
    public static String getStepWithTeams(Id recordId) {
        // US-20120 / FIX-20178: matrice PMT restreinte au Scope du projet (PS ou IS),
        // pour que le client n'ait jamais à connaître/recoder cette règle.
        String projectScope = ProjectProductSetupHandlerUtilities.getProjectScope(recordId);
        PMTMatrix matrix = PMTMatrix.get().forScope(projectScope);
        List<PMTMatrix.FieldRule> records = TaskCompletionByTeamControllerUtilities.getProjectStages(matrix);
        List<PMTMatrix.Team> recordsteams = matrix.getValidationTeams();

        Map<String, Id> mapteamowner = TaskCompletionByTeamControllerUtilities.getOwnerTeamId(recordId, recordsteams);
        
        Map<Id, String> mapownersName = TaskCompletionByTeamControllerUtilities.getOwnerTeamNameById(mapteamowner.values());
        Map<String, ProjectProductChild__c> stepsrecords = TaskCompletionByTeamControllerUtilities.getProjectChildren(recordId);
 
        // Construction des données
        Map<String, List<Map<String, String>>> stepMap = buildStepMap(records, mapteamowner, mapownersName, stepsrecords);
 
        // Transformation en JSON et retour
        return formatStepsAsJson(stepMap, stepsrecords);
    }

    // Construit une map des étapes avec les équipes associées
    private static Map<String, List<Map<String, String>>> buildStepMap(List<PMTMatrix.FieldRule> records, Map<String, Id> mapteamowner, Map<Id, String> mapownersName, Map<String, ProjectProductChild__c> stepsrecords) {
        Map<String, List<Map<String, String>>> stepMap = new Map<String, List<Map<String, String>>>();

        for (PMTMatrix.FieldRule record : records) {
            String stepName = record.stage;
            String teamName = record.team;
            String teamNameSansSpaces = teamName.replaceAll('\\s', '');

            Id ownerId = mapteamowner.get(teamName);
            String owner = mapownersName.get(ownerId);
            ProjectProductChild__c idrecord = stepsrecords.get(stepName);
            if (idrecord == null) continue;

            // FIX-20178: clé de ligne du datatable (key-field "id"), unique par étape et équipe
            Map<String, String> teamData = createTeamData(stepName + '-' + teamNameSansSpaces, teamName, owner, idrecord, teamNameSansSpaces);
       
            if (!stepMap.containsKey(stepName)) stepMap.put(stepName, new List<Map<String, String>>());
            stepMap.get(stepName).add(teamData);
        }
        return stepMap;
    }

    // Crée une structure de données pour une équipe
    private static Map<String, String> createTeamData(String recordId, String teamName, String owner, ProjectProductChild__c idrecord, String teamNameSansSpaces) {
        String status = 'Draft';
        String iconName = '🟠';
 
        if (!String.isBlank(idrecord.TECH_TeamValidation__c) && idrecord.TECH_TeamValidation__c.contains(teamNameSansSpaces)) {
            status = 'Completed';
            iconName = '✅';
        } 
        else if (Date.today().daysBetween(idrecord.EndDate__c) <= Math.round(idrecord.StartDate__c.daysBetween(idrecord.EndDate__c) * 0.3)) {
            iconName = '⚠️';
        } 
        else if (Date.today().daysBetween(idrecord.EndDate__c) < 0) {
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
 
    // Transforme les données en JSON
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
        if (recordIds.isEmpty() || stepNames.isEmpty() || teamNames.isEmpty()) return results;

        // 1. Champs requis de la matrice PMT (FIX-20178)
        PMTMatrix matrix = PMTMatrix.get();
        Set<String> allRequiredFields = new Set<String>(matrix.getRequiredFields(true));
        Set<String> allRequiredFieldsShareclass = new Set<String>(matrix.getRequiredFields(false));

        // 2. Récupérer les ProjectProductChild avec les bons champs
        String fieldsQuery = 'Id, Name, RecordType.DeveloperName, ProjectProductParent__c, Status__c, CompletionRateStep__c';
        if (!allRequiredFields.isEmpty()) fieldsQuery += ', ' + String.join(new List<String>(allRequiredFields), ',');

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

            ProjectProductChild__c projectChild = projectProductChildMap.get(ppcId);
            if (matrix.getTeam(team) == null || projectChild == null) continue;
            PMTMatrix.FieldRule setting = matrix.getRule(team, step);

            List<String> requiredFields = setting.requiredFund;
            Integer completedFields = 0;
            Integer totalFields = requiredFields.size();
         
            for (String field : requiredFields) {
                if (projectChild.get(field) != null) completedFields++;
            }
         
            // Ajout des champs shareclass si pertinents
            List<String> requiredFieldsShareclass = setting.requiredShareClass;
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
         
            if (projectChild.Status__c == 'Completed' || totalFields == 0) completionRate = 1;
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