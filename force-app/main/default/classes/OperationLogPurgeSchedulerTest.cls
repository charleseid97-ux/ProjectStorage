@IsTest
private class OperationLogPurgeSchedulerTest {
    // Vérifie que le scheduler peut être planifié via Apex.
    @IsTest
    static void scheduleDailyCreatesScheduledJob() {
        Test.startTest();
        String jobId = OperationLogPurgeScheduler.scheduleDaily(2);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'A scheduled job id should be returned.');
    }

        // Vérifie que le scheduler par défaut planifie bien à 02:00.
    @IsTest
    static void scheduleDailyAt2AMCreatesScheduledJob() {
        Test.startTest();
        String jobId = OperationLogPurgeScheduler.scheduleDailyAt2AM();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'A scheduled job id should be returned.');
    }
    
}
