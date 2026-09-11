/** ──────────────────────────────────────
 * @description Pulls Citywire fund manager ratings for every active main Share_Class__c ISIN, consolidates results by Citywire manager ID, and refreshes matching FundManager__c records.
 *              Combines the Schedulable entry point and the Batchable work in a single class (per team convention for this integration).
 * @author Charles EID
 * @testClass CityWireUpdateBatchTest
 * @coverage 85%   [10-09-26]
────────────────────────────────────── */
public without sharing class CityWireUpdateBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    private static final Integer DEFAULT_BATCH_SIZE = 20;
    private static final String OPERATION_LOOKUP = 'CityWireFundLookup';
    private static final String OPERATION_CONFLICT = 'CityWireConflictDetected';
    private static final String OPERATION_UNMATCHED = 'CityWireUnmatchedManager';
    private static final String OPERATION_SUMMARY = 'CityWireRatingsSummary';

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
    }

    // ── Schedulable entry point ──────────────────────────────
    public void execute(SchedulableContext sc) {
        if (isRunning()) {
            OperationLogService.info(null, 'CityWireScheduleSkip', 'CityWireUpdateBatch is already running; skipping this scheduled fire.');
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
        for (Share_Class__c shareClass : scope) {
            processedCount++;

            try {
                CityWireCalloutService.CityWireFundResponseWrapper response = CityWireCalloutService.getFund(shareClass.ISIN__c);

                if (response.Managers == null || response.Managers.isEmpty()) {
                    OperationLogService.warn(shareClass.Id, OPERATION_LOOKUP, 'Citywire returned no manager data for ISIN ' + shareClass.ISIN__c + '.');
                } 
                else {
                    mergeManagers(response.Managers);
                }
            } 
            catch (CityWireCalloutService.CityWireCalloutException ex) {
                failedCount++;
                OperationLogService.error(shareClass.Id, OPERATION_LOOKUP, 'Citywire callout failed for ISIN ' + shareClass.ISIN__c + '.', ex);
            }
        }

        OperationLogService.flush();
    }

    private void mergeManagers(List<CityWireCalloutService.CityWireManagerWrapper> managers) {
        for (CityWireCalloutService.CityWireManagerWrapper manager : managers) {
            if (manager.ID == null) {
                continue;
            }

            Decimal ratingValue = manager.Rating != null ? manager.Rating.RatingValue : null;
            String ratingDateStr = manager.Rating != null ? manager.Rating.RatingDate : null;
            Date ratingDate = parseRatingDate(ratingDateStr);

            ManagerAggregate existing = managerResults.get(manager.ID);
            if (existing == null) {
                ManagerAggregate agg = new ManagerAggregate();
                agg.rating = ratingValue;
                agg.url = manager.ImageSrc;
                agg.ratingDate = ratingDate;
                managerResults.put(manager.ID, agg);
            } 
            else if (existing.rating != ratingValue || existing.url != manager.ImageSrc || existing.ratingDate != ratingDate) {
                existing.hasConflict = true;
            }
        }
    }

    private static Date parseRatingDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.length() > 10 ? value.substring(0, 10) : value);
        } 
        catch (Exception ex) {
            return null;
        }
    }

    public void finish(Database.BatchableContext bc) {
        CityWireSettings__mdt settings = CityWireSettings__mdt.getInstance('Default');
        Boolean dryRun = dryRunOverride != null ? dryRunOverride : (settings != null && settings.DryRun__c == true);

        Set<Decimal> allManagerIds = managerResults.keySet();
        Map<Decimal, FundManager__c> fundManagerByCityWireId = new Map<Decimal, FundManager__c>();
        for (FundManager__c fm : [SELECT Id, CityWireId__c, CityWireRating__c, CityWireURL__c, CityWireDate__c
                                  FROM FundManager__c
                                  WHERE CityWireId__c IN :allManagerIds]) {
            fundManagerByCityWireId.put(fm.CityWireId__c, fm);
        }

        List<FundManager__c> updateList = new List<FundManager__c>();
        List<String> unmatchedIds = new List<String>();
        List<String> conflictedIds = new List<String>();
        Integer conflictCount = 0;
        Integer unmatchedCount = 0;

        for (Decimal cityWireId : managerResults.keySet()) {
            ManagerAggregate agg = managerResults.get(cityWireId);
            FundManager__c match = fundManagerByCityWireId.get(cityWireId);

            if (agg.hasConflict) {
                conflictCount++;
                conflictedIds.add(String.valueOf(cityWireId));
                String message = 'Conflicting Citywire ratings detected for manager ID ' + cityWireId + ' across ISINs; excluded from update.';
                if (match != null) {
                    OperationLogService.warn(match.Id, OPERATION_CONFLICT, message);
                } 
                else {
                    logWithoutRecord(OPERATION_CONFLICT, message);
                }
                continue;
            }

            if (match == null) {
                unmatchedCount++;
                unmatchedIds.add(String.valueOf(cityWireId));
                logWithoutRecord(OPERATION_UNMATCHED, 'No FundManager__c found for Citywire manager ID ' + cityWireId + '.');
                continue;
            }

            Boolean changed = match.CityWireRating__c != agg.rating || match.CityWireURL__c != agg.url || match.CityWireDate__c != agg.ratingDate;
            if (!changed) continue;

            match.CityWireRating__c = agg.rating;
            match.CityWireURL__c = agg.url;
            match.CityWireDate__c = agg.ratingDate;
            updateList.add(match);
        }

        if (!dryRun && !updateList.isEmpty()) {
            Database.update(updateList, false);
        }
        Integer updatedCount = dryRun ? 0 : updateList.size();

        logSummary(dryRun, updatedCount, dryRun ? updateList.size() : 0, unmatchedCount, conflictCount, unmatchedIds, conflictedIds);
        OperationLogService.flush();

        sendAlert(settings, dryRun, updatedCount);
    }

    private void logWithoutRecord(String operation, String message) {
        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = OperationLogService.Level.WARN;
        entry.sourceObjectApiName = 'FundManager__c';
        entry.operation = operation;
        entry.message = message;
        entry.apexClass = 'CityWireUpdateBatch';
        entry.methodName = 'finish';
        OperationLogService.log(entry);
    }

    private void logSummary(Boolean dryRun, Integer updatedCount, Integer wouldUpdateCount, Integer unmatchedCount, Integer conflictCount, List<String> unmatchedIds, List<String> conflictedIds) {
        Map<String, Object> context = new Map<String, Object>{
            'processed' => processedCount,
            'updated' => updatedCount,
            'wouldUpdate' => wouldUpdateCount,
            'unmatched' => unmatchedCount,
            'failed' => failedCount,
            'conflicts' => conflictCount,
            'dryRun' => dryRun,
            'unmatchedIds' => unmatchedIds,
            'conflictedIds' => conflictedIds
        };

        OperationLogService.Entry entry = new OperationLogService.Entry();
        entry.level = (failedCount > 0 || dryRun) ? OperationLogService.Level.WARN : OperationLogService.Level.INFO;
        entry.operation = OPERATION_SUMMARY;
        entry.message = 'Citywire ratings sync finished: ' + processedCount + ' processed, ' + updatedCount + ' updated' + (dryRun ? ' (dry run, ' + wouldUpdateCount + ' would update)' : '') + ', ' + unmatchedCount + ' unmatched, ' + failedCount + ' failed, ' + conflictCount + ' conflicts.';
        entry.contextJson = JSON.serialize(context);
        entry.apexClass = 'CityWireUpdateBatch';
        entry.methodName = 'finish';
        OperationLogService.log(entry);
    }

    private void sendAlert(CityWireSettings__mdt settings, Boolean dryRun, Integer updatedCount) {
        if (settings == null || settings.EnableAlerts__c != true) return;

        List<String> queueDeveloperNames = parseQueueDeveloperNames(settings.AlertQueuesDeveloperName__c);
        if (queueDeveloperNames.isEmpty() || String.isBlank(settings.AlertEmailTemplateDeveloperName__c)) return;

        Boolean failureRateBreached = processedCount > 0 && settings.FailureAlertThresholdPct__c != null && (Decimal.valueOf(failedCount) / Decimal.valueOf(processedCount) * 100) > settings.FailureAlertThresholdPct__c;
        Boolean zeroUpdatesBreached = !dryRun && updatedCount == 0 && settings.AlertOnZeroUpdates__c == true;

        if (!failureRateBreached && !zeroUpdatesBreached) return;

        Id summaryLogId = null;
        List<OperationLog__c> logs = [SELECT Id FROM OperationLog__c
                                      WHERE CorrelationId__c = :OperationLogService.getCorrelationId() AND Operation__c = :OPERATION_SUMMARY
                                      ORDER BY CreatedDate DESC LIMIT 1];
        if (!logs.isEmpty()) {
            summaryLogId = logs[0].Id;
        }

        Set<Id> queueIds = QueueMemberService.getQueueId(queueDeveloperNames);
        if (queueIds.isEmpty()) return;

        Map<Id, List<Id>> resolved = QueueMemberService.resolveMembers(queueIds);
        Set<Id> recipientUserIds = new Set<Id>();
        for (List<Id> members : resolved.values()) {
            recipientUserIds.addAll(members);
        }

        EmailService.sendTemplateEmail(settings.AlertEmailTemplateDeveloperName__c, summaryLogId, recipientUserIds);
    }

    private static List<String> parseQueueDeveloperNames(String rawLines) {
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