global with sharing class WS_WTPWorldclassBatch
implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    // Status que l'on veut surveiller
    private static final Set<String> WATCH_STATUSES = new Set<String>{
        'NEW','New','new'
    };

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // On ne prend que les jobs avec UIDs valides et status à traiter
        String soql =
            'SELECT Id, WorkTogetherProcess__c, ProjectUid__c, JobUid__c, Status__c, SourceFileName__c ' +
            'FROM WorldclassJob__c ' +
            'WHERE ProjectUid__c != null ' +
            'AND JobUid__c != null ' +
            'AND Status__c IN :WATCH_STATUSES ' +
            'ORDER BY CreatedDate ASC ' +
            'LIMIT 2000';
        return Database.getQueryLocator(soql);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope.isEmpty()) return;

        // 1) Authentification (une seule fois par exécution)
        String token;
        try {
            token = WS_WTPSendFileToWordclass.login();
        } catch (Exception e) {
            System.debug('Login Phrase KO: ' + e.getMessage());
            return;
        }

        Set<Id> candidateCases = new Set<Id>();
        List<WorldclassJob__c> completedJobs = new List<WorldclassJob__c>();
        List<ContentVersion>   cvsToInsert = new List<ContentVersion>();

        // 2) Traiter chaque job (max 2 callouts/job : statut + download si terminé)
        for (SObject so : scope) {
            WorldclassJob__c j = (WorldclassJob__c) so;

            // a) Lire le statut du job
            String apiStatus = WTP_PhraseApiUtil.getJobStatus(token, j.ProjectUid__c, j.JobUid__c);
            system.debug('apiStatus :'+apiStatus);
            if (apiStatus == null) {
                // pas de changement, juste marquer la sync
                //completedJobs.add(new WorldclassJob__c(Id=j.Id, LastSync__c=System.now()));
                continue;
            }

            // b) Si terminé → download + attach + marquer COMPLETED
            if (apiStatus.equalsIgnoreCase('COMPLETED') || apiStatus.equalsIgnoreCase('DELIVERED')) {
                ContentVersion cv = WTP_PhraseApiUtil.downloadTargetAsContentVersion(
                    token, j.ProjectUid__c, j.JobUid__c, j.WorkTogetherProcess__c, j.SourceFileName__c
                );
                if (cv != null) {
                    cvsToInsert.add(cv);
                    system.debug('cv title  :'+cv.Title);
                    completedJobs.add(new WorldclassJob__c(
                        Id          = j.Id,
                        Status__c   = 'COMPLETED'
                        //LastSync__c = System.now()
                    ));
                    candidateCases.add(j.WorkTogetherProcess__c);
                }
            } else {
                // c) Sinon, juste refléter le statut courant
                /*completedJobs.add(new Worldclass_Job__c(
                    Id          = j.Id,
                    Status__c   = apiStatus
                    LastSync__c = System.now()
                ));*/
            }
        }

        // Insert des fichiers avec gestion des succès/échecs
        List<WorldclassJob__c> completedUpdatesToApply = new List<WorldclassJob__c>();

        // DML groupés
        if (!cvsToInsert.isEmpty()) {
            try { 
                Database.SaveResult[] sr = Database.insert(cvsToInsert, /* allOrNone */ false);
                // Seuls les indexes qui ont réussi valident la MAJ COMPLETED du job
                for (Integer i = 0; i < sr.size(); i++) {
                    if (sr[i].isSuccess()) {
                        completedUpdatesToApply.add(completedJobs[i]);
                    } else {
                        // log utile
                        System.debug('Insert CV KO idx ' + i + ' : ' +
                            String.join(new List<String>{
                                sr[i].getErrors().isEmpty() ? '' : sr[i].getErrors()[0].getStatusCode() + '',
                                sr[i].getErrors().isEmpty() ? '' : sr[i].getErrors()[0].getMessage()
                            }, ' - ')
                        );
                    }
                }
            } catch (Exception e) { System.debug('Insert CV KO: ' + e.getMessage()); }
        }
        if (!completedUpdatesToApply.isEmpty()) {
            try {
                Database.update(completedUpdatesToApply, /* allOrNone */ false);
            } catch (Exception e) {
                System.debug('Update jobs KO: ' + e.getMessage());
            }
        }

        // >>> ICI : vérifier et marquer les cases "Translated" si tout est complété
        WTP_PhraseApiUtil.markTranslatedIfAllJobsCompleted(candidateCases);
    }

    global void finish(Database.BatchableContext bc) {
        // Optionnel: log, chaining, etc.
    }

}