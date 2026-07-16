public without sharing class DeleteDigitalInteractionsScheduler implements Schedulable {
    public static final Integer BATCH_SIZE = 200;

    // Lance le batch quand le cron Salesforce déclenche le scheduler.
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DeleteDigitalInteractionsBatch(), BATCH_SIZE);
    }

    // Helper pour planifier le traitement tous les jours à 02:00.
    public static Id scheduleDailyAt2AM() {
        return System.schedule(
            'Delete Digital Interactions - Daily 2AM',
            '0 0 2 * * ?',
            new DeleteDigitalInteractionsScheduler()
        );
    }
}