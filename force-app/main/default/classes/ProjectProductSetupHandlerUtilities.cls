/** ──────────────────────────────────────
 * @description Helper methods for ProjectProduct__c trigger logic: Project Product Child creation, step validation
 *                  (TECH_TeamValidation__c) and blanking of newly selected fields when TECH_FieldsToModify__c changes,
 *                  filled-fields count and Launch Date milestone sync.
 *              Project side of the PS/IS rule: getProjectScope and normalizeScope (blank Scope = PS, defined only here).
 *                  Which team applies to a Scope is configuration (PMTTeam__mdt.Scope__c, read by PMTMatrix.forScope,
 *                  FIX-20178); validateSteps reads the PMT matrix restricted to the project's Scope.
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_ProjectProductTrigger, Test_FieldModificationController
 * @coverage 95%   [09-10-26]
 ────────────────────────────────────── */
public class ProjectProductSetupHandlerUtilities {
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();

    public static ProjectProductChild__c createProjectProductChild(String stage, String parentId, Date startDate, Date endDate , List<String> teamswithNofields, Integer nbOfFieldsGoal) {
        System.debug('### [DEBUG] Setting for stage ' + stage);
        List<String> cleanteamswithNofields= new List<String>();
        
        for(String team: teamswithNofields ){
            cleanteamswithNofields.add(team.replaceAll(' ', ''));
        }

        String teamsNofields= String.join( cleanteamswithNofields , ';');
        System.debug('test doha teams with no fields'+teamsNofields );

        String recordTypeId;
        String childType;

        if (stage == 'Design' || stage == 'Proposal') {
            recordTypeId = Schema.SObjectType.ProjectProductChild__c.getRecordTypeInfosByDeveloperName().get('DesignAndProposal').getRecordTypeId();
            childType = 'DesignAndProposal';
        } else {
            recordTypeId = Schema.SObjectType.ProjectProductChild__c.getRecordTypeInfosByDeveloperName().get(stage).getRecordTypeId();
            childType = stage;
        }

        ProjectProductChild__c ppc = new ProjectProductChild__c(
            Name = stage,
            Status__c = 'Not Started',
            ProjectProductParent__c = parentId,
            StartDate__c = startDate,
            EndDate__c = endDate,
            RecordTypeId = recordTypeId,
            TECH_Childtype__c = childType,
            TECH_TeamValidation__c= teamsNofields,
            fundNbOfFields__c = nbOfFieldsGoal
        );
        return ppc;
    }

    // US-20120: Récupère le Scope (PS/IS) du projet, normalisé (Scope vide = PS).
    public static String getProjectScope(Id recordId) {
        ProjectProduct__c projectProduct = [SELECT Scope__c FROM ProjectProduct__c WHERE Id = :recordId LIMIT 1];
        return normalizeScope(projectProduct.Scope__c);
    }

    // US-20120 / FIX-20178: un projet sans Scope (antérieur au champ) est un projet PS. Seul endroit où ce défaut est défini.
    public static String normalizeScope(String scope) {
        return String.isBlank(scope) ? 'PS' : scope;
    }

