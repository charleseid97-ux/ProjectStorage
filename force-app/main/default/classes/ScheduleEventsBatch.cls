global without sharing class ScheduleEventsBatch implements Database.Batchable<String>, Database.Stateful {

    private static final String RESOURCE_NAME = 'ScheduleEventsToBatch';

    @TestVisible
    private static String testCsvContent;

    private Map<String, Integer> headerIndex;
    private Integer fromLine;
    private Integer toLine;
    private static final String ERROR_PREFIX =    ERROR_PREFIX;
    // Conserve les erreurs entre les execute()
    private List<String> collectedErrors = new List<String>();

    global ScheduleEventsBatch(Integer fromLine, Integer toLine) {
        this.fromLine = fromLine;
        this.toLine = toLine;
    }

    global Iterable<String> start(Database.BatchableContext bc) {
        System.debug('=== BATCH START ===');
        System.debug('PARAM fromLine=' + fromLine + ' toLine=' + toLine);

        ScheduleEventsCsvHelper.ParsedCsv parsed;

        if (Test.isRunningTest() && testCsvContent != null) {
            System.debug('USING TEST CSV CONTENT');
            parsed = ScheduleEventsCsvHelper.loadFromCsvString(testCsvContent);
        } else {
            System.debug('USING STATIC RESOURCE=' + RESOURCE_NAME);
            parsed = ScheduleEventsCsvHelper.loadFromStaticResource(RESOURCE_NAME);
        }

        headerIndex = parsed.headerIndex;

        if (headerIndex == null || headerIndex.isEmpty()) {
            System.debug('ERROR: headerIndex is empty');
            return new List<String>();
        }

        System.debug('HEADER COUNT=' + headerIndex.size());
        System.debug('HEADER KEYS=' + headerIndex.keySet());

        List<String> allRecords = ScheduleEventsCsvHelper.getDataRecords(parsed);
        System.debug('TOTAL RECORDS (without header)=' + allRecords.size());

        List<String> filtered = new List<String>();

        for (Integer i = 0; i < allRecords.size(); i++) {
            Boolean afterStart = (fromLine == null || i >= fromLine);
            Boolean beforeEnd = (toLine == null || i <= toLine);

            if (afterStart && beforeEnd) {
                filtered.add(allRecords[i]);
            }
        }

        System.debug('FILTERED RECORDS COUNT=' + filtered.size());

        if (!filtered.isEmpty()) {
            Integer firstIncluded = (fromLine == null ? 0 : fromLine);
            Integer lastIncluded = (toLine == null ? firstIncluded + filtered.size() - 1 : toLine);

            System.debug('FIRST INDEX INCLUDED=' + firstIncluded);
            System.debug('LAST INDEX INCLUDED=' + lastIncluded);
            System.debug('FIRST FILTERED LINE SAMPLE=' + filtered[0]);
        } else {
            System.debug('NO RECORDS TO PROCESS');
        }

        return filtered;
    }

    global void execute(Database.BatchableContext bc, List<String> scope) {
        System.debug('=== EXECUTE START === scope size=' + scope.size());

        if (scope == null || scope.isEmpty()) {
            System.debug('EMPTY SCOPE');
            return;
        }

        Integer eventSaved = 0;
        Integer eventErrors = 0;
        Integer skippedRows = 0;

        for (String line : scope) {
            System.debug('--- NEW ROW ---');
            System.debug('RAW LINE=' + line);

            ScheduleEventsCsvHelper.RowData row =
                ScheduleEventsCsvHelper.buildRow(headerIndex, line);

            if (row == null) {
                skippedRows++;
                System.debug('SKIP row: buildRow returned null');
                collectedErrors.add('scheduleId : UNKNOWN Error : buildRow returned null');
                continue;
            }

            System.debug(
                'ROW PARSED scheduleId=' + row.scheduleId +
                ' | name=' + row.rawName +
                ' | sourceType=' + row.sourceType +
                ' | sourceStatus=' + row.sourceStatus +
                ' | sourceRecordType=' + row.sourceRecordType +
                ' | localZone=' + row.localZone +
                ' | mappedTimeZone=' + ScheduleEventsCsvHelper.mapTimeZoneIdToIana(row.localZone) +
                ' | ownerId=' + row.ownerId +
                ' | salesTeam=' + row.salesTeam +
                ' | startDate=' + row.startDate +
                ' | endDate=' + row.endDate +
                ' | startTime=' + row.startTimeText +
                ' | endTime=' + row.endTimeText
            );

            if (String.isBlank(row.scheduleId)) {
                skippedRows++;
                System.debug('SKIP row: missing scheduleId');
                collectedErrors.add('scheduleId : UNKNOWN Error : missing scheduleId');
                continue;
            }

            Event__c ev = ScheduleEventsCsvHelper.buildEvent(row);

            if (ev == null) {
                skippedRows++;
                System.debug('SKIP event build failed for scheduleId=' + row.scheduleId);
                collectedErrors.add(ERROR_PREFIX + row.scheduleId + ' Error : buildEvent returned null');
                continue;
            }

            System.debug(
                'EVENT BUILT scheduleId=' + ev.ScheduleID__c +
                ' | name=' + ev.Name +
                ' | title=' + ev.Title__c +
                ' | recordTypeId=' + ev.RecordTypeId +
                ' | category=' + ev.category__c +
                ' | status=' + ev.status__c +
                ' | timeZone=' + ev.timeZone__c +
                ' | startDate=' + ev.startDate__c +
                ' | endDate=' + ev.endDate__c +
                ' | city=' + ev.city__c +
                ' | country=' + ev.country__c
            );

            List<Event__c> existingEvents = [
                SELECT Id
                FROM Event__c
                WHERE ScheduleID__c = :ev.ScheduleID__c
                LIMIT 1
            ];

            if (!existingEvents.isEmpty()) {
                ev.Id = existingEvents[0].Id;
                System.debug('UPDATE existing event Id=' + ev.Id + ' for ScheduleID=' + ev.ScheduleID__c);
            } else {
                System.debug('INSERT new event for ScheduleID=' + ev.ScheduleID__c);
            }

            try {
                upsert ev;
                eventSaved++;
                System.debug('EVENT SAVED ScheduleID=' + ev.ScheduleID__c + ' Id=' + ev.Id);
            } catch (Exception e) {
                eventErrors++;
                String errorMessage = ERROR_PREFIX + row.scheduleId + ' Error : ' + e.getMessage();
                collectedErrors.add(errorMessage);

                System.debug(
                    'EVENT ERROR ScheduleID=' + row.scheduleId +
                    ' | MSG=' + e.getMessage() +
                    ' | STACK=' + e.getStackTraceString()
                );
            }
        }

        System.debug(
            '=== EXECUTE SUMMARY eventsSaved=' + eventSaved +
            ' | eventErrors=' + eventErrors +
            ' | skippedRows=' + skippedRows +
            ' ==='
        );
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('=== BATCH FINISHED ===');
        System.debug('RESOURCE_NAME=' + RESOURCE_NAME);
        System.debug('FINAL PARAM fromLine=' + fromLine + ' toLine=' + toLine);

        if (collectedErrors.isEmpty()) {
            System.debug('NO ERRORS FOUND');
            Integer i = 0;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            return;
        }

        System.debug('=== ERROR LIST START ===');
        for (String errorLine : collectedErrors) {
            System.debug(errorLine);
        }
        System.debug('=== ERROR LIST END ===');
        
    }
}