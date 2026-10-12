public without sharing class MainShareClassBatch implements Database.Batchable<SObject> {

    // Returns all Share Class Country Registrations that must be initialized or recalculated.
    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Country__c
            WHERE ShareClass__c != null
            AND Country__c != null
        ]);
    }

    // Recalculates every Product + Country group represented in the current batch scope.
    public void execute(Database.BatchableContext batchContext, List<Country__c> scope) {
        Set<Id> registrationIds = new Map<Id, Country__c>(scope).keySet();
        MainShareClassService.recalculateByRegistrationIds(registrationIds);
    }

    // No final action is required after all calculation scopes have completed.
    public void finish(Database.BatchableContext batchContext) {
    }
}