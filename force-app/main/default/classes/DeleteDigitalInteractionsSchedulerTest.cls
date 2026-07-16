@IsTest
private class DeleteDigitalInteractionsSchedulerTest {
    // Vérifie que le scheduler peut être planifié par cron.
    @IsTest
    static void schedulerEnqueuesBatch() {
        String cron = '0 0 2 1 1 ? 2030';

        Test.startTest();
        Id scheduledJobId = System.schedule(
            'UT Delete Digital Interactions Scheduler',
            cron,
            new DeleteDigitalInteractionsScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduledJobId, 'Le scheduler doit être créé.');
    }

    // Vérifie le helper de planification quotidienne.
    @IsTest
    static void helperSchedulesDailyJob() {
        Test.startTest();
        Id scheduledJobId = DeleteDigitalInteractionsScheduler.scheduleDailyAt2AM();
        Test.stopTest();

        System.assertNotEquals(null, scheduledJobId, 'Le helper doit créer le scheduler.');
    }
}