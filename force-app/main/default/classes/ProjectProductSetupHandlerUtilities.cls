/** ──────────────────────────────────────
 * @description Helper methods for ProjectProduct__c trigger logic: Project Product Child creation, step validation
 *                  (TECH_TeamValidation__c) and blanking of newly selected fields when TECH_FieldsToModify__c changes,
 *                  filled-fields count and Launch Date milestone sync.
 *              Project side of the PS/IS rule: getProjectScope and normalizeScope (blank Scope = PS, defined only here).
 *                  Which team applies to a Scope is configuration (PMTTeam__mdt.Scope__c, read by PMTMatrix.forScope,
 *                  FIX-20178); validateSteps reads the PMT matrix restricted to the project's Scope.
 *              Phase completion rule (FIX-20270): isPhaseValidated - every validation team of the project's Scope has
 *                  validated the phase. splitMultiPicklist is the shared multi-select picklist split.
 *              US-20194: getTeamsAfterModification receives the project's matrix (PMTMatrix.forProject: Scope and conditions).
 * @lastModifiedBy Charles EID   [21-10-26]
 * @testClass Test_ProjectProductTrigger, Test_FieldModificationController
 * @coverage 100%   [21-10-26]
 ────────────────────────────────────── */
public class ProjectProductSetupHandlerUtilities {

