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
}