    public static void validateSteps(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Set<Id> changedProjectIds = new Set<Id>();
        system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Start validateSteps');
        for (Id id : newProjectProduct.keySet()) {
            System.debug('validateSteps.TECH_FieldsToModify__c => ' + newProjectProduct.get(id).TECH_FieldsToModify__c);
            System.debug('validateSteps.TECH_FieldsToModify__c => ' + oldProjectProduct.get(id)?.TECH_FieldsToModify__c);

            if (newProjectProduct.get(id).TECH_FieldsToModify__c != oldProjectProduct.get(id)?.TECH_FieldsToModify__c) {
                changedProjectIds.add(id);
            }
        }
        System.debug('changedProjectIds => ' + changedProjectIds);

        if (changedProjectIds.isEmpty()) return;
    
        // FIX-20178: stage and team of each field from the PMT matrix restricted to the project's Scope (one set of maps per scope)
        PMTMatrix matrix = PMTMatrix.get();
        Map<String, Map<String, String>> stageFieldsByScope = new Map<String, Map<String, String>>();
        Map<String, Map<String, String>> teamFieldsByScope = new Map<String, Map<String, String>>();

        // Every validation team (Product Strategy and IS included) - the ones owning a modified field are removed below
        List<String> allTeams = new List<String>();
        for (PMTMatrix.Team team : matrix.getValidationTeams()) allTeams.add(team.key);

        Map<Id, ProjectProductChild__c> updates = new Map<Id, ProjectProductChild__c>();
        Set<String> fieldsToModify = new Set<String>();

        for (ProjectChildJunction__c junction : [
            SELECT ProjectProductChild__r.Id,
                   ProjectProductChild__r.ProjectProductParent__r.Scope__c,
                   ProjectProductChild__r.ProjectProductParent__c,
                   ProjectProductChild__r.TECH_TeamValidation__c,
                   ProjectProductChild__r.TECH_Childtype__c,
                   ProjectProductChild__r.Name,
                   ProjectShareclass__r.TECH_FieldsToModify__c,
                   ProjectProductChild__r.ProjectProductParent__r.TECH_FieldsToModify__c
            FROM ProjectChildJunction__c
            WHERE ProjectProductChild__r.ProjectProductParent__c IN :changedProjectIds
              AND ProjectProductChild__r.Name != 'Design'
        ]) {
            ProjectProductChild__c child = junction.ProjectProductChild__r;
            Id parentId = child.ProjectProductParent__c;

            String scope = normalizeScope(child.ProjectProductParent__r.Scope__c);
            if (!stageFieldsByScope.containsKey(scope)) {
                PMTMatrix scopedMatrix = matrix.forScope(scope);
                stageFieldsByScope.put(scope, scopedMatrix.getStageByField());
                teamFieldsByScope.put(scope, scopedMatrix.getTeamByField());
            }
            Map<String, String> stageFields = stageFieldsByScope.get(scope);
            Map<String, String> teamFields = teamFieldsByScope.get(scope);
    
            if (String.isNotBlank(junction.ProjectShareclass__r.TECH_FieldsToModify__c)) {
                fieldsToModify.addAll(junction.ProjectShareclass__r.TECH_FieldsToModify__c.split(';'));
            }
       
            if (String.isNotBlank(newProjectProduct.get(parentId)?.TECH_FieldsToModify__c)) {
                fieldsToModify.addAll(newProjectProduct.get(parentId).TECH_FieldsToModify__c.split(';'));
            }
            Set<String> remainingTeams = new Set<String>(allTeams);
            System.debug('fieldsToModify=>' + fieldsToModify);

            Set<String> coveredTeams = new Set<String>();
            for (String field : fieldsToModify) {
                String stage = stageFields.get(field);
                System.debug('stage=>' + stage);

                if (stage == 'Design' || stage == 'Proposal') stage = 'DesignAndProposal';
                if (child.TECH_Childtype__c == stage) {
                    String team = teamFields.get(field);
                    if (team != null) {
                        System.debug('field=>' + field + ' team=>' + team );
                        remainingTeams.remove(team.replaceAll(' ', ''));
                    }
                }
            }

            child.TECH_TeamValidation__c = String.join(remainingTeams, ';');
    
            System.debug('team=>' + child.TECH_Childtype__c+ ' child.TECH_TeamValidation__c => ' + child.TECH_TeamValidation__c);

            updates.put(child.Id, child);
        }
        if (!updates.isEmpty()) {
            update updates.values();
        }
        system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> END validateSteps');
    }

    private static Set<String> splitToSet(String s) {
        Set<String> out = new Set<String>();
        if (String.isBlank(s)) return out;

        for (String token : s.split(';')) {
            token = token != null ? token.trim() : null;
            if (String.isNotBlank(token)) out.add(token);
        }
        return out;
    }

