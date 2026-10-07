@IsTest
private class MainShareClassBatchTest {

    // Verifies that the initialization batch can be scheduled and completed safely.
    @IsTest
    static void testBatchExecution() {
        Test.startTest();
        Id jobId = Database.executeBatch(new MainShareClassBatch(), 200);
        Test.stopTest();

        AsyncApexJob batchJob = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('BatchApex', batchJob.JobType);
        System.assertEquals('Completed', batchJob.Status);
    }
}