    public static ProjectProductChild__c createProjectProductChild(String stage, String parentId, Date startDate, Date endDate, List<String> teamswithNofields, Integer nbOfFieldsGoal) {
        List<String> cleanTeamsWithNoFields = new List<String>();
        for (String team : teamswithNofields) {
            cleanTeamsWithNoFields.add(team.replaceAll(' ', ''));
        }

        // Design and Proposal share the DesignAndProposal record type
        String childType = (stage == 'Design' || stage == 'Proposal') ? 'DesignAndProposal' : stage;
        Id recordTypeId = Schema.SObjectType.ProjectProductChild__c.getRecordTypeInfosByDeveloperName().get(childType).getRecordTypeId();

        return new ProjectProductChild__c(
            Name = stage,
            Status__c = 'Not Started',
            ProjectProductParent__c = parentId,
            StartDate__c = startDate,
            EndDate__c = endDate,
            RecordTypeId = recordTypeId,
            TECH_Childtype__c = childType,
            TECH_TeamValidation__c = String.join(cleanTeamsWithNoFields, ';'),
            fundNbOfFields__c = nbOfFieldsGoal
        );
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

    // FIX-20270: values of a multi-select picklist (e.g. TECH_TeamValidation__c, TECH_FieldsToModify__c), trimmed, without blanks or duplicates.
    public static Set<String> splitMultiPicklist(String value) {
        Set<String> values = new Set<String>();
        if (String.isBlank(value)) return values;

        for (String item : value.split(';')) {
            if (String.isNotBlank(item)) values.add(item.trim());
        }
        return values;
    }

    // FIX-20270: a phase is validated once every validation team of the project's Scope (PMTMatrix.forScope) is in its TECH_TeamValidation__c. The caller passes a normalized scope.
    public static Boolean isPhaseValidated(String teamValidation, String scope) {
        Set<String> scopeTeams = PMTMatrix.get().forScope(scope).getValidationTeamKeys();
        return !scopeTeams.isEmpty() && splitMultiPicklist(teamValidation).containsAll(scopeTeams);
    }

    // Recomputes TECH_TeamValidation__c of every phase (except Design) of the projects whose TECH_FieldsToModify__c changed: the teams owning a field to modify at the phase's stage are left to validate.
    // FIX-20270: the fields of a phase are the project's fields + the fields of the phase's share classes. Before, one list accumulated across every junction of the save, so in a multi-project save the fields of one project leaked into the next projects' phases.
    public static void validateSteps(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Set<Id> changedProjectIds = new Set<Id>();
        for (Id id : newProjectProduct.keySet()) {
            if (newProjectProduct.get(id).TECH_FieldsToModify__c != oldProjectProduct.get(id)?.TECH_FieldsToModify__c) changedProjectIds.add(id);
        }

        if (changedProjectIds.isEmpty()) return;

        Map<Id, ProjectProductChild__c> phaseById = new Map<Id, ProjectProductChild__c>();
        Map<Id, Set<String>> fieldsByPhaseId = new Map<Id, Set<String>>();
        for (ProjectChildJunction__c junction : [SELECT ProjectProductChild__r.Id, ProjectProductChild__r.ProjectProductParent__c, ProjectProductChild__r.TECH_TeamValidation__c, ProjectProductChild__r.TECH_Childtype__c, ProjectProductChild__r.Name, ProjectShareclass__r.TECH_FieldsToModify__c
                                                 FROM ProjectChildJunction__c
                                                 WHERE ProjectProductChild__r.ProjectProductParent__c IN :changedProjectIds AND ProjectProductChild__r.Name != 'Design']) {
            ProjectProductChild__c child = junction.ProjectProductChild__r;
            if (!phaseById.containsKey(child.Id)) {
                phaseById.put(child.Id, child);
                fieldsByPhaseId.put(child.Id, splitMultiPicklist(newProjectProduct.get(child.ProjectProductParent__c)?.TECH_FieldsToModify__c));
            }
            fieldsByPhaseId.get(child.Id).addAll(splitMultiPicklist(junction.ProjectShareclass__r.TECH_FieldsToModify__c));
        }

        for (ProjectProductChild__c child : phaseById.values()) {
            child.TECH_TeamValidation__c = getTeamsAfterModification(child, fieldsByPhaseId.get(child.Id), PMTMatrix.forProject(newProjectProduct.get(child.ProjectProductParent__c)));
        }
        if (!phaseById.isEmpty()) update phaseById.values();
    }

    // FIX-20270: TECH_TeamValidation__c of a phase once fields are modified: every validation team (Product Strategy and IS included) except the teams owning one of the fields at the phase's stage, from the PMT matrix of the project (its Scope and, US-20194, its conditions: PMTMatrix.forProject). Shared by the project and share class validateSteps. The phase must hold TECH_Childtype__c.
    public static String getTeamsAfterModification(ProjectProductChild__c phase, Set<String> modifiedFields, PMTMatrix projectMatrix) {
        Map<String, String> stageByField = projectMatrix.getStageByField();
        Map<String, String> teamByField = projectMatrix.getTeamByField();

        Set<String> remainingTeams = PMTMatrix.get().getValidationTeamKeys();
        for (String field : modifiedFields) {
            String stage = stageByField.get(field);
            if (stage == 'Design' || stage == 'Proposal') stage = 'DesignAndProposal';
            String team = teamByField.get(field);
            if (phase.TECH_Childtype__c == stage && team != null) remainingTeams.remove(team.replaceAll(' ', ''));
        }
        return String.join(new List<String>(remainingTeams), ';');
    }

    // Blanks, on the phases, the fields newly added to TECH_FieldsToModify__c (checkboxes excepted).
    public static void emptyFields(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Set<Id> changedProjectIds = new Set<Id>();
        for (ProjectProduct__c project : newProjectProduct.values()) {
            if (project.TECH_FieldsToModify__c != oldProjectProduct.get(project.Id)?.TECH_FieldsToModify__c) changedProjectIds.add(project.Id);
        }

        if (changedProjectIds.isEmpty()) return;

        Map<String, Schema.SObjectField> fieldMap = ProjectProductChild__c.SObjectType.getDescribe().fields.getMap();
        List<ProjectProductChild__c> toUpdate = new List<ProjectProductChild__c>();
        for (ProjectProductChild__c child : [SELECT Id, ProjectProductParent__c
                                             FROM ProjectProductChild__c
                                             WHERE ProjectProductParent__c IN :changedProjectIds]) {
            String newFieldsStr = newProjectProduct.get(child.ProjectProductParent__c)?.TECH_FieldsToModify__c;
            if (String.isBlank(newFieldsStr)) continue;

            Set<String> oldFields = splitMultiPicklist(oldProjectProduct.get(child.ProjectProductParent__c)?.TECH_FieldsToModify__c);
            for (String field : splitMultiPicklist(newFieldsStr)) {
                if (!oldFields.contains(field) && fieldMap.containsKey(field) && fieldMap.get(field).getDescribe().getType() != Schema.DisplayType.Boolean) child.put(field, null);
            }
            toUpdate.add(child);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public static Integer countFilledFields(SObject record, List<String> fieldApiNames) {
        Integer filledCount = 0;
        for (String fieldName : new Set<String>(fieldApiNames)) {
            Object value = record.get(fieldName);
            // Vérifie si le champ est non null et, s'il s'agit d'une string, non vide
            if (value != null && (!(value instanceof String) || String.valueOf(value).trim() != '')) filledCount++;
        }
        return filledCount;
    }

    // Moves the Launch Date milestone to the project's new end date.
    public static void updateMilestoneGolive(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        List<Milestone__c> launchDateMilestones = [SELECT Id, StartDate__c, Project_product__c
                                                   FROM Milestone__c
                                                   WHERE Project_product__c IN :newProjectProduct.keySet() AND Name = 'Launch Date'];

        if (launchDateMilestones.isEmpty()) return;

        Map<Id, Milestone__c> milestoneByProjectId = new Map<Id, Milestone__c>();
        for (Milestone__c milestone : launchDateMilestones) {
            milestoneByProjectId.put(milestone.Project_product__c, milestone);
        }

        List<Milestone__c> milestonesToUpdate = new List<Milestone__c>();
        for (ProjectProduct__c projectProduct : newProjectProduct.values()) {
            if (projectProduct.EndDate__c == oldProjectProduct.get(projectProduct.Id).EndDate__c) continue;

            // FIX-20270: a project of the save without a Launch Date milestone is skipped (it raised a null pointer exception when another project of the save had one)
            Milestone__c relatedMilestone = milestoneByProjectId.get(projectProduct.Id);
            if (relatedMilestone != null && relatedMilestone.StartDate__c != projectProduct.EndDate__c) {
                relatedMilestone.StartDate__c = projectProduct.EndDate__c;
                milestonesToUpdate.add(relatedMilestone);
            }
        }
        if (!milestonesToUpdate.isEmpty()) update milestonesToUpdate;
    }
}