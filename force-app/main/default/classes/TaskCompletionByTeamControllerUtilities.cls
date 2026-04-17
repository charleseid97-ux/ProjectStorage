public class TaskCompletionByTeamControllerUtilities {
 
    /**
     * 🔹 Récupère les étapes de configuration
     */
    public static List<ProductProjectSettings__c> getProjectStages() {
        return [
            SELECT Id, Name, ProjectType__c, Stage__c, Order__c, Team__c, OrderTeam__c
            FROM ProductProjectSettings__c
            WHERE ProjectType__c = 'Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)
            ORDER BY Order__c, OrderTeam__c ASC
        ];
    }
 
    /**
     * 🔹 Récupère les équipes pour "Design"
     */
    public static List<ProductProjectSettings__c> getDesignTeams() {
        return [
            SELECT Id, Name, ProjectType__c, Stage__c, Order__c, Team__c, OrderTeam__c
            FROM ProductProjectSettings__c
            WHERE ProjectType__c = 'Creation' AND Stage__c = 'Design' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)
            ORDER BY OrderTeam__c ASC
        ];
    }
 
    /**
     * 🔹 Récupère les ProjectProductChild associés
     */
    public static Map<String, ProjectProductChild__c> getProjectChildren(Id recordId) {
        Map<String, ProjectProductChild__c> stepsrecords = new Map<String, ProjectProductChild__c>();
        for (ProjectProductChild__c recordchild : [
            SELECT Id, Name, Status__c, TECH_TeamValidation__c, StartDate__c, EndDate__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c = :recordId
        ]) {
            stepsrecords.put(recordchild.Name, recordchild);
        }
        return stepsrecords;
    }
 
    /**
     * 🔹 Récupère le nom des propriétaires en fonction de leur ID
     */
    public static Map<Id, String> getOwnerTeamNameById(List<Id> recordsId) {
        Map<Id, String> mapIdNameOwner = new Map<Id, String>();
        for (User user : [SELECT Id, FirstName, LastName FROM User WHERE Id IN :recordsId]) {
            mapIdNameOwner.put(user.Id, user.FirstName + ' ' + user.LastName);
        }
        return mapIdNameOwner;
    }
 
    /**
     * 🔹 Récupère le propriétaire d'une équipe pour un projet donné
     */
    public static Map<String, Id> getOwnerTeamId(Id recordId, List<ProductProjectSettings__c> recordsteams) {
        List<String> teamsName = new List<String>();
        for (ProductProjectSettings__c team : recordsteams) {
            teamsName.add(team.Team__c);
        }
 
        if (teamsName.isEmpty()) return new Map<String, Id>();
 
        ProjectProduct__c projectproduct = [
            SELECT Id, ProductStrategy__c, Legal__c, Tax__c, OPS__c, Risk__c, ESG__c, Compliance__c,
                   DCO__c, DCR__c, InvestmentPerf__c, Finance__c, Communication__c, Technology__c, IS__c
            FROM ProjectProduct__c WHERE Id = :recordId
        ];
 
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


    /**
     * 🔹 Récupère les noms des RecordTypes
     */
    public static Map<Id, String> getRecordTypeName(Set<Id> ppChildIds) {
        Map<Id, String> recordTypeMap = new Map<Id, String>();
        for (ProjectProductChild__c record : [SELECT Id, RecordType.DeveloperName FROM ProjectProductChild__c WHERE Id IN :ppChildIds]) {
            recordTypeMap.put(record.Id, record.RecordType.DeveloperName);
        }
        return recordTypeMap;
    }

    public static Map<Id, Set<Id>> getProjectChildShareClasses(Set<Id> ppChildIds) {
        Map<Id, Set<Id>> projectChildWithShareClassesMap = new Map<Id, Set<Id>>();
        for (ProjectChildJunction__c projectJunction : [
            SELECT ProjectShareclass__c, ProjectProductChild__c FROM ProjectChildJunction__c
            WHERE ProjectProductChild__c IN :ppChildIds
        ]) {
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
            List<SObject> shareClassChilds = ProjectChildTeamValidationController.getRecordWithFields(
                'ProjectShareclassChild__c',
                shareClassIds,
                fieldList
            );

            System.debug('shareClassChilds: ' + shareClassChilds);

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