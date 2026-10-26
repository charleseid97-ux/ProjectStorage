public without sharing class OperationLogPurgeBatch implements Database.Batchable<SObject> {
    // Sélectionne uniquement les logs dont la date d'expiration est dépassée.
    public Database.QueryLocator start(Database.BatchableContext context) {
        Date todayDate = Date.today();

        return Database.getQueryLocator([
            SELECT Id
            FROM OperationLog__c
            WHERE ExpirationDate__c <= :todayDate
        ]);
    }

    // Supprime les logs expirés en mode partiel pour continuer même si un record échoue.
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        if (scope.isEmpty()) {
            return;
        }

        Database.delete(scope, false);
    }

    // Termine le batch sans écrire de log pour éviter une boucle de purge/log.
    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'OperationLogPurgeBatch finished.');
    }
}
