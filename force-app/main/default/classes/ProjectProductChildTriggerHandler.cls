/** ──────────────────────────────────────
 * @description Dispatches the ProjectProductChildTrigger events (PMT project stages) to ProjectProductChildHandler.
 *              Before update order (FIX-20270): the stage status (updatePhaseStatusWAllTeamValidation) is set before
 *                  the completion rate (updateCompletionRate), so the rate sees the status set in the same save.
 * @lastModifiedBy Charles EID   [19-10-26]
 * @testClass Test_ProjectProductChildTriggerHandler
 * @coverage 100%   [19-10-26]
 ────────────────────────────────────── */
public class ProjectProductChildTriggerHandler {
    public static Boolean isBlankingFields = false;

    public static void handleBeforeInsert(List<ProjectProductChild__c> newProjectProductChild) {
        ProjectProductChildHandler.cloneParentProject(newProjectProductChild);
        ProjectProductChildHandler.calculNbOfFields(newProjectProductChild);
    }

    public static void handleBeforeUpdate(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        ProjectProductChildHandler.lockRecordProjectProductChild(newProjectProductChild, oldProjectProductChild);
        ProjectProductChildHandler.blockValidationBeforeSPCValidated(newProjectProductChild, oldProjectProductChild);
        ProjectProductChildHandler.calculNbOfFields(newProjectProductChild.values());
        ProjectProductChildHandler.updatePhaseStatusWAllTeamValidation(newProjectProductChild, oldProjectProductChild);
        ProjectProductChildHandler.updateCompletionRate(newProjectProductChild, oldProjectProductChild);
    }

    public static void handleAfterInsert(Map<Id, ProjectProductChild__c> newChildrenMap) {
        List<ProjectProductChild__c> children = newChildrenMap.values();

        Date goLiveEndDate = ProjectProductChildHandler.createMilestones(children); // For now, assumes 1 common date
        if (goLiveEndDate != null) ProjectProductChildHandler.updateProjectEndate(children, goLiveEndDate);

        ProjectProductChildHandler.createRelatedShareClasses(children);
    }

    public static void handleAfterUpdate(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        if (ProjectShareclassTriggerHandler.isBlankingChildFields) return;

        isBlankingFields = true;
        ProjectProductChildHandler.updateProjectProductParent(newProjectProductChild, oldProjectProductChild);
        isBlankingFields = false;

        ProjectProductChildHandler.logPhaseValidation(newProjectProductChild, oldProjectProductChild);
        ProjectProductChildHandler.sendTaxNotificationsKPMG(newProjectProductChild.values(), oldProjectProductChild);
    }
}