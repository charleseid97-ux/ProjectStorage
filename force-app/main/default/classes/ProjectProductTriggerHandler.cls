public class ProjectProductTriggerHandler {
    public static Boolean isBlankingFields = false;

    public static void handleBeforeInsert(List<ProjectProduct__c> newProjectProduct) {
        new ProjectProductSetupHandler().getOwnersTeam(newProjectProduct);
        ProjectProductSetupHandler.cloneFund(newProjectProduct);
    }
    
    public static void handleBeforeUpdate(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        new ProjectProductSetupHandler().updateProjectProductStatus(newProjectProduct , oldProjectProduct);
        ProjectProductSetupHandler.updateLegalOwner(newProjectProduct, oldProjectProduct);
        new   ProjectProductSetupHandler().updateProjectProductName(newProjectProduct , oldProjectProduct);
    }

    public static void handleAfterInsert(Map<Id, ProjectProduct__c> l_project) {
        ProjectProductSetupHandler.updatePPName(l_project.values());
        new ProjectProductSetupHandler().createProjectProduct(l_project.values());
        new ProjectProductSetupHandler().createTaskList(l_project.values());
        ProjectProductSetupHandler.nbOfFieldsGoal(l_project);

    }

    public static void handleAfterUpdate(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        
        Map<Id, ProjectProduct__c> cleanednewProjectProduct = newProjectProduct;
        Map<Id, ProjectProduct__c> recalNbOfFields = new Map<Id, ProjectProduct__c>();
            
        if(ProjectProductChildTriggerHandler.isBlankingFields){
            return;
        }

        for(String projectId : newProjectProduct.keySet()) {
            if(newProjectProduct.get(projectId).TECH_FieldsToModify__c != oldProjectProduct.get(projectId).TECH_FieldsToModify__c){
               
                recalNbOfFields.put(projectId, newProjectProduct.get(projectId));
            }
        }
        
        if(!recalNbOfFields.isEmpty()){
            ProjectProductSetupHandler.nbOfFieldsGoal(recalNbOfFields);
            isBlankingFields = true;
            ProjectProductSetupHandlerUtilities.validateSteps(recalNbOfFields , oldProjectProduct);
            ProjectProductSetupHandlerUtilities.emptyFields(recalNbOfFields , oldProjectProduct);
            isBlankingFields = false;
        }

        new ProjectProductSetupHandler().createGroupChatterForProject(cleanednewProjectProduct.values(), oldProjectProduct);
        ProjectProductSetupHandlerUtilities.updateMilestoneGolive(cleanednewProjectProduct , oldProjectProduct);
    }
}