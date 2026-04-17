public class ProjectGlobalCompletionController {

    @AuraEnabled(cacheable=true)
    public static ProjectProduct__c getProjectProduct(String recordId) {
        try {
            List<ProjectProduct__c> l_ProjectProduct = [
                SELECT Id, RemainingProjectDays__c, EndDate__c, GlobalProjectCompletion__c 
                FROM ProjectProduct__c 
                WHERE Id = :recordId
            ];
            
            if (!l_ProjectProduct.isEmpty()) {
                return l_ProjectProduct[0];
            } else {
                throw new AuraHandledException('No record found with the provided ID.');
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Pour ProjectProductChild__c
@AuraEnabled(cacheable=true)
public static ProjectProduct__c getParentDatesFromProductChild(String childId){
    try{
        ProjectProductChild__c childRecord = [SELECT ProjectProductParent__r.EndDate__c, ProjectProductParent__r.ProjectStartDate__c
                                              FROM ProjectProductChild__c
                                              WHERE Id = :childId
                                              LIMIT 1];
        if(childRecord.ProjectProductParent__r != null){
            return childRecord.ProjectProductParent__r;
        } else {
            throw new AuraHandledException('Parent ProjectProduct not found.');
        }
    } catch(Exception e){
        throw new AuraHandledException(e.getMessage());
    }
}

// Pour ProjectShareclassChild__c
@AuraEnabled(cacheable=true)
public static ProjectProduct__c getParentDatesFromShareclassChild(String shareclassChildId){
    try{
        ProjectShareclassChild__c childRecord = [SELECT ProjectShareclasses__r.ProjectProduct__r.EndDate__c,
                                                        ProjectShareclasses__r.ProjectProduct__r.ProjectStartDate__c
                                                 FROM ProjectShareclassChild__c 
                                                 WHERE Id = :shareclassChildId
                                                 LIMIT 1];
        if(childRecord.ProjectShareclasses__r?.ProjectProduct__r != null){
            return childRecord.ProjectShareclasses__r.ProjectProduct__r;
        } else {
            throw new AuraHandledException('Parent ProjectProduct not found.');
        }
    }catch(Exception e){
        throw new AuraHandledException(e.getMessage());
    }
}

}