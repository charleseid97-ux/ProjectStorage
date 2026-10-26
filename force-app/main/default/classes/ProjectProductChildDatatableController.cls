/** ──────────────────────────────────────
 * @description Controller of the projectProductChildDatatable LWC ("Project phases management"): lists, updates and
 *                  deletes the ProjectProductChild__c phases of a project, and returns the Status picklist values.
 *              FIX-20270: this component might not be used (the LWC is on no flexipage in the repo, duplicate of
 *                  projectManagementPhase). Once confirmed in Prod, it may be deleted with the projectProductChildDatatable LWC.
 * @testClass Test_ProjectProductChildDatatableCTRL
 * @coverage 100%   [19-10-26]
 ────────────────────────────────────── */
public with sharing class ProjectProductChildDatatableController {
 
    @AuraEnabled(cacheable=true)
    public static List<ProjectProductChild__c> getChildren(Id parentId) {
        return [SELECT Id, Name, StartDate__c, EndDate__c, CompletionRateStep__c, Status__c, RAG__c, ProjectProductParent__c
                FROM ProjectProductChild__c
                WHERE ProjectProductParent__c = :parentId
                ORDER BY StartDate__c];
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
        return [SELECT Id, Name, StartDate__c, EndDate__c, CompletionRateStep__c, Status__c, RAG__c, ProjectProductParent__c
                FROM ProjectProductChild__c
                WHERE Id IN :updatedRecords];
    }
 
    @AuraEnabled
    public static void deleteChild(Id recordId) {
        delete [SELECT Id FROM ProjectProductChild__c WHERE Id = :recordId];
    }
}