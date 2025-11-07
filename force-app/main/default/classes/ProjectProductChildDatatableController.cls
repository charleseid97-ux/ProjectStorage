public with sharing class ProjectProductChildDatatableController {
 
    @AuraEnabled(cacheable=true)
    public static List<ProjectProductChild__c> getChildren(Id parentId) {
        return [
            SELECT Id, Name, StartDate__c, EndDate__c, CompletionRateStep__c, Status__c, RAG__c, ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c = :parentId
            ORDER BY StartDate__c
        ];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getStatusPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = ProjectProductChild__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : picklistEntries) {
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled
    public static List<ProjectProductChild__c> updateChildren(List<ProjectProductChild__c> updatedRecords) {
        update updatedRecords;
        return [
            SELECT Id, Name, StartDate__c, EndDate__c, CompletionRateStep__c, Status__c, RAG__c, ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE Id IN :updatedRecords
        ];
    }
 
    @AuraEnabled
    public static void deleteChild(Id recordId) {
        delete [SELECT Id FROM ProjectProductChild__c WHERE Id = :recordId];
    }
}