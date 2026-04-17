public class ProjectShareclassChildTriggerHandler {
    public static void handleBeforeInsert(List<ProjectShareclassChild__c> m_newProjectShareclassChild) {
        ProjectShareclassChildHandler.cloneParentShareclass(m_newProjectShareclassChild);
        ProjectShareclassChildHandler.calculNbOfFields(m_newProjectShareclassChild);

    }
    
    public static void handleBeforeUpdate(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild, Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
        if(!ProjectShareclassTriggerHandler.isBlankingChildFields){

            ProjectShareclassChildHandler.lockRecordShareClassChild(m_newProjectShareclassChild , m_oldProjectShareclassChild);
        }
        ProjectShareclassChildHandler.calculNbOfFields(m_newProjectShareclassChild.values());

    }


    public static void handleAfterInsert(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild) {
    }

    public static void handleAfterUpdate(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild, Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
            ProjectShareclassChildHandler.updateShareclassParent(m_newProjectShareclassChild, m_oldProjectShareclassChild);

    }
    public static void handleBeforeDelete(Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
       
    }
}