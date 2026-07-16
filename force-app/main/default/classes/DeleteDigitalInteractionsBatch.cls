public without sharing class DeleteDigitalInteractionsBatch implements Database.Batchable<SObject> {
    @TestVisible
    private static final Datetime CUTOFF_DATE = Datetime.newInstanceGmt(2025, 1, 1, 0, 0, 0);

    // Construit la requête avec un bind Apex pour éviter les soucis de format DateTime SOQL.
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Digital_Interaction__c
            WHERE CreatedDate > :CUTOFF_DATE and  Engagement_Type__c ='web' 
        ]);
    }

    // Supprime les enregistrements par lot, sans bloquer tout le scope si un record échoue.
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Database.DeleteResult[] results = Database.delete(scope, false);

        for (Database.DeleteResult result : results) {
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Suppression Digital_Interaction__c impossible : ' + error.getStatusCode() + ' - ' + error.getMessage()
                    );
                }
            }
        }
    }

    // Point d'extension pour ajouter un email/log de fin si besoin.
    public void finish(Database.BatchableContext bc) {
    }
}