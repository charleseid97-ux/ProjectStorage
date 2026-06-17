@IsTest
private class OperationLogPurgeBatchTest {
    // Vérifie que le batch supprime les logs expirés sans toucher aux logs encore valides.
    @IsTest
    static void batchDeletesOnlyExpiredLogs() {
        OperationLog__c expiredLog = new OperationLog__c(
            Level__c = 'INFO',
            SourceRecordId__c = '001000000000001AAA',
            Operation__c = 'Expired',
            ExpirationDate__c = Date.today().addDays(-1)
        );
        OperationLog__c activeLog = new OperationLog__c(
            Level__c = 'INFO',
            SourceRecordId__c = '001000000000002AAA',
            Operation__c = 'Active',
            ExpirationDate__c = Date.today().addDays(1)
        );
        insert new List<OperationLog__c>{ expiredLog, activeLog };

        Id expiredLogId = expiredLog.Id;
        Id activeLogId = activeLog.Id;

        Test.startTest();
        Database.executeBatch(new OperationLogPurgeBatch(), 50);
        Test.stopTest();

        Integer expiredCount = [
            SELECT COUNT()
            FROM OperationLog__c
            WHERE Id = :expiredLogId
        ];
        Integer activeCount = [
            SELECT COUNT()
            FROM OperationLog__c
            WHERE Id = :activeLogId
        ];

        System.assertEquals(0, expiredCount, 'Expired log should be deleted.');
        System.assertEquals(1, activeCount, 'Active log should be kept.');
    }
}
