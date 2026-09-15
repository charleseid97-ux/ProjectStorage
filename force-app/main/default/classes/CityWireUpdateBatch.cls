/** ──────────────────────────────────────
 * @description Pulls Citywire fund manager ratings for every active main Share_Class__c ISIN, consolidates results by Citywire manager ID, and refreshes matching FundManager__c records.
 *              Combines the Schedulable entry point and the Batchable work in a single class (per team convention for this integration).
 * @author Charles EID
 * @testClass CityWireUpdateBatchTest
 * @coverage 96%   [15-09-26]
────────────────────────────────────── */
public without sharing class CityWireUpdateBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    private static final String APEX_CLASS_NAME = 'CityWireUpdateBatch';
    private static final String METHOD_SCHEDULABLE_EXECUTE = 'execute(SchedulableContext)';
    private static final String METHOD_BATCHABLE_EXECUTE = 'execute(BatchableContext)';
    private static final String METHOD_FINISH = 'finish';

    private static final Integer DEFAULT_BATCH_SIZE = 20;
    private static final Integer DEFAULT_MAX_RATING_AGE_MONTHS = 3;

    private static final String OPERATION_LOOKUP = 'CityWireFundLookup';
    private static final String OPERATION_STALE_RATING = 'CityWireStaleRatingDate';
    private static final String OPERATION_CONFLICT = 'CityWireConflictDetected';
    private static final String OPERATION_NOCHANGE = 'CityWireNoChangeDetected';
    private static final String OPERATION_UNMATCHED = 'CityWireUnmatchedManager';
    private static final String OPERATION_UPDATED = 'CityWireFundManagerUpdated';
    private static final String OPERATION_UPDATE_FAILED = 'CityWireFundManagerUpdateFailed';
    private static final String OPERATION_SUMMARY = 'CityWireRatingsSummary';
    private static final String OPERATION_SCHEDULE_SKIP = 'CityWireScheduleSkip';

    // Keys used in the finish() outcome map (cityWireIdsByOutcome) — every managed Citywire ID lands in exactly one of these,
    // so the buckets always sum to managerResults.size(), independent of the ISIN-level processed/failed counts.
    private static final String OUTCOME_UPDATED = 'Updated';
    private static final String OUTCOME_WOULD_UPDATE = 'WouldUpdate';
    private static final String OUTCOME_UPDATE_FAILED = 'UpdateFailed';
    private static final String OUTCOME_UNMATCHED = 'Unmatched';
    private static final String OUTCOME_CONFLICTED = 'Conflicted';
    private static final String OUTCOME_NO_CHANGE = 'NoChange';

    private Map<Decimal, ManagerAggregate> managerResults = new Map<Decimal, ManagerAggregate>();
    private Integer processedCount = 0;
    private Integer failedCount = 0;

    // Test-only seam: the deployed CityWireSettings__mdt.Default record ships with DryRun__c = true as a deploy-time safety default, so tests that need to assert real DML force it off here.
    @TestVisible
    private static Boolean dryRunOverride = null;

    private class ManagerAggregate {
        Decimal rating;
        String url;
        Date ratingDate;
        Boolean hasConflict = false;
        Boolean oldRatingDate = false;
        String conflictDetail;
    }

    // Tracks one FundManager__c update in flight, so the "previous" values are still available for logging once Database.update() returns.
    private class PendingUpdate {
        FundManager__c record;
        Decimal cityWireId;
        Decimal previousRating;
        String previousUrl;
        Date previousRatingDate;
    }

    // ── Schedulable entry point ──────────────────────────────
    public void execute(SchedulableContext sc) {
        if (isRunning()) {
            OperationLogService.logWithContext(OperationLogService.Level.INFO, (Id) null, OPERATION_SCHEDULE_SKIP, 'CityWireUpdateBatch is already running; skipping this scheduled fire.', new Map<String, Object>{ 'alreadyRunning' => true }, APEX_CLASS_NAME, METHOD_SCHEDULABLE_EXECUTE);
            OperationLogService.flush();
            return;
        }

        CityWireSettings__mdt settings = CityWireSettings__mdt.getInstance('Default');
        Integer batchSize = settings != null && settings.BatchSize__c != null ? Integer.valueOf(settings.BatchSize__c) : DEFAULT_BATCH_SIZE;

        Database.executeBatch(new CityWireUpdateBatch(), batchSize);
    }

    private Boolean isRunning() {
        List<AsyncApexJob> jobs = [SELECT Id
                                   FROM AsyncApexJob
                                   WHERE ApexClass.Name = 'CityWireUpdateBatch'
                                   AND JobType = 'BatchApex'
                                   AND Status NOT IN ('Aborted', 'Completed', 'Failed')];
        return !jobs.isEmpty();
    }

    // ── Batchable ─────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        OperationLogService.setCorrelationId('CityWireRatings-' + Datetime.now().getTime());

        String query = 'SELECT Id, ISIN__c FROM Share_Class__c' +
                       ' WHERE TechIsActive__c = true' +
                       ' AND IsMainShareClass__c = \'True\'' +
                       ' AND ISIN__c != null';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Share_Class__c> scope) {
        CityWireSettings__mdt settings = CityWireSettings__mdt.getInstance('Default');
        Integer maxRatingAgeMonths = settings != null && settings.MaxRatingAgeMonths__c != null ? Integer.valueOf(settings.MaxRatingAgeMonths__c) : DEFAULT_MAX_RATING_AGE_MONTHS;

        for (Share_Class__c shareClass : scope) {
            processedCount++;

            try {
                CityWireCalloutService.CityWireFundResponseWrapper response = CityWireCalloutService.getFund(shareClass.ISIN__c);

                if (response.Managers == null || response.Managers.isEmpty()) {
                    OperationLogService.logWithContext(OperationLogService.Level.WARN, shareClass.Id, OPERATION_LOOKUP, 'Citywire returned no manager data for ISIN ' + shareClass.ISIN__c + '.', new Map<String, Object>{ 'isin' => shareClass.ISIN__c, 'shareClassId' => shareClass.Id, 'summaryDisclaimer' => response.SummaryDisclaimer, 'fundRatingDate' => response.RatingDate }, APEX_CLASS_NAME, METHOD_BATCHABLE_EXECUTE);
                }
                else {
                    mergeManagers(shareClass, response.Managers, response.RatingDate, maxRatingAgeMonths);
                }
            }
            catch (CityWireCalloutService.CityWireCalloutException ex) {
                failedCount++;
                OperationLogService.logWithContext(OperationLogService.Level.ERROR, shareClass.Id, OPERATION_LOOKUP, 'Citywire callout failed for ISIN ' + shareClass.ISIN__c + '.', new Map<String, Object>{ 'isin' => shareClass.ISIN__c, 'shareClassId' => shareClass.Id, 'exceptionMessage' => ex.getMessage() }, ex, APEX_CLASS_NAME, METHOD_BATCHABLE_EXECUTE);
            }
        }

        OperationLogService.flush();
    }

    public void finish(Database.BatchableContext bc) {
        CityWireSettings__mdt settings = CityWireSettings__mdt.getInstance('Default');
        Boolean dryRun = dryRunOverride != null ? dryRunOverride : (settings != null && settings.DryRun__c == true);

        Set<Decimal> allManagerIds = managerResults.keySet();
        Map<Decimal, FundManager__c> fundManagerByCityWireId = new Map<Decimal, FundManager__c>();
        for (FundManager__c fm : [SELECT Id, Name, CityWireId__c, CityWireRating__c, CityWireURL__c, CityWireDate__c
                                  FROM FundManager__c
                                  WHERE CityWireId__c IN :allManagerIds]) {
            fundManagerByCityWireId.put(fm.CityWireId__c, fm);
        }

        Map<String, List<String>> cityWireIdsByOutcome = new Map<String, List<String>>();
        List<PendingUpdate> updateCandidates = new List<PendingUpdate>();

        for (Decimal cityWireId : managerResults.keySet()) {
            ManagerAggregate agg = managerResults.get(cityWireId);
            FundManager__c match = fundManagerByCityWireId.get(cityWireId);

            if (match == null) {
                recordOutcome(cityWireIdsByOutcome, OUTCOME_UNMATCHED, cityWireId);
                OperationLogService.logWithContext(OperationLogService.Level.WARN, (String) null, 'FundManager__c', OPERATION_UNMATCHED, 'No FundManager__c found for Citywire manager ID ' + cityWireId + '.', new Map<String, Object>{ 'cityWireId' => cityWireId, 'rating' => agg.rating, 'url' => agg.url, 'ratingDate' => agg.ratingDate, 'hadOldRatingDateEntry' => agg.oldRatingDate }, null, APEX_CLASS_NAME, METHOD_FINISH);
                continue;
            }
            else if (agg.hasConflict) {
                recordOutcome(cityWireIdsByOutcome, OUTCOME_CONFLICTED, cityWireId);
                OperationLogService.logWithContext(OperationLogService.Level.WARN, match.Id, OPERATION_CONFLICT, 'Conflicting Citywire ratings detected for manager ID ' + cityWireId + '; excluded from update.', new Map<String, Object>{ 'cityWireId' => cityWireId, 'fundManagerId' => match.Id, 'fundManagerName' => match.Name, 'conflictDetail' => agg.conflictDetail, 'currentDbRating' => match.CityWireRating__c, 'currentDbUrl' => match.CityWireURL__c, 'currentDbRatingDate' => match.CityWireDate__c, 'hadOldRatingDateEntry' => agg.oldRatingDate }, APEX_CLASS_NAME, METHOD_FINISH);
                continue;
            }
            else if (!(match.CityWireRating__c != agg.rating || match.CityWireURL__c != agg.url || match.CityWireDate__c != agg.ratingDate)) {
                recordOutcome(cityWireIdsByOutcome, OUTCOME_NO_CHANGE, cityWireId);
                OperationLogService.logWithContext(OperationLogService.Level.INFO, match.Id, OPERATION_NOCHANGE, 'The matched fund manager doesn\'t need updating.', new Map<String, Object>{ 'cityWireId' => cityWireId, 'fundManagerId' => match.Id, 'rating' => agg.rating, 'url' => agg.url, 'ratingDate' => agg.ratingDate }, APEX_CLASS_NAME, METHOD_FINISH);
                continue;
            }

            PendingUpdate pending = new PendingUpdate();
            pending.cityWireId = cityWireId;
            pending.previousRating = match.CityWireRating__c;
            pending.previousUrl = match.CityWireURL__c;
            pending.previousRatingDate = match.CityWireDate__c;

            match.CityWireRating__c = agg.rating;
            match.CityWireURL__c = agg.url;
            match.CityWireDate__c = agg.ratingDate;
            pending.record = match;
            updateCandidates.add(pending);
        }

        if (dryRun) {
            for (PendingUpdate pending : updateCandidates) {
                recordOutcome(cityWireIdsByOutcome, OUTCOME_WOULD_UPDATE, pending.cityWireId);
            }
        }
        else if (!updateCandidates.isEmpty()) {
            List<FundManager__c> recordsToUpdate = new List<FundManager__c>();
            for (PendingUpdate pending : updateCandidates) {
                recordsToUpdate.add(pending.record);
            }

            List<Database.SaveResult> saveResults = Database.update(recordsToUpdate, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                PendingUpdate pending = updateCandidates[i];
                FundManager__c record = pending.record;

                if (saveResults[i].isSuccess()) {
                    recordOutcome(cityWireIdsByOutcome, OUTCOME_UPDATED, pending.cityWireId);
                    OperationLogService.logWithContext(OperationLogService.Level.INFO, record.Id, OPERATION_UPDATED, 'FundManager__c updated with Citywire rating ' + record.CityWireRating__c + '.', new Map<String, Object>{ 'cityWireId' => pending.cityWireId, 'fundManagerId' => record.Id, 'fundManagerName' => record.Name, 'previousRating' => pending.previousRating, 'newRating' => record.CityWireRating__c, 'previousUrl' => pending.previousUrl, 'newUrl' => record.CityWireURL__c, 'previousRatingDate' => pending.previousRatingDate, 'newRatingDate' => record.CityWireDate__c }, APEX_CLASS_NAME, METHOD_FINISH);
                }
                else {
                    recordOutcome(cityWireIdsByOutcome, OUTCOME_UPDATE_FAILED, pending.cityWireId);
                    List<String> errorMessages = new List<String>();
                    for (Database.Error dmlError : saveResults[i].getErrors()) {
                        errorMessages.add(dmlError.getStatusCode() + ': ' + dmlError.getMessage());
                    }
                    OperationLogService.logWithContext(OperationLogService.Level.ERROR, record.Id, OPERATION_UPDATE_FAILED, 'FundManager__c update failed for Citywire manager ID ' + pending.cityWireId + ': ' + String.join(errorMessages, ' | '), new Map<String, Object>{ 'cityWireId' => pending.cityWireId, 'fundManagerId' => record.Id, 'attemptedRating' => record.CityWireRating__c, 'attemptedUrl' => record.CityWireURL__c, 'attemptedRatingDate' => record.CityWireDate__c, 'errors' => errorMessages }, APEX_CLASS_NAME, METHOD_FINISH);
                }
            }
        }

        logSummary(dryRun, cityWireIdsByOutcome);
        OperationLogService.flush();

        sendAlert(settings, dryRun, countFor(cityWireIdsByOutcome, OUTCOME_UPDATED), countFor(cityWireIdsByOutcome, OUTCOME_UPDATE_FAILED));
    }

    // A Citywire manager ID is only ever added to managerResults with usable (non-stale) data. Ratings older than
    // maxRatingAgeMonths are ignored entirely rather than merged, so a stale null/garbage entry can never look
    // like it "conflicts" with good data recorded earlier in the run, and can never overwrite good data with a blank.
    private void mergeManagers(Share_Class__c shareClass, List<CityWireCalloutService.CityWireManagerWrapper> managers, String fundRatingDateStr, Integer maxRatingAgeMonths) {
        Date ratingDate = parseRatingDate(fundRatingDateStr);
        Boolean isStale = ratingDate == null || ratingDate < Date.today().addMonths(-maxRatingAgeMonths);

        for (CityWireCalloutService.CityWireManagerWrapper manager : managers) {
            if (manager.ID == null) continue;

            if (isStale) {
                ManagerAggregate existingForStale = managerResults.get(manager.ID);
                if (existingForStale != null) existingForStale.oldRatingDate = true;
                OperationLogService.logWithContext(OperationLogService.Level.WARN, (String) null, 'FundManager__c', OPERATION_STALE_RATING, 'Citywire rating date for manager ID ' + manager.ID + ' (ISIN ' + shareClass.ISIN__c + ') is missing or older than ' + maxRatingAgeMonths + ' months; ignored.', new Map<String, Object>{ 'cityWireId' => manager.ID, 'isin' => shareClass.ISIN__c, 'shareClassId' => shareClass.Id, 'ratingDateRaw' => fundRatingDateStr, 'parsedRatingDate' => ratingDate, 'maxAgeMonths' => maxRatingAgeMonths, 'hadExistingData' => existingForStale != null }, null, APEX_CLASS_NAME, METHOD_BATCHABLE_EXECUTE);
                continue;
            }

            Decimal ratingValue = manager.Rating != null ? manager.Rating.RatingValue : null;
            String imageSrc = manager.Rating != null ? manager.Rating.ImageSrc : null;

            ManagerAggregate existing = managerResults.get(manager.ID);
            if (existing == null) {
                ManagerAggregate agg = new ManagerAggregate();
                agg.rating = ratingValue;
                agg.url = imageSrc;
                agg.ratingDate = ratingDate;
                managerResults.put(manager.ID, agg);
                continue;
            }

            // A field only conflicts when both sides actually disagree on real data. A null on either side means
            // "missing information", not a conflict — the non-null value wins. RatingDate is deliberately excluded
            // from conflict detection: two non-stale ISINs legitimately reporting slightly different "as of" dates
            // for the same manager isn't a data problem, it's just when each fund's rating happened to be refreshed.
            List<String> conflicts = new List<String>();
            if (existing.rating != null && ratingValue != null && existing.rating != ratingValue) {
                conflicts.add('Rating: ' + existing.rating + ' vs ' + ratingValue);
            }
            if (existing.url != null && imageSrc != null && existing.url != imageSrc) {
                conflicts.add('URL: ' + existing.url + ' vs ' + imageSrc);
            }

            if (!conflicts.isEmpty()) {
                existing.hasConflict = true;
                existing.conflictDetail = String.join(conflicts, '; ');
            }
            else {
                if (existing.rating == null) existing.rating = ratingValue;
                if (existing.url == null) existing.url = imageSrc;
            }

            // Always keep the freshest rating date seen, independent of whether rating/url conflicted this round.
            if (ratingDate != null && (existing.ratingDate == null || ratingDate > existing.ratingDate)) {
                existing.ratingDate = ratingDate;
            }
        }
    }

    private static Date parseRatingDate(String value) {
        if (String.isBlank(value)) return null;
        try {
            return Date.valueOf(value.length() > 10 ? value.substring(0, 10) : value);
        }
        catch (Exception ex) {
            return null;
        }
    }

    private void recordOutcome(Map<String, List<String>> cityWireIdsByOutcome, String outcome, Decimal cityWireId) {
        if (!cityWireIdsByOutcome.containsKey(outcome)) {
            cityWireIdsByOutcome.put(outcome, new List<String>());
        }
        cityWireIdsByOutcome.get(outcome).add(String.valueOf(cityWireId));
    }

    private static Integer countFor(Map<String, List<String>> cityWireIdsByOutcome, String outcome) {
        List<String> ids = cityWireIdsByOutcome.get(outcome);
        return ids == null ? 0 : ids.size();
    }

    private void logSummary(Boolean dryRun, Map<String, List<String>> cityWireIdsByOutcome) {
        Integer updatedCount = countFor(cityWireIdsByOutcome, OUTCOME_UPDATED);
        Integer wouldUpdateCount = countFor(cityWireIdsByOutcome, OUTCOME_WOULD_UPDATE);
        Integer updateFailedCount = countFor(cityWireIdsByOutcome, OUTCOME_UPDATE_FAILED);
        Integer unmatchedCount = countFor(cityWireIdsByOutcome, OUTCOME_UNMATCHED);
        Integer conflictCount = countFor(cityWireIdsByOutcome, OUTCOME_CONFLICTED);
        Integer noChangeCount = countFor(cityWireIdsByOutcome, OUTCOME_NO_CHANGE);
        Integer totalManagers = managerResults.size();

        Map<String, Object> context = new Map<String, Object>{
            'isinsProcessed' => processedCount,
            'isinsFailed' => failedCount,
            'totalManagersEvaluated' => totalManagers,
            'updated' => updatedCount,
            'wouldUpdate' => wouldUpdateCount,
            'updateFailed' => updateFailedCount,
            'unmatched' => unmatchedCount,
            'conflicts' => conflictCount,
            'unchanged' => noChangeCount,
            'dryRun' => dryRun,
            'cityWireIdsByOutcome' => cityWireIdsByOutcome
        };

        String message = 'Citywire ratings sync finished: ' + processedCount + ' ISINs processed (' + failedCount + ' failed)\n' +
                        totalManagers + ' distinct managers evaluated, of which:\n' +
                        updatedCount + ' updated' + (dryRun ? ' (dry run, ' + wouldUpdateCount + ' would update)' : '') + '\n' +
                        (updateFailedCount > 0 ? updateFailedCount + ' failed to update\n' : '') +
                        noChangeCount + ' unchanged\n' +
                        unmatchedCount + ' unmatched\n' +
                        conflictCount + ' conflicts.';

        OperationLogService.Level level = (failedCount > 0 || updateFailedCount > 0 || dryRun) ? OperationLogService.Level.WARN : OperationLogService.Level.INFO;
        OperationLogService.logWithContext(level, (String) null, null, OPERATION_SUMMARY, message, context, null, APEX_CLASS_NAME, METHOD_FINISH);
    }

    private void sendAlert(CityWireSettings__mdt settings, Boolean dryRun, Integer updatedCount, Integer updateFailedCount) {
        if (settings == null || !settings.EnableAlerts__c) return;

        List<String> queueDeveloperNames = parseLines(settings.AlertQueuesDeveloperName__c);
        List<String> additionalEmailAddresses = parseLines(settings.AlertAdditionalEmailAddresses__c);
        Boolean hasQueueRecipients = !queueDeveloperNames.isEmpty();
        Boolean hasRawRecipients = !additionalEmailAddresses.isEmpty();
        if ((!hasQueueRecipients && !hasRawRecipients) || String.isBlank(settings.AlertEmailTemplateDeveloperName__c)) return;

        Boolean failureRateBreached = processedCount > 0 && settings.FailureAlertThresholdPct__c != null && (Decimal.valueOf(failedCount) / Decimal.valueOf(processedCount) * 100) > settings.FailureAlertThresholdPct__c;
        Boolean zeroUpdatesBreached = !dryRun && updatedCount == 0 && settings.AlertOnZeroUpdates__c == true;
        Boolean updateFailuresOccurred = updateFailedCount > 0;

        if (!failureRateBreached && !zeroUpdatesBreached && !updateFailuresOccurred) return;

        Id summaryLogId = null;
        List<OperationLog__c> logs = [SELECT Id FROM OperationLog__c
                                      WHERE CorrelationId__c = :OperationLogService.getCorrelationId() AND Operation__c = :OPERATION_SUMMARY
                                      ORDER BY CreatedDate DESC LIMIT 1];
        if (!logs.isEmpty()) {
            summaryLogId = logs[0].Id;
        }

        Set<Id> recipientUserIds = new Set<Id>();
        if (hasQueueRecipients) {
            Set<Id> queueIds = QueueMemberService.getQueueId(queueDeveloperNames);
            if (!queueIds.isEmpty()) {
                Map<Id, List<Id>> resolved = QueueMemberService.resolveMembers(queueIds);
                for (List<Id> members : resolved.values()) {
                    recipientUserIds.addAll(members);
                }
            }
        }

        if (recipientUserIds.isEmpty() && !hasRawRecipients) return;

        EmailService.sendTemplateEmail(settings.AlertEmailTemplateDeveloperName__c, summaryLogId, recipientUserIds, additionalEmailAddresses);
    }

    private static List<String> parseLines(String rawLines) {
        List<String> result = new List<String>();
        if (String.isBlank(rawLines)) return result;

        for (String line : rawLines.split('\n')) {
            String trimmed = line.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }
}