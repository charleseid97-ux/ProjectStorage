@IsTest
private class OperationLogServiceTest {
    // Vérifie le logging synchrone, la corrélation et la rétention par défaut.
    @IsTest
    static void logAndFlushCreatesRecords() {
        Id sourceId = '001000000000001';

        OperationLogService.resetForTest();
        OperationLogService.setCorrelationId('UNIT-TEST');
        OperationLogService.info(sourceId, 'Account Sync', 'Account synchronized successfully.');

        try {
            Integer denominator = 0;
            Integer result = 10 / denominator;
        } catch (Exception ex) {
            OperationLogService.error(sourceId, 'Account Sync', 'Account synchronization failed.', ex);
        }

        OperationLogService.flush();

        String sourceRecordId = String.valueOf(sourceId);
        List<OperationLog__c> logs = [
            SELECT Level__c, SourceRecordId__c, SourceObject__c, CorrelationId__c,
                   ExpirationDate__c, ExceptionType__c, StackTrace__c
            FROM OperationLog__c
            WHERE SourceRecordId__c = :sourceRecordId
        ];

        System.assertEquals(2, logs.size(), 'Two logs should have been created.');
        for (OperationLog__c logRecord : logs) {
            System.assertEquals(sourceRecordId, logRecord.SourceRecordId__c);
            System.assertEquals('Account', logRecord.SourceObject__c);
            System.assertEquals('UNIT-TEST', logRecord.CorrelationId__c);
            System.assertEquals(Date.today().addDays(100), logRecord.ExpirationDate__c);
        }
    }

    // Vérifie le mode asynchrone via Queueable.
    @IsTest
    static void asyncFlushCreatesRecords() {
        Id sourceId = '001000000000002';

        OperationLogService.resetForTest();
        OperationLogService.warn(sourceId, 'Async Operation', 'Async warning.');

        Test.startTest();
        OperationLogService.flushAsync();
        Test.stopTest();

        String sourceRecordId = String.valueOf(sourceId);
        Integer logCount = [
            SELECT COUNT()
            FROM OperationLog__c
            WHERE SourceRecordId__c = :sourceRecordId
            AND Level__c = 'WARN'
        ];

        System.assertEquals(1, logCount, 'The queueable should insert the buffered log.');
    }

    // Vérifie l'entrée générique avec contexte JSON et date d'expiration métier.
    @IsTest
    static void genericEntrySupportsCustomRetentionAndContext() {
        OperationLogService.resetForTest();

        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = OperationLogService.Level.INFO;
        entry.sourceRecordId = '001000000000003';
        entry.sourceObjectApiName = 'Account';
        entry.operation = 'Retention Test';
        entry.message = 'Custom expiration date.';
        entry.contextJson = '{"scope":"unit-test"}';
        entry.expirationDate = Date.today().addDays(365);
        entry.apexClass = 'OperationLogServiceTest';
        entry.methodName = 'genericEntrySupportsCustomRetentionAndContext';

        OperationLogService.log(entry);
        OperationLogService.flush();

        OperationLog__c logRecord = [
            SELECT Context__c, ExpirationDate__c, ApexClass__c, MethodName__c
            FROM OperationLog__c
            WHERE SourceRecordId__c = '001000000000003'
            LIMIT 1
        ];

        System.assertEquals('{"scope":"unit-test"}', logRecord.Context__c);
        System.assertEquals(Date.today().addDays(365), logRecord.ExpirationDate__c);
        System.assertEquals('OperationLogServiceTest', logRecord.ApexClass__c);
        System.assertEquals('genericEntrySupportsCustomRetentionAndContext', logRecord.MethodName__c);
    }

        // Vérifie les niveaux texte, les valeurs nulles et la corrélation générée automatiquement.
    @IsTest
    static void stringLogSupportsDefaultsAndLevels() {
        OperationLogService.resetForTest();

        OperationLogService.log(null, null, null, null, null, null, null);
        OperationLogService.log('debug', '001000000000004', 'Account', 'Debug Test', 'Debug message.', null, null);
        OperationLogService.log('invalid', '001000000000005', 'Account', 'Default Test', 'Default message.', null, null);

        OperationLogService.flush();

        List<OperationLog__c> logs = [
            SELECT Level__c, CorrelationId__c
            FROM OperationLog__c
            WHERE Operation__c IN ('Debug Test', 'Default Test')
            OR Level__c = 'INFO'
        ];

        System.assertEquals(3, logs.size(), 'Three logs should have been created.');

        for (OperationLog__c logRecord : logs) {
            System.assertNotEquals(null, logRecord.CorrelationId__c, 'Correlation id should be generated.');
        }
    }

    // Vérifie les sorties rapides sans erreur quand aucune donnée ne doit être traitée.
    @IsTest
    static void emptyAndNullInputsDoNothing() {
        OperationLogService.resetForTest();

        OperationLogService.log(null);
        OperationLogService.flush();
        OperationLogService.flushAsync();

        Integer logCount = [
            SELECT COUNT()
            FROM OperationLog__c
        ];

        System.assertEquals(0, logCount, 'No log should be created for null or empty inputs.');
    }

    // Vérifie le flush automatique quand le buffer atteint la limite bulk.
    @IsTest
    static void autoFlushWhenBufferLimitIsReached() {
        OperationLogService.resetForTest();

        for (Integer index = 0; index < 200; index++) {
            OperationLogService.info('001000000000006', 'Bulk Auto Flush', 'Buffered message ' + index);
        }

        Integer logCount = [
            SELECT COUNT()
            FROM OperationLog__c
            WHERE Operation__c = 'Bulk Auto Flush'
        ];

        System.assertEquals(200, logCount, 'Buffer should flush automatically at the limit.');
    }
}
