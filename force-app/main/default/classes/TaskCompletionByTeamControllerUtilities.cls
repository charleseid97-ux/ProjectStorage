/** ──────────────────────────────────────
 * @description Shared data-access utility class for the Team Completion widget (lwc_TaskCompletionByTeam).
 *              Provides the stage x validation team grid of the PMT matrix (PMTMatrix, FIX-20178), team owner
 *                  resolution from ProjectProduct__c, and the Project Product Child/Shareclass Child lookups used to
 *                  calculate completion rates.
 *              Called by TaskCompletionByTeamController, which restricts the matrix to the project's Scope (PMTMatrix.forScope).
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_TaskCompletionByTeamController
 * @coverage 100%   [09-10-26]
 ────────────────────────────────────── */
public class TaskCompletionByTeamControllerUtilities {
 
    // FIX-20178: grille étapes x équipes de validation de la matrice PMT (triée par étape puis par équipe)
    public static List<PMTMatrix.FieldRule> getProjectStages(PMTMatrix matrix) {
        List<PMTMatrix.FieldRule> stageTeams = new List<PMTMatrix.FieldRule>();
        for (PMTMatrix.Stage stage : matrix.stages) {
            for (PMTMatrix.Team team : matrix.getValidationTeams()) {
                stageTeams.add(matrix.getRule(team.name, stage.name));
            }
        }
        return stageTeams;
    }
 
    // Récupère les ProjectProductChild associés
    public static Map<String, ProjectProductChild__c> getProjectChildren(Id recordId) {
        Map<String, ProjectProductChild__c> stepsrecords = new Map<String, ProjectProductChild__c>();
        for (ProjectProductChild__c recordchild : [SELECT Id, Name, Status__c, TECH_TeamValidation__c, StartDate__c, EndDate__c
                                                   FROM ProjectProductChild__c
                                                   WHERE ProjectProductParent__c = :recordId]) {
            stepsrecords.put(recordchild.Name, recordchild);
        }
        return stepsrecords;
    }
 
    // Récupère le nom des propriétaires en fonction de leur ID
    public static Map<Id, String> getOwnerTeamNameById(List<Id> recordsId) {
        Map<Id, String> mapIdNameOwner = new Map<Id, String>();
        for (User user : [SELECT Id, FirstName, LastName FROM User WHERE Id IN :recordsId]) {
            mapIdNameOwner.put(user.Id, user.FirstName + ' ' + user.LastName);
        }
        return mapIdNameOwner;
    }
 
    // Récupère le propriétaire d'une équipe pour un projet donné
    public static Map<String, Id> getOwnerTeamId(Id recordId, List<PMTMatrix.Team> recordsteams) {
        List<String> teamsName = new List<String>();
        for (PMTMatrix.Team team : recordsteams) {
            teamsName.add(team.name);
        }
 
        if (teamsName.isEmpty()) return new Map<String, Id>();
 
        ProjectProduct__c projectproduct = [SELECT Id, ProductStrategy__c, Legal__c, Tax__c, OPS__c, Risk__c, ESG__c, Compliance__c, DCO__c, DCR__c, InvestmentPerf__c, Finance__c, Communication__c, Technology__c, IS__c
                                            FROM ProjectProduct__c 
                                            WHERE Id = :recordId];
 
        Map<String, Id> mapteamowner = new Map<String, Id>();
        for (String teamName : teamsName) {
            String teamOwnerField = teamName.replaceAll('\\s', '') + '__c';
            if (Schema.getGlobalDescribe().get('ProjectProduct__c').getDescribe().fields.getMap().containsKey(teamOwnerField)) {
                Id ownerId = (Id) projectproduct.get(teamOwnerField);
                mapteamowner.put(teamName, ownerId);
            }
        }
        return mapteamowner;
    }

    // Récupère les noms des RecordTypes
    public static Map<Id, String> getRecordTypeName(Set<Id> ppChildIds) {
        Map<Id, String> recordTypeMap = new Map<Id, String>();
        for (ProjectProductChild__c record : [SELECT Id, RecordType.DeveloperName FROM ProjectProductChild__c WHERE Id IN :ppChildIds]) {
            recordTypeMap.put(record.Id, record.RecordType.DeveloperName);
        }
        return recordTypeMap;
    }

    public static Map<Id, Set<Id>> getProjectChildShareClasses(Set<Id> ppChildIds) {
        Map<Id, Set<Id>> projectChildWithShareClassesMap = new Map<Id, Set<Id>>();
        for (ProjectChildJunction__c projectJunction : [SELECT ProjectShareclass__c, ProjectProductChild__c 
                                                        FROM ProjectChildJunction__c
                                                        WHERE ProjectProductChild__c IN :ppChildIds]) {
            if (!projectChildWithShareClassesMap.containsKey(projectJunction.ProjectProductChild__c)) {
                projectChildWithShareClassesMap.put(projectJunction.ProjectProductChild__c, new Set<Id>());
            }
            projectChildWithShareClassesMap.get(projectJunction.ProjectProductChild__c).add(projectJunction.ProjectShareclass__c);
        }
        return projectChildWithShareClassesMap;
    }

    public static Map<Id, List<ProjectShareclassChild__c>> getProjectShareclassChildren(Map<Id, Set<Id>> projectChildWithShareClassesMap, List<String> fieldList) {
        Set<Id> shareClassIds = new Set<Id>();
        for (Set<Id> shareClasses : projectChildWithShareClassesMap.values()) {
            shareClassIds.addAll(shareClasses);
        }

        Map<Id, List<ProjectShareclassChild__c>> pChildWithShareclasseChildsMap = new Map<Id, List<ProjectShareclassChild__c>>();

        if (!shareClassIds.isEmpty()) {
            List<SObject> shareClassChilds = ProjectChildTeamValidationController.getRecordWithFields('ProjectShareclassChild__c', shareClassIds, fieldList);

            for (SObject shareclasseChild : shareClassChilds) {
                ProjectShareclassChild__c shareclasseChildConverted = (ProjectShareclassChild__c) shareclasseChild;
                Id projectChildId = shareclasseChildConverted.ProjectShareclasses__c;

                if (!pChildWithShareclasseChildsMap.containsKey(projectChildId)) {
                    pChildWithShareclasseChildsMap.put(projectChildId, new List<ProjectShareclassChild__c>());
                }
                pChildWithShareclasseChildsMap.get(projectChildId).add(shareclasseChildConverted);
            }
        }
        return pChildWithShareclasseChildsMap;
    }
}