    public static void emptyFields(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Set<Id> changedProjectIds = new Set<Id>();
        for (ProjectProduct__c proj : newProjectProduct.values()) {
            if (proj.TECH_FieldsToModify__c != oldProjectProduct.get(proj.Id)?.TECH_FieldsToModify__c) {
                changedProjectIds.add(proj.Id);
            }
        }
    
        if (changedProjectIds.isEmpty()) return;
    
        Map<String, Schema.SObjectField> fieldMap = ProjectProductChild__c.SObjectType.getDescribe().fields.getMap();
        List<ProjectProductChild__c> toUpdate = new List<ProjectProductChild__c>();
    
        for (ProjectProductChild__c child : [
            SELECT Id, ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c IN :changedProjectIds
        ]) {
            Id parentId = child.ProjectProductParent__c;
            String newFieldsStr = newProjectProduct.get(parentId)?.TECH_FieldsToModify__c;
            String oldFieldsStr = oldProjectProduct.get(parentId)?.TECH_FieldsToModify__c;
    
            if (String.isBlank(newFieldsStr)) continue;
    
            Set<String> newFields = new Set<String>(newFieldsStr.split(';'));
            Set<String> oldFields = oldFieldsStr != null ? new Set<String>(oldFieldsStr.split(';')) : new Set<String>();
            System.debug('### [DEBUG] emptyFields - newFields: ' + newFields);
            System.debug('### [DEBUG] emptyFields - oldFields: ' + oldFields);

            for (String field : newFields) {
                if (!oldFields.contains(field) && fieldMap.containsKey(field)) {
                    Schema.DisplayType type = fieldMap.get(field).getDescribe().getType();
                    if (type != Schema.DisplayType.Boolean) {
                        child.put(field, null);
                    }
                }
            }
    
            toUpdate.add(child);
        }
        System.debug('### [DEBUG] emptyFields - toUpdate size: ' + toUpdate.size());
        System.debug('### [DEBUG] emptyFields - toUpdate : ' + toUpdate);
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static Integer countFilledFields(SObject record, List<String> fieldApiNames) {
        Integer filledCount = 0;
        Set<String> fields = new Set<String>();
        fields.addAll(fieldApiNames);
        for (String fieldName : fields) {

            // if (record.get(fieldName) != null) {
                Object value = record.get(fieldName);
                // Vérifie si le champ est non null et, s'il s'agit d'une string, non vide
                if (value != null && (!(value instanceof String) || String.valueOf(value).trim() != '')) {
                    System.debug('### [DEBUG] countFilledFields - fieldName: ' + fieldName);

                    filledCount++;
                }
            // }
        }
        
        System.debug('### [DEBUG] countFilledFields - filledCount: ' + filledCount);
        return filledCount;
    }

    public static void updateMilestoneGolive(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        List<Milestone__c> lMilestone = [SELECT Id, StartDate__c, Project_product__c
                                        FROM Milestone__c
                                        WHERE Project_product__c IN :newProjectProduct.keySet()
                                        AND Name = 'Launch Date'];

        if (lMilestone.isEmpty() || lMilestone == null) {
            return;
        }
    
        Map<Id, Milestone__c> mapMilestoneByProject = new Map<Id, Milestone__c>();
        for (Milestone__c milestone : lMilestone) {
            mapMilestoneByProject.put(milestone.Project_product__c, milestone);
        }
    
        List<Milestone__c> milestonesToUpdate = new List<Milestone__c>();

        for (ProjectProduct__c projectProduct : newProjectProduct.values()) {
            if (projectProduct.EndDate__c != oldProjectProduct.get(projectProduct.Id).EndDate__c) {
                Milestone__c relatedMilestone = mapMilestoneByProject.get(projectProduct.Id);
                if (relatedMilestone.StartDate__c != projectProduct.EndDate__c) {
                    relatedMilestone.StartDate__c = projectProduct.EndDate__c;
                    milestonesToUpdate.add(relatedMilestone); 
                }
            }
        }

        if (!milestonesToUpdate.isEmpty()) {
            update milestonesToUpdate;
        }
    }

}