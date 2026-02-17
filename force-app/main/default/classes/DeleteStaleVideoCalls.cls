// Batch Apex permettant de supprimer des VideoCall selon des critères précis
// - IsRecorded = false
// - Aucun enregistrement Meeting_Note__c lié
// - Créé il y a plus de 3 heures
public without sharing class DeleteStaleVideoCalls
    implements Database.Batchable<SObject>, Schedulable {

    // Flag : true -> suppression réelle, false -> debug seulement (liste des IDs)
    private Boolean performDelete;

    // Constructeurs
    // Par défaut on supprime (compatibilité avec l'usage existant)
    public DeleteStaleVideoCalls() {
        this(true);
    }

    // Permet d'instancier en mode debug (performDelete = false)
    public DeleteStaleVideoCalls(Boolean performDelete) {
        this.performDelete = performDelete;
    }

    // Méthode start : définit la requête SOQL exécutée par le batch
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Date/heure limite : maintenant moins 3 heures
        Datetime cutoff = System.now().addHours(-3);

        // Debug : affichage du cutoff et du mode
        System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.start - cutoff = ' + cutoff + ' performDelete = ' + performDelete);

        // Requête SOQL filtrant les VideoCall à supprimer
        return Database.getQueryLocator([
            SELECT Id
            FROM VideoCall
            WHERE IsRecorded = false
            AND CreatedDate <= :cutoff
            AND Id NOT IN (
                SELECT VideoCall__c
                FROM Meeting_Note__c
            )
        ]);
    }

    // Méthode execute : appelée pour chaque lot d’enregistrements
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Liste des identifiants à supprimer
        List<Id> idsToDelete = new List<Id>();

        // Extraction des Id depuis le scope
        for (SObject record : scope) {
            idsToDelete.add(record.Id);
        }

        // Conversion explicite Id -> String pour le log
        List<String> idStrings = new List<String>();
        for (Id i : idsToDelete) {
            idStrings.add(String.valueOf(i));
        }

        // Debug : nombre et liste (limité à 2000 caractères pour éviter log trop long)
        String idsLog = String.join(idStrings, ',');
        if (idsLog.length() > 2000) {
            idsLog = idsLog.substring(0, 2000) + '...';
        }
        System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.execute - scope size=' + scope.size() + ' ids=[' + idsLog + ']');

        // Si en mode debug, on s'arrête après le log
        if (!performDelete) {
            System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.execute - MODE DEBUG : aucune suppression effectuée.');
            return;
        }

        // Suppression avec gestion des succès partiels
        if (!idsToDelete.isEmpty()) {
            try {
                // allOrNone = false pour obtenir les résultats détaillés
                Database.DeleteResult[] results = Database.delete(idsToDelete, false);

                Integer successCount = 0;
                Integer failureCount = 0;
                for (Integer i = 0; i < results.size(); i++) {
                    Database.DeleteResult dr = results[i];
                    Id processedId = idsToDelete[i];
                    if (dr.isSuccess()) {
                        successCount++;
                        System.debug(LoggingLevel.INFO, 'Deleted Id=' + processedId);
                    } else {
                        failureCount++;
                        // Concaténation des messages d'erreur
                        String errs = '';
                        for (Database.Error err : dr.getErrors()) {
                            errs += '[' + err.getStatusCode() + '] ' + err.getMessage() + '; ';
                        }
                        System.debug(LoggingLevel.ERROR, 'Failed to delete Id=' + processedId + ' Errors=' + errs);
                    }
                }

                System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.execute - suppression terminée. success=' + successCount + ' failure=' + failureCount);

            } catch (Exception ex) {
                // Sauvegarde d'un log si exception générale
                System.debug(LoggingLevel.ERROR, 'DeleteStaleVideoCalls.execute - Exception lors de la suppression : ' + ex.getMessage());
            }
        } else {
            System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.execute - aucun Id à supprimer dans ce lot.');
        }
    }

    // Méthode finish : exécutée une fois le batch terminé
    public void finish(Database.BatchableContext bc) {
        // Point d’extension pour notifications ou logs post-traitement
        System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.finish - batch terminé. performDelete = ' + performDelete);
    }

    // Implémentation Schedulable pour permettre l’exécution planifiée
    // Par défaut la planification exécute en mode suppression réelle (comportement conservateur)
    public void execute(SchedulableContext sc) {
        System.debug(LoggingLevel.INFO, 'DeleteStaleVideoCalls.execute (Schedulable) - lancement du batch planifié');
        Database.executeBatch(new DeleteStaleVideoCalls(true), 200);
    }

    // --- Helper static pour lancer rapidement depuis Execute Anonymous ---
    // Exemple : DeleteStaleVideoCalls.runNow(false); // debug only
    public static void runNow(Boolean performDelete) {
        Database.executeBatch(new DeleteStaleVideoCalls(performDelete), 200);
    }
}