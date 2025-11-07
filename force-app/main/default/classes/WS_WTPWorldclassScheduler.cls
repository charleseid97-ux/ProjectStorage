global with sharing class WS_WTPWorldclassScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Lance le batch avec un scope petit pour respecter les callouts
        Database.executeBatch(new WS_WTPWorldclassBatch(), 10);
    }

    // Méthode utilitaire pour (re)programmer côté Apex
    /*public static void scheduleEvery5Minutes() {
        // CRON: second minute hour day-of-month month day-of-week optional-year
        // "0 0/5 * * * ?" = toutes les 5 minutes
        String cron = '0 0/5 * * * ?';
        System.schedule('WTP Phrase Poll - every 5 min', cron, new WS_WTPWorldclassScheduler());
    }*/
}