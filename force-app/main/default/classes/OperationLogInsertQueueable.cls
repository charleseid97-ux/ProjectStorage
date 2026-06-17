public without sharing class OperationLogInsertQueueable implements Queueable {
    private List<OperationLog__c> recordsToInsert;

    // Stocke une copie des logs à insérer par le job asynchrone.
    public OperationLogInsertQueueable(List<OperationLog__c> recordsToInsert) {
        this.recordsToInsert = new List<OperationLog__c>();

        if (recordsToInsert != null) {
            this.recordsToInsert.addAll(recordsToInsert);
        }
    }

    // Insère les logs en mode partiel pour éviter qu'un record invalide fasse échouer tout le job.
    public void execute(QueueableContext context) {
        if (recordsToInsert.isEmpty()) {
            return;
        }

        try {
            Database.insert(recordsToInsert, false);
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'OperationLogInsertQueueable failed to insert logs: ' + ex.getMessage());
        }
    }
}
