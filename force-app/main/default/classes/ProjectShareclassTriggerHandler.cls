/**
 * ==================================================
 * Change Log
 * ==================================================
 * Date   : 2026-05-26
 * Author : Mira EID
 * Ref    : US-19137
 *
 * Changes:
 * - Updated SetNameWithoutProduct
 * ==================================================
 */
public class ProjectShareclassTriggerHandler {
    public static Boolean isBlankingChildFields = false;
    public static Boolean isUpdatingNbOfGoals = false;
    public static void handleBeforeInsert(List<ProjectShareclass__c> newProjectShareclass) { 
        ProjectShareclassHandler.setNameWithoutProduct(newProjectShareclass, null);

    }
    
    public static void handleBeforeUpdate(Map<Id, ProjectShareclass__c> newProjectShareclass, Map<Id, ProjectShareclass__c> oldProjectShareclass) {
        ProjectShareclassHandler.setNameWithoutProduct(newProjectShareclass.values(), oldProjectShareclass);
    }

    public static void handleBeforeDelete(Map<Id, ProjectShareclass__c> oldProjectShareclass) {
    }

    public static void handleAfterInsert(Map<Id, ProjectShareclass__c> newProjectShareclass) {
        
        isUpdatingNbOfGoals = true;
        ProjectShareclassHandler.nbOfFieldsGoal(newProjectShareclass);
        isUpdatingNbOfGoals = false;
        ProjectShareclassHandler.createProjectShareclassChild(newProjectShareclass.values());
    }

    public static void handleAfterUpdate(Map<Id, ProjectShareclass__c> newProjectShareclass, Map<Id, ProjectShareclass__c> oldProjectShareclass) {
        
        isUpdatingNbOfGoals = true;
        ProjectShareclassHandler.nbOfFieldsGoal(newProjectShareclass);
        isUpdatingNbOfGoals = false;
        isBlankingChildFields = true;
        ProjectShareclassHandler.validateSteps(newProjectShareclass, oldProjectShareclass);
        ProjectShareclassHandler.emptyFields(newProjectShareclass, oldProjectShareclass);
        isBlankingChildFields = false;
        ProjectShareclassHandler.syncTaxDataFromTaxTransparency(newProjectShareclass, oldProjectShareclass);
    }
}