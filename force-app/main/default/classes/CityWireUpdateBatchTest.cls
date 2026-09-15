@isTest
private class CityWireUpdateBatchTest {

    private static final String ISIN_MATCHED = 'FR0000000001';
    private static final String ISIN_UNMATCHED = 'FR0000000002';
    private static final String ISIN_CONFLICT_A = 'FR0000000003';
    private static final String ISIN_CONFLICT_B = 'FR0000000004';
    private static final String ISIN_FAILING = 'FR0000000005';
    private static final String ISIN_EMPTY = 'FR0000000006';
    private static final String ISIN_UPDATE_FAILURE = 'FR0000000007';
    private static final String ISIN_NULL_TOLERANT_A = 'FR0000000008';
    private static final String ISIN_NULL_TOLERANT_B = 'FR0000000009';
    private static final String ISIN_STALE_NO_CONFLICT_A = 'FR0000000010';
    private static final String ISIN_STALE_NO_CONFLICT_B = 'FR0000000011';

    private static final Decimal CITYWIRE_ID_MATCHED = 12345;
    private static final Decimal CITYWIRE_ID_UNMATCHED = 55555;
    private static final Decimal CITYWIRE_ID_CONFLICT = 99999;
    private static final Decimal CITYWIRE_ID_UPDATE_FAILURE = 77777;
    private static final Decimal CITYWIRE_ID_NULL_TOLERANT = 11111;
    private static final Decimal CITYWIRE_ID_STALE_NO_CONFLICT = 22222;

    // Test fixtures use dates relative to "today" rather than hardcoded ones, since the batch now ignores
    // any rating older than 3 months — a hardcoded date would silently become stale as time passes.
    private static String recentDate(Integer daysAgo) {
        return String.valueOf(Date.today().addDays(-daysAgo));
    }

    private class RoutingMock implements HttpCalloutMock {
        Map<String, String> bodyByIsin = new Map<String, String>();
        Set<String> failIsins = new Set<String>();

        RoutingMock withBody(String isin, String body) {
            bodyByIsin.put(isin, body);
            return this;
        }

        RoutingMock withFailure(String isin) {
            failIsins.add(isin);
            return this;
        }

        public HttpResponse respond(HttpRequest request) {
            String endpoint = request.getEndpoint();
            String isin = endpoint.substringAfterLast('/');

            HttpResponse res = new HttpResponse();
            if (failIsins.contains(isin)) {
                res.setStatusCode(500);
                res.setBody('{"error":"server error"}');
                return res;
            }

            res.setStatusCode(200);
            res.setBody(bodyByIsin.containsKey(isin) ? bodyByIsin.get(isin) : '{"SummaryDisclaimer":"d","Managers":[]}');
            return res;
        }
    }

    private static String managerBody(Decimal cityWireId, Decimal rating, String ratingDate, String imageSrc) {
        return '{"SummaryDisclaimer":"d","RatingDate":"' + ratingDate + '","Managers":[' +
            '{"ID":' + cityWireId + ',"FirstName":"John","LastName":"Doe",' +
            '"Rating":{"RatingValue":' + rating + ',"ImageSrc":"' + imageSrc + '"}}' +
        ']}';
    }

    // Rating is omitted (JSON null) rather than embedded as a string, so a genuinely missing value round-trips as Apex null.
    private static String managerBodyWithNullRating(Decimal cityWireId, String ratingDate) {
        return '{"SummaryDisclaimer":"d","RatingDate":"' + ratingDate + '","Managers":[' +
            '{"ID":' + cityWireId + ',"FirstName":"John","LastName":"Doe","Rating":{"RatingValue":null}}' +
        ']}';
    }

    private static RoutingMock defaultMock() {
        return new RoutingMock()
            .withBody(ISIN_MATCHED, managerBody(CITYWIRE_ID_MATCHED, 3, recentDate(10), 'https://citywire.com/12345.png'))
            .withBody(ISIN_UNMATCHED, managerBody(CITYWIRE_ID_UNMATCHED, 2, recentDate(12), 'https://citywire.com/55555.png'))
            .withBody(ISIN_CONFLICT_A, managerBody(CITYWIRE_ID_CONFLICT, 4, recentDate(20), 'https://citywire.com/conflict-a.png'))
            .withBody(ISIN_CONFLICT_B, managerBody(CITYWIRE_ID_CONFLICT, 5, recentDate(21), 'https://citywire.com/conflict-b.png'))
            .withFailure(ISIN_FAILING)
            .withBody(ISIN_EMPTY, '{"SummaryDisclaimer":"d","Managers":[]}')
            // Rating 999 overflows FundManager__c.CityWireRating__c (Number(2,0), max 99) to force a DML failure on update.
            .withBody(ISIN_UPDATE_FAILURE, managerBody(CITYWIRE_ID_UPDATE_FAILURE, 999, recentDate(5), 'https://citywire.com/77777.png'))
            // Same manager, one ISIN gives a real rating, the other gives a null rating (missing info, not a conflict).
            .withBody(ISIN_NULL_TOLERANT_A, managerBody(CITYWIRE_ID_NULL_TOLERANT, 7, recentDate(10), 'https://citywire.com/11111.png'))
            .withBody(ISIN_NULL_TOLERANT_B, managerBodyWithNullRating(CITYWIRE_ID_NULL_TOLERANT, recentDate(11)))
            // Same manager, one ISIN gives a real recent rating, the other gives a garbage/ancient rating date that must be ignored entirely.
            .withBody(ISIN_STALE_NO_CONFLICT_A, managerBody(CITYWIRE_ID_STALE_NO_CONFLICT, 2, recentDate(10), 'https://citywire.com/22222.png'))
            .withBody(ISIN_STALE_NO_CONFLICT_B, managerBodyWithNullRating(CITYWIRE_ID_STALE_NO_CONFLICT, '0001-01-01'));
    }

    @TestSetup
    static void setup() {
        Strategy__c strategy = new Strategy__c(Name = 'CityWire Strategy', AssetClass__c = 'Equity', Code__c = 'CWEQ');
        insert strategy;

        Product__c product = new Product__c(Name = 'CityWire Product', ProductName__c = 'CityWire Product Test', FundStrategy__c = strategy.Id);
        insert product;

        List<Share_Class__c> shareClasses = new List<Share_Class__c>();
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC Matched', ISIN_MATCHED));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC Unmatched', ISIN_UNMATCHED));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC ConflictA', ISIN_CONFLICT_A));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC ConflictB', ISIN_CONFLICT_B));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC Failing', ISIN_FAILING));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC Empty', ISIN_EMPTY));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC UpdateFailure', ISIN_UPDATE_FAILURE));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC NullTolerantA', ISIN_NULL_TOLERANT_A));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC NullTolerantB', ISIN_NULL_TOLERANT_B));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC StaleNoConflictA', ISIN_STALE_NO_CONFLICT_A));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC StaleNoConflictB', ISIN_STALE_NO_CONFLICT_B));

        Share_Class__c notMain = buildMainActiveShareClass(product.Id, 'SC NotMain', 'FR0000000099');
        notMain.IsMainShareClass__c = 'False';
        shareClasses.add(notMain);

        insert shareClasses;

        insert new FundManager__c(Name = 'Matched Manager', EmpId__c = 1, CityWireId__c = CITYWIRE_ID_MATCHED);
        insert new FundManager__c(Name = 'Conflict Manager', EmpId__c = 2, CityWireId__c = CITYWIRE_ID_CONFLICT);
        insert new FundManager__c(Name = 'Update Failure Manager', EmpId__c = 3, CityWireId__c = CITYWIRE_ID_UPDATE_FAILURE);
        insert new FundManager__c(Name = 'Null Tolerant Manager', EmpId__c = 4, CityWireId__c = CITYWIRE_ID_NULL_TOLERANT);
        insert new FundManager__c(Name = 'Stale No Conflict Manager', EmpId__c = 5, CityWireId__c = CITYWIRE_ID_STALE_NO_CONFLICT);
    }

    private static Share_Class__c buildMainActiveShareClass(Id fundId, String name, String isin) {
        return new Share_Class__c(
            Name = name,
            Fund__c = fundId,
            ISIN__c = isin,
            Status__c = 'Active',
            IsMainShareClass__c = 'True'
        );
    }

    @isTest
    static void testHappyPath_matchesAndUpdatesFundManager() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        FundManager__c updated = [SELECT CityWireRating__c, CityWireURL__c, CityWireDate__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_MATCHED];
        System.assertEquals(3, updated.CityWireRating__c);
        System.assertEquals('https://citywire.com/12345.png', updated.CityWireURL__c);
        System.assertEquals(Date.valueOf(recentDate(10)), updated.CityWireDate__c);
    }

    @isTest
    static void testUnmatchedCityWireId_logsWarningAndSkipsCreation() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Integer fundManagerCountBefore = [SELECT COUNT() FROM FundManager__c];

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        Integer fundManagerCountAfter = [SELECT COUNT() FROM FundManager__c];
        System.assertEquals(fundManagerCountBefore, fundManagerCountAfter, 'An unmatched Citywire ID must never create a new FundManager__c record');

        List<OperationLog__c> logs = [SELECT Message__c FROM OperationLog__c WHERE Operation__c = 'CityWireUnmatchedManager'];
        System.assertEquals(1, logs.size());
    }

    @isTest
    static void testConflictingRatings_logsWarningAndExcludesFromUpdate() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        FundManager__c conflictManager = [SELECT CityWireRating__c, CityWireURL__c, CityWireDate__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_CONFLICT];
        System.assertEquals(null, conflictManager.CityWireRating__c, 'A manager with two different non-null ratings must not be updated');

        List<OperationLog__c> logs = [SELECT Message__c, Context__c FROM OperationLog__c WHERE Operation__c = 'CityWireConflictDetected'];
        System.assertEquals(1, logs.size());
        Map<String, Object> context = (Map<String, Object>) JSON.deserializeUntyped(logs[0].Context__c);
        System.assert(String.valueOf(context.get('conflictDetail')).contains('Rating'), 'The conflict detail should explain what actually differed');
    }

    @isTest
    static void testNullRating_isNotAConflict_takesTheNonNullValue() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        FundManager__c manager = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_NULL_TOLERANT];
        System.assertEquals(7, manager.CityWireRating__c, 'A null rating from one ISIN must not overwrite or conflict with a real rating from another');

        List<OperationLog__c> conflictLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireConflictDetected' AND SourceRecordId__c = :manager.Id];
        System.assertEquals(0, conflictLogs.size(), 'A missing value must never be treated as a conflict');
    }

    @isTest
    static void testOldRatingDate_isIgnoredAndLogged_preventsFalseConflict() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        FundManager__c manager = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_STALE_NO_CONFLICT];
        System.assertEquals(2, manager.CityWireRating__c, 'The stale entry must be ignored entirely, leaving only the good rating');

        List<OperationLog__c> conflictLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireConflictDetected' AND SourceRecordId__c = :manager.Id];
        System.assertEquals(0, conflictLogs.size(), 'A stale/garbage rating date must never manufacture a false conflict');

        List<OperationLog__c> staleLogs = [SELECT Level__c, Context__c FROM OperationLog__c WHERE Operation__c = 'CityWireStaleRatingDate'];
        System.assertEquals(1, staleLogs.size(), 'The ignored stale entry should still be logged for visibility');
        System.assertEquals('WARN', staleLogs[0].Level__c);
    }

    @isTest
    static void testCalloutFailure_partialSuccessContinuesOtherIsins() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        // The matched ISIN still updates even though the failing ISIN errored in the same run
        FundManager__c updated = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_MATCHED];
        System.assertEquals(3, updated.CityWireRating__c);

        List<OperationLog__c> errorLogs = [SELECT Id FROM OperationLog__c WHERE Level__c = 'ERROR' AND Operation__c = 'CityWireFundLookup'];
        System.assertEquals(1, errorLogs.size());
    }

    @isTest
    static void testEmptyManagersArray_logsWarnNotError() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        List<OperationLog__c> logs = [SELECT Level__c FROM OperationLog__c WHERE Operation__c = 'CityWireFundLookup' AND SourceObject__c = 'Share_Class__c' AND Level__c = 'WARN'];
        System.assert(!logs.isEmpty(), 'An empty Managers array must be logged as WARN, not ERROR');
    }

    @isTest
    static void testDryRun_skipsUpdate() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = true;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        FundManager__c untouched = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_MATCHED];
        System.assertEquals(null, untouched.CityWireRating__c, 'Dry run must never perform the DML update');
    }

    @isTest
    static void testUnchangedRating_isNotReUpdated() {
        FundManager__c fm = [SELECT Id FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_MATCHED];
        fm.CityWireRating__c = 3;
        fm.CityWireURL__c = 'https://citywire.com/12345.png';
        fm.CityWireDate__c = Date.valueOf(recentDate(10));
        update fm;

        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        List<OperationLog__c> noChangeLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireNoChangeDetected' AND SourceRecordId__c = :fm.Id];
        System.assertEquals(1, noChangeLogs.size(), 'A manager whose rating/URL/date has not changed should be logged as no-change');

        List<OperationLog__c> updateLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireFundManagerUpdated' AND SourceRecordId__c = :fm.Id];
        System.assertEquals(0, updateLogs.size(), 'A manager whose rating/URL/date has not changed should not be re-updated');
    }

    @isTest
    static void testUpdateFailure_logsErrorAndDoesNotBlockOtherRecords() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        // The record that fails DML (rating out of range) stays untouched...
        FundManager__c failedRecord = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_UPDATE_FAILURE];
        System.assertEquals(null, failedRecord.CityWireRating__c, 'A failed DML update must not leave a partial value on the record');

        // ...while the unrelated matched record still updates in the same run (partial success, per-record allOrNone=false).
        FundManager__c updated = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_MATCHED];
        System.assertEquals(3, updated.CityWireRating__c);

        List<OperationLog__c> errorLogs = [SELECT Message__c FROM OperationLog__c WHERE Operation__c = 'CityWireFundManagerUpdateFailed'];
        System.assertEquals(1, errorLogs.size());

        List<OperationLog__c> summaryLogs = [SELECT Context__c FROM OperationLog__c WHERE Operation__c = 'CityWireRatingsSummary' ORDER BY CreatedDate DESC LIMIT 1];
        Map<String, Object> context = (Map<String, Object>) JSON.deserializeUntyped(summaryLogs[0].Context__c);
        System.assertEquals(1, (Integer) context.get('updateFailed'), 'The summary context should account for the failed update');
    }

    @isTest
    static void testScheduler_enqueuesBatchWhenNotRunning() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        ((Schedulable) new CityWireUpdateBatch()).execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'CityWireUpdateBatch' AND JobType = 'BatchApex'];
        System.assertEquals(1, jobs.size());
    }

    @isTest
    static void testScheduler_skipsWhenAlreadyRunning() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        ((Schedulable) new CityWireUpdateBatch()).execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'CityWireUpdateBatch' AND JobType = 'BatchApex'];
        System.assertEquals(1, jobs.size(), 'The scheduler must not enqueue a second batch while one is already running');
    }
}