/** ──────────────────────────────────────
 * @description Controller of the projectManagementPhase LWC ("Project Management Phase" table, Admin interface tab of
 *                  the Project Product record pages): lists the project's ProjectProductChild__c phases and saves the
 *                  dates and statuses edited in the table.
 *              Save errors (validation rules, trigger errors) are returned to the LWC as an AuraHandledException with
 *                  the readable message, shown in a toast (FIX-20270).
 * @lastModifiedBy Charles EID   [19-10-26]
 * @testClass Test_ProjectManagementPhaseController
 * @coverage 100%   [19-10-26]
 ────────────────────────────────────── */
public with sharing class ProjectManagementPhaseController {
    @AuraEnabled(cacheable=true)
    public static List<ProjectProductChild__c> getProjectChildren(Id parentId) {
        return [SELECT Id, Name, StartDate__c, EndDate__c, CompletionRateStep__c, Status__c, RAG__c
                FROM ProjectProductChild__c
                WHERE ProjectProductParent__c = :parentId
                ORDER BY StartDate__c];
    }

    @AuraEnabled
    public static List<ProjectProductChild__c> updateProjectChildren(List<ProjectProductChild__c> updatedRecords, Id parentId) {
        try {
            update updatedRecords;
        }
        catch (DmlException e) {
            AuraHandledException auraException = new AuraHandledException(e.getDmlMessage(0));
            auraException.setMessage(e.getDmlMessage(0));
            throw auraException;
        }
        return getProjectChildren(parentId);
    }
}