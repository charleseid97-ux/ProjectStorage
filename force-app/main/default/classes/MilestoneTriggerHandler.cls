public class MilestoneTriggerHandler {
    
    public static void handleBeforeInsert(List<Milestone__c> newMilestone) {
       MilestoneHandler.linkStepToMilestone(newMilestone[0]);
    }
    
    public static void handleBeforeUpdate(Map<Id, Milestone__c> newMilestone, Map<Id, Milestone__c> oldMilestone) {
       
    }


    public static void handleAfterInsert(Map<Id, Milestone__c> newMilestone) {
    }

    public static void handleAfterUpdate(Map<Id, Milestone__c> newMilestone, Map<Id, Milestone__c> oldMilestone) {
        MilestoneHandler.updateProjectLaunchDate(newMilestone, oldMilestone);
        MilestoneHandler.updateOwnerOnProjectProduct(newMilestone, oldMilestone);
        MilestoneHandler.validatePhasesESG(newMilestone, oldMilestone);
    }
}