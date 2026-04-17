public with sharing class ProjectManagementPhaseController {
    @AuraEnabled(cacheable=true)
    public static List<ProjectProductChild__c> getProjectChildren(Id parentId) {
        return [
            SELECT Id, Name, StartDate__c, EndDate__c, CompletionRateStep__c,
                   Status__c, RAG__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c = :parentId
            ORDER BY StartDate__c
        ];
    }
 
    @AuraEnabled
    public static List<ProjectProductChild__c> updateProjectChildren(List<ProjectProductChild__c> updatedRecords, Id parentId) {
        update updatedRecords;
        return getProjectChildren(parentId);
    }
}