/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Rollback Validation panel (rollbackTeamValidation),
 *                  on the "Admin interface" tab of the Project Product record pages.
 *              Lists the Project Product Child phases and the teams of TECH_TeamValidation__c - with ProductStrategy
 *                  and IS mutually exclusive according to the project's Scope__c (US-20120, blank = PS) - and adds or
 *                  removes the selected teams from the validated teams of the chosen phase.
 *              The teams excluded for the project's Scope come from the PMT matrix (PMTMatrix.forScope, FIX-20178).
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_RollbackTeamValidationController
 * @coverage 100%   [09-10-26]
 ────────────────────────────────────── */
public with sharing class RollbackTeamValidationController {
    @AuraEnabled(cacheable=true)
    public static List<RecordType> getProjectProductChildRecordTypes() {
        return [SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'ProjectProductChild__c'];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getTeamPicklistValues(Id recordId) {
        // US-20120 / FIX-20178: teams that don't apply to the project's Scope (PMTTeam__mdt.Scope__c, blank = PS) are not offered
        String scope = ProjectProductSetupHandlerUtilities.getProjectScope(recordId);
        PMTMatrix matrix = PMTMatrix.get();
        Set<String> excludedTeams = new Set<String>();
        for (PMTMatrix.Team team : matrix.teams) excludedTeams.add(team.key);
        for (PMTMatrix.Team team : matrix.forScope(scope).teams) excludedTeams.remove(team.key);

        Schema.DescribeFieldResult fieldResult = ProjectProductChild__c.TECH_TeamValidation__c.getDescribe();
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (excludedTeams.contains(entry.getValue())) continue;
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled
    public static void rollbackTeamValidation(String phase, String status, List<String> teams, Id recordId) {
        List<ProjectProductChild__c> records = [SELECT Id, TECH_TeamValidation__c
                                                FROM ProjectProductChild__c
                                                WHERE ProjectProductParent__c = :recordId
                                                AND RecordType.DeveloperName = :phase];
 
        for (ProjectProductChild__c record : records) {
            Set<String> existingTeams = new Set<String>();
            if (record.TECH_TeamValidation__c != null) {
                existingTeams.addAll(record.TECH_TeamValidation__c.split(';'));
            }
 
            if (status == 'Draft') {
                existingTeams.removeAll(teams);
            } 
            else if (status == 'Validated') {
                existingTeams.addAll(teams);
            }
 
            record.TECH_TeamValidation__c = existingTeams.isEmpty() ? null : String.join(new List<String>(existingTeams), ';');
        }
 
        if (!records.isEmpty()) {
            update records;
        }
    }
}