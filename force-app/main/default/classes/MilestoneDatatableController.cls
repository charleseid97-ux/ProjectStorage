public with sharing class MilestoneDatatableController {
    
    @AuraEnabled(cacheable=true)
    public static List<Milestone__c> getMilestones(Id parentId) {
        return [
            SELECT Id, Name, StartDate__c, Status__c, Project_product__c, RAG__c
            FROM Milestone__c
            WHERE Project_product__c = :parentId
            ORDER BY StartDate__c
        ];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getStatusPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = Milestone__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : picklistEntries) {
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled
    public static List<Milestone__c> updateMilestones(List<Milestone__c> updatedRecords) {
        update updatedRecords;
        return [
            SELECT Id, Name, StartDate__c, Status__c, Project_product__c, RAG__c
            FROM Milestone__c
            WHERE Id IN :updatedRecords
        ];
    }
}