@IsTest
private class OperationLogRecordControllerTest {
    // Vérifie que le contrôleur retourne uniquement les logs du record courant avec le filtre de niveau.
    @IsTest
    static void getLogsReturnsRecordLogsOnly() {
        Id firstSourceId = '001000000000004';
        Id secondSourceId = '001000000000005';

        OperationLogService.resetForTest();
        OperationLogService.info(firstSourceId, 'First Operation', 'Info message.');
        OperationLogService.warn(firstSourceId, 'Second Operation', 'Warn message.');
        OperationLogService.error(secondSourceId, 'Other Operation', 'Other account error.');
        OperationLogService.flush();

        String recordId = String.valueOf(firstSourceId);
        List<OperationLogRecordController.LogRow> rows = OperationLogRecordController.getLogs(recordId, 10, 'INFO');

        System.assertEquals(2, rows.size(), 'Only INFO, WARN and ERROR logs of the current record should be returned.');
        for (OperationLogRecordController.LogRow row : rows) {
            System.assertEquals(recordId, row.sourceRecordId);
            System.assertNotEquals('DEBUG', row.level);
        }
    }

    // Vérifie que le filtre WARN exclut les logs INFO.
    @IsTest
    static void getLogsAppliesWarnFilter() {
        Id sourceId = '001000000000006';

        OperationLogService.resetForTest();
        OperationLogService.info(sourceId, 'Info Operation', 'Info message.');
        OperationLogService.warn(sourceId, 'Warn Operation', 'Warn message.');
        OperationLogService.flush();

        List<OperationLogRecordController.LogRow> rows = OperationLogRecordController.getLogs(String.valueOf(sourceId), 10, 'WARN');

        System.assertEquals(1, rows.size(), 'Only the WARN log should be returned.');
        System.assertEquals('WARN', rows[0].level);
    }
}
