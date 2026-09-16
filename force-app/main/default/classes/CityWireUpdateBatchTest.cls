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
    private static final String ISIN_MISSING_MANAGER_ID = 'FR0000000012';
    private static final String ISIN_NO_CHANGE = 'FR0000000013';

    private static final Decimal CITYWIRE_ID_MATCHED = 12345;
    private static final Decimal CITYWIRE_ID_UNMATCHED = 55555;
    private static final Decimal CITYWIRE_ID_CONFLICT = 99999;
    private static final Decimal CITYWIRE_ID_UPDATE_FAILURE = 77777;
    private static final Decimal CITYWIRE_ID_NULL_TOLERANT = 11111;
    private static final Decimal CITYWIRE_ID_STALE_NO_CONFLICT = 22222;
    private static final Decimal CITYWIRE_ID_NO_CHANGE = 44444;

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

    // Simulates an API response entry with no manager ID at all — a genuinely malformed entry, not just missing data.
    private static String managerBodyWithMissingId(String ratingDate) {
        return '{"SummaryDisclaimer":"d","RatingDate":"' + ratingDate + '","Managers":[' +
            '{"ID":null,"FirstName":"John","LastName":"Doe","Rating":{"RatingValue":5}}' +
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
            .withBody(ISIN_STALE_NO_CONFLICT_B, managerBodyWithNullRating(CITYWIRE_ID_STALE_NO_CONFLICT, '0001-01-01'))
            .withBody(ISIN_MISSING_MANAGER_ID, managerBodyWithMissingId(recentDate(10)))
            // Rating/URL/date already match the pre-set FundManager__c below — nothing should change.
            .withBody(ISIN_NO_CHANGE, managerBody(CITYWIRE_ID_NO_CHANGE, 6, recentDate(10), 'https://citywire.com/44444.png'));
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
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC MissingManagerId', ISIN_MISSING_MANAGER_ID));
        shareClasses.add(buildMainActiveShareClass(product.Id, 'SC NoChange', ISIN_NO_CHANGE));

        Share_Class__c notMain = buildMainActiveShareClass(product.Id, 'SC NotMain', 'FR0000000099');
        notMain.IsMainShareClass__c = 'False';
        shareClasses.add(notMain);

        insert shareClasses;

        insert new FundManager__c(Name = 'Matched Manager', EmpId__c = 1, CityWireId__c = CITYWIRE_ID_MATCHED);
        insert new FundManager__c(Name = 'Conflict Manager', EmpId__c = 2, CityWireId__c = CITYWIRE_ID_CONFLICT);
        insert new FundManager__c(Name = 'Update Failure Manager', EmpId__c = 3, CityWireId__c = CITYWIRE_ID_UPDATE_FAILURE);
        insert new FundManager__c(Name = 'Null Tolerant Manager', EmpId__c = 4, CityWireId__c = CITYWIRE_ID_NULL_TOLERANT);
        insert new FundManager__c(Name = 'Stale No Conflict Manager', EmpId__c = 5, CityWireId__c = CITYWIRE_ID_STALE_NO_CONFLICT);
        // Pre-set to exactly match what defaultMock() returns for ISIN_NO_CHANGE, so the batch sees nothing to update.
        insert new FundManager__c(Name = 'No Change Manager', EmpId__c = 6, CityWireId__c = CITYWIRE_ID_NO_CHANGE, CityWireRating__c = 6, CityWireURL__c = 'https://citywire.com/44444.png', CityWireDate__c = Date.valueOf(recentDate(10)));
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

    // Returns the Context__c (parsed) of the first OperationLog__c row for the given operation whose context cityWireId matches, or null.
    // Message__c/Context__c are LongTextArea fields and can't be filtered in SOQL, so matching happens in Apex instead.
    private static Map<String, Object> findContextForCityWireId(String operation, Decimal cityWireId) {
        for (OperationLog__c logRecord : [SELECT Context__c FROM OperationLog__c WHERE Operation__c = :operation]) {
            Map<String, Object> context = (Map<String, Object>) JSON.deserializeUntyped(logRecord.Context__c);
            if (context.get('cityWireId') != null && Decimal.valueOf(String.valueOf(context.get('cityWireId'))) == cityWireId) {
                return context;
            }
        }
        return null;
    }

    // One shared batch run exercises every outcome the fixture set is built for — happy path, unmatched, conflict,
    // null-tolerant merge, missing ID, stale rating date, callout failure, empty response, update failure and no-change —
    // since they all already coexist in the same @TestSetup data and would otherwise just re-run the identical batch.
    @isTest
    static void testBatchOutcomeScenarios() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        Database.executeBatch(new CityWireUpdateBatch(), 20);
        Test.stopTest();

        // Happy path: a clean match gets its rating/URL/date updated.
        FundManager__c updated = [SELECT CityWireRating__c, CityWireURL__c, CityWireDate__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_MATCHED];
        System.assertEquals(3, updated.CityWireRating__c);
        System.assertEquals('https://citywire.com/12345.png', updated.CityWireURL__c);
        System.assertEquals(Date.valueOf(recentDate(10)), updated.CityWireDate__c);

        // Unmatched: a Citywire ID with no FundManager__c is logged and never creates a record.
        Integer fundManagerCount = [SELECT COUNT() FROM FundManager__c];
        System.assertEquals(6, fundManagerCount, 'No new FundManager__c should ever be created for an unmatched Citywire ID');
        List<OperationLog__c> unmatchedLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireUnmatchedManager'];
        System.assertEquals(1, unmatchedLogs.size());

        // Conflict: two non-null, disagreeing ratings for the same manager are excluded from update and logged twice
        // (once at merge-time detection, once at finish-time reporting).
        FundManager__c conflictManager = [SELECT Id, CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_CONFLICT];
        System.assertEquals(null, conflictManager.CityWireRating__c, 'A manager with two different non-null ratings must not be updated');
        List<OperationLog__c> conflictLogs = [SELECT Context__c, MethodName__c FROM OperationLog__c WHERE Operation__c = 'CityWireConflictDetected'];
        System.assertEquals(2, conflictLogs.size(), 'A conflict should be logged both at merge-time detection and at finish-time reporting');
        Boolean hasMergeTimeConflictLog = false;
        Boolean hasFinishTimeConflictLog = false;
        for (OperationLog__c logRecord : conflictLogs) {
            Map<String, Object> context = (Map<String, Object>) JSON.deserializeUntyped(logRecord.Context__c);
            System.assert(String.valueOf(context.get('conflictDetail')).contains('Rating'), 'The conflict detail should explain what actually differed');
            if (logRecord.MethodName__c == 'execute(BatchableContext)') {
                hasMergeTimeConflictLog = true;
                System.assert(context.containsKey('managerApiResponse'), 'The merge-time conflict log should carry the raw Citywire API response');
            }
            if (logRecord.MethodName__c == 'finish') hasFinishTimeConflictLog = true;
        }
        System.assert(hasMergeTimeConflictLog, 'The conflict should be logged the moment it is detected during merge');
        System.assert(hasFinishTimeConflictLog, 'The final conflicted outcome should also be logged in finish()');

        // Null-tolerant merge: a null rating from one ISIN never overwrites or conflicts with a real rating from another,
        // and the two occurrences are logged as "recorded" then "merged".
        FundManager__c nullTolerantManager = [SELECT Id, CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_NULL_TOLERANT];
        System.assertEquals(7, nullTolerantManager.CityWireRating__c, 'A null rating must not overwrite or conflict with a real rating');
        List<OperationLog__c> nullTolerantConflictLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireConflictDetected' AND SourceRecordId__c = :nullTolerantManager.Id];
        System.assertEquals(0, nullTolerantConflictLogs.size(), 'A missing value must never be treated as a conflict');
        Map<String, Object> recordedContext = findContextForCityWireId('CityWireManagerRecorded', CITYWIRE_ID_NULL_TOLERANT);
        System.assertNotEquals(null, recordedContext, 'The first data point for a manager should be logged as recorded');
        System.assert(String.isNotBlank((String) recordedContext.get('managerApiResponse')), 'The recorded log should carry the raw Citywire API response');
        Map<String, Object> mergedContext = findContextForCityWireId('CityWireManagerMerged', CITYWIRE_ID_NULL_TOLERANT);
        System.assertNotEquals(null, mergedContext, 'A subsequent non-conflicting data point should be logged as merged');
        System.assert(String.isNotBlank((String) mergedContext.get('managerApiResponse')), 'The merged log should carry the raw Citywire API response');

        // Missing manager ID: a genuinely malformed API entry is logged, not silently dropped.
        List<OperationLog__c> missingIdLogs = [SELECT Level__c, Context__c FROM OperationLog__c WHERE Operation__c = 'CityWireManagerMissingId'];
        System.assertEquals(1, missingIdLogs.size(), 'A manager entry with no ID must still be logged, not silently dropped');
        System.assertEquals('WARN', missingIdLogs[0].Level__c);
        Map<String, Object> missingIdContext = (Map<String, Object>) JSON.deserializeUntyped(missingIdLogs[0].Context__c);
        System.assert(String.isNotBlank((String) missingIdContext.get('managerApiResponse')), 'The missing-ID log should carry the raw Citywire API response');

        // Stale rating date: a garbage/ancient date is ignored entirely rather than manufacturing a false conflict.
        FundManager__c staleManager = [SELECT Id, CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_STALE_NO_CONFLICT];
        System.assertEquals(2, staleManager.CityWireRating__c, 'The stale entry must be ignored entirely, leaving only the good rating');
        List<OperationLog__c> staleConflictLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireConflictDetected' AND SourceRecordId__c = :staleManager.Id];
        System.assertEquals(0, staleConflictLogs.size(), 'A stale/garbage rating date must never manufacture a false conflict');
        List<OperationLog__c> staleLogs = [SELECT Level__c FROM OperationLog__c WHERE Operation__c = 'CityWireStaleRatingDate'];
        System.assertEquals(1, staleLogs.size(), 'The ignored stale entry should still be logged for visibility');
        System.assertEquals('WARN', staleLogs[0].Level__c);

        // Callout failure: one failing ISIN doesn't block the others in the same run (partial success).
        List<OperationLog__c> calloutErrorLogs = [SELECT Id FROM OperationLog__c WHERE Level__c = 'ERROR' AND Operation__c = 'CityWireFundLookup'];
        System.assertEquals(1, calloutErrorLogs.size());

        // Empty Managers array: logged as WARN, not ERROR.
        List<OperationLog__c> emptyManagersLogs = [SELECT Level__c FROM OperationLog__c WHERE Operation__c = 'CityWireFundLookup' AND SourceObject__c = 'Share_Class__c' AND Level__c = 'WARN'];
        System.assert(!emptyManagersLogs.isEmpty(), 'An empty Managers array must be logged as WARN, not ERROR');

        // Update failure: a DML error (rating out of range) doesn't block other records, and shows up in the run summary.
        FundManager__c updateFailedManager = [SELECT CityWireRating__c FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_UPDATE_FAILURE];
        System.assertEquals(null, updateFailedManager.CityWireRating__c, 'A failed DML update must not leave a partial value on the record');
        List<OperationLog__c> updateFailedLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireFundManagerUpdateFailed'];
        System.assertEquals(1, updateFailedLogs.size());

        // No change: a manager whose rating/URL/date already match is logged as no-change and never re-updated.
        FundManager__c noChangeManager = [SELECT Id FROM FundManager__c WHERE CityWireId__c = :CITYWIRE_ID_NO_CHANGE];
        List<OperationLog__c> noChangeLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireNoChangeDetected' AND SourceRecordId__c = :noChangeManager.Id];
        System.assertEquals(1, noChangeLogs.size(), 'A manager whose rating/URL/date has not changed should be logged as no-change');
        List<OperationLog__c> noChangeUpdateLogs = [SELECT Id FROM OperationLog__c WHERE Operation__c = 'CityWireFundManagerUpdated' AND SourceRecordId__c = :noChangeManager.Id];
        System.assertEquals(0, noChangeUpdateLogs.size(), 'A manager whose rating/URL/date has not changed should not be re-updated');

        // Run summary: the failed update is reflected in the aggregate context.
        List<OperationLog__c> summaryLogs = [SELECT Context__c FROM OperationLog__c WHERE Operation__c = 'CityWireRatingsSummary' ORDER BY CreatedDate DESC LIMIT 1];
        Map<String, Object> summaryContext = (Map<String, Object>) JSON.deserializeUntyped(summaryLogs[0].Context__c);
        System.assertEquals(1, (Integer) summaryContext.get('updateFailed'), 'The summary context should account for the failed update');
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
    static void testSchedulerGuard_enqueuesOnlyWhenNotAlreadyRunning() {
        Test.setMock(HttpCalloutMock.class, defaultMock());
        CityWireUpdateBatch.dryRunOverride = false;

        Test.startTest();
        // First fire: nothing running yet, so it should enqueue a batch.
        ((Schedulable) new CityWireUpdateBatch()).execute(null);
        List<AsyncApexJob> jobsAfterFirstFire = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'CityWireUpdateBatch' AND JobType = 'BatchApex'];
        System.assertEquals(1, jobsAfterFirstFire.size(), 'The first scheduled fire should enqueue a batch when none is running');

        // Second fire while the first is still queued: must be skipped, not enqueue a second batch.
        ((Schedulable) new CityWireUpdateBatch()).execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobsAfterSecondFire = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'CityWireUpdateBatch' AND JobType = 'BatchApex'];
        System.assertEquals(1, jobsAfterSecondFire.size(), 'The scheduler must not enqueue a second batch while one is already running');
    }
}