public with sharing class RollbackTeamValidationController {
    @AuraEnabled(cacheable=true)
    public static List<RecordType> getProjectProductChildRecordTypes() {
        return [SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'ProjectProductChild__c'];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getTeamPicklistValues() {
        Schema.DescribeFieldResult fieldResult = ProjectProductChild__c.TECH_TeamValidation__c.getDescribe();
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled
    public static void rollbackTeamValidation(String phase, String status, List<String> teams, Id recordId) {
        List<ProjectProductChild__c> records = [
            SELECT Id, TECH_TeamValidation__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c = :recordId
            AND RecordType.DeveloperName = :phase
        ];
 
        for (ProjectProductChild__c record : records) {
            Set<String> existingTeams = new Set<String>();
            if (record.TECH_TeamValidation__c != null) {
                existingTeams.addAll(record.TECH_TeamValidation__c.split(';'));
            }
 
            if (status == 'Draft') {
                existingTeams.removeAll(teams);
            } else if (status == 'Validated') {
                existingTeams.addAll(teams);
            }
 
            record.TECH_TeamValidation__c = existingTeams.isEmpty() ? null : String.join(new List<String>(existingTeams), ';');
        }
 
        if (!records.isEmpty()) {
            update records;
        }
    }
}