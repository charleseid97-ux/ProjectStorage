public class ProjectProductChildTriggerHandler {
    public static Boolean isBlankingFields = false;

    public static void handleBeforeInsert(List<ProjectProductChild__c> newProjectProductChild) {
        ProjectProductChildHandler.cloneParentProject(newProjectProductChild);
        // ProjectProductChildHandler.nbOfFieldsGoal(newProjectProductChild);
        ProjectProductChildHandler.calculNbOfFields(newProjectProductChild);

    }

     public static void handleBeforeUpdate(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        List<ProjectProductChild__c> l_projectProductChild = newProjectProductChild.values();
        ProjectProductChildHandler.lockRecordProjectProductChild(newProjectProductChild, oldProjectProductChild);
        ProjectProductChildHandler.blockValidationBeforeSPCValidated(newProjectProductChild, oldProjectProductChild);
        //ProjectProductChildHandler.nbOfFieldsGoal(newProjectProductChild.values());        
        ProjectProductChildHandler.calculNbOfFields(newProjectProductChild.values());
        ProjectProductChildHandler.updateCompletionRate(newProjectProductChild, oldProjectProductChild);
        ProjectProductChildHandler.updatePhaseStatusWAllTeamValidation(newProjectProductChild, oldProjectProductChild);
    }   
    
    public static void handleAfterInsert(Map<Id, ProjectProductChild__c> newChildrenMap) {
        List<ProjectProductChild__c> children = newChildrenMap.values();
    
        Date goLiveEndDate = ProjectProductChildHandler.createMilestones(children); // For now, assumes 1 common date
        if (goLiveEndDate != null) {
            ProjectProductChildHandler.updateProjectEndate(children, goLiveEndDate);
        }
    
        ProjectProductChildHandler.createRelatedShareClasses(children);
    }

    public static void handleAfterUpdate(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {

        if(ProjectShareclassTriggerHandler.isBlankingChildFields){
            return;
        }
        isBlankingFields = true;
        ProjectProductChildHandler.updateProjectProductParent(newProjectProductChild, oldProjectProductChild);
        isBlankingFields = false;

        ProjectProductChildHandler.logPhaseValidation(newProjectProductChild, oldProjectProductChild);
    }
}