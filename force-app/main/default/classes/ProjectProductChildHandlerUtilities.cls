/** ──────────────────────────────────────
 * @description Helper methods for the ProjectProductChild__c trigger logic (ProjectProductChildHandler): milestone
 *                  creation and the Design phase status.
 *              Design has no team validation of its own: it takes the status of the project's Proposal phase
 *                  (Completed, or back to On track), FIX-20270.
 * @lastModifiedBy Charles EID   [19-10-26]
 * @testClass Test_RollbackTeamValidationController
 * @coverage 100%   [19-10-26]
 ────────────────────────────────────── */
public with sharing class ProjectProductChildHandlerUtilities {

    public static Milestone__c createMilestone(String name, String projectProductId, String projectProductChildId, Date startDate) {
        return new Milestone__c(
            Name = name,
            Status__c = 'Not Started',
            Project_Product__c = projectProductId,
            Project_Product_Child__c = projectProductChildId,
            StartDate__c = startDate
        );
    }

    // FIX-20270: gives the Design phase of each project the status of its Proposal phase. A Design phase already in the current trigger batch
    // (e.g. a Rollback on Design and Proposal updates both) is set in memory: updating it from the before trigger would fail (SELF_REFERENCE_FROM_TRIGGER).
    public static void updateDesignStatusPhase(Map<Id, String> statusByProjectId, Map<Id, ProjectProductChild__c> phasesInTrigger) {
        List<ProjectProductChild__c> phaseDesignToUpdate = new List<ProjectProductChild__c>();
        for (ProjectProductChild__c projectProductChild : [SELECT Id, Status__c, ProjectProductParent__c
                                                           FROM ProjectProductChild__c
                                                           WHERE ProjectProductParent__c IN :statusByProjectId.keySet()
                                                           AND Name = 'Design']) {
            String status = statusByProjectId.get(projectProductChild.ProjectProductParent__c);
            if (phasesInTrigger.containsKey(projectProductChild.Id)) {
                phasesInTrigger.get(projectProductChild.Id).Status__c = status;
            }
            else if (projectProductChild.Status__c != status) {
                projectProductChild.Status__c = status;
                phaseDesignToUpdate.add(projectProductChild);
            }
        }
        if (!phaseDesignToUpdate.isEmpty()) update phaseDesignToUpdate;
    }
}