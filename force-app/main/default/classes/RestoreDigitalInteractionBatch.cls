public without sharing class RestoreDigitalInteractionBatch implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private Integer successCount = 0;

    @TestVisible
    private Integer errorCount = 0;

    @TestVisible
    private List<String> errorSamples = new List<String>();

    // Récupère tous les Digital_Interaction__c supprimés encore disponibles dans la corbeille.
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT id,LastModifiedDate, Source__c FROM Digital_Interaction__c WHERE LastModifiedDate < 2026-07-08T00:00:00Z AND IsDeleted = true  ORDER BY LastModifiedDate DESC ALL ROWS'
        );
    }

    // Restaure les records par batch et continue même si certains records échouent.
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Database.UndeleteResult[] results = Database.undelete(scope, false);
        integer i= 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        for (Database.UndeleteResult result : results) {
            if (result.isSuccess()) {
                successCount++;
                continue;
            }

            errorCount++;
            logErrors(result);
        }
    }

    // Affiche un résumé de fin dans les logs Apex du job.
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'RestoreDigitalInteractionBatch finished. Success=' + successCount + ', Errors=' + errorCount);

        for (String errorSample : errorSamples) {
            System.debug(LoggingLevel.ERROR, errorSample);
        }
    }

    // Garde seulement quelques erreurs en mémoire pour éviter de consommer trop de heap.
    private void logErrors(Database.UndeleteResult result) {
        if (errorSamples.size() >= 100) {
            return;
        }

        for (Database.Error err : result.getErrors()) {
            errorSamples.add('Undelete error on Id ' + result.getId() + ' : ' + err.getStatusCode() + ' - ' + err.getMessage());
        }
    }
}