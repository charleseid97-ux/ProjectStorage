global without sharing class ScheduleSspBatch

implements Database.Batchable<String>, Database.Stateful {
private Integer fromLine;
private Integer toLine;
    // Constructeur par défaut du batch
global ScheduleSspBatch() {

}
// Constructeur batch SSP
global ScheduleSspBatch(
    Integer fromLine,
    Integer toLine
) {

    this.fromLine = fromLine;
    this.toLine = toLine;
}

    private static final String RESOURCE_NAME =
        'ScheduleEventsToBatch_SSP';

    @TestVisible
    private static String testCsvContent;

    private Map<String, Integer> headerIndex;

    // Conserve les erreurs du batch
    private List<String> collectedErrors =
        new List<String>();


    // Charge le CSV SSP
    global Iterable<String> start(
        Database.BatchableContext bc
    ) {

        ScheduleEventsCsvHelper.ParsedCsv parsed;

        if (Test.isRunningTest()
            && testCsvContent != null) {

            parsed =
                ScheduleEventsCsvHelper.loadFromCsvString(
                    testCsvContent
                );

        } else {

            parsed =
                ScheduleEventsCsvHelper.loadFromStaticResource(
                    RESOURCE_NAME
                );
        }

        headerIndex = parsed.headerIndex;

        List<String> allRecords =
    ScheduleEventsCsvHelper.getDataRecords(
        parsed
    );

List<String> filtered =
    new List<String>();


for (Integer i = 0;
    i < allRecords.size();
    i++) {

    Boolean afterStart =
        (fromLine == null || i >= fromLine);

    Boolean beforeEnd =
        (toLine == null || i <= toLine);

    if (afterStart && beforeEnd) {

        filtered.add(
            allRecords[i]
        );
    }
}

return filtered;
    }


    // Traite les lignes SSP
    global void execute(
        Database.BatchableContext bc,
        List<String> scope
    ) {

        if (scope == null || scope.isEmpty()) {
            return;
        }

        List<ScheduleSspCsvHelper.RowData> rows =
            new List<ScheduleSspCsvHelper.RowData>();

        Set<String> eventScheduleIds =
            new Set<String>();

        Set<String> speakerEmails =
            new Set<String>();

        Set<String> strategyCodes =
            new Set<String>();


        // Parse les lignes
        for (String line : scope) {

            try {

                ScheduleSspCsvHelper.RowData row =
                    ScheduleSspCsvHelper.buildRow(
                        headerIndex,
                        line
                    );

                if (row == null) {
                    continue;
                }

                rows.add(row);

                if (!String.isBlank(row.eventScheduleId)) {
                    eventScheduleIds.add(
                        row.eventScheduleId
                    );
                }

                if (!String.isBlank(row.speakerEmail)) {
                    speakerEmails.add(
                        row.speakerEmail.toLowerCase()
                    );
                }

                if (!String.isBlank(row.strategyCode)) {
                    strategyCodes.add(
                        row.strategyCode
                    );
                }

            } catch (Exception e) {

                collectedErrors.add(
                    'CSV parse error : ' +
                    e.getMessage()
                );
            }
        }


        // Charge les Events
        Map<String, Event__c> eventsByScheduleId =
            new Map<String, Event__c>();

        for (Event__c ev : [
            SELECT Id, ScheduleID__c
            FROM Event__c
            WHERE ScheduleID__c IN :eventScheduleIds
        ]) {

            eventsByScheduleId.put(
                ev.ScheduleID__c,
                ev
            );
        }


        // Charge les Contacts
        Map<String, Contact> contactsByEmail =
            new Map<String, Contact>();

        for (Contact c : [
            SELECT Id, Email
            FROM Contact
            WHERE Email IN :speakerEmails
        ]) {

            if (!String.isBlank(c.Email)) {

                contactsByEmail.put(
                    c.Email.trim().toLowerCase(),
                    c
                );
            }
        }


        // Charge les Strategies
        Map<String, Id> strategyByCode =
            new Map<String, Id>();

        for (Strategy__c fs : [
            SELECT Id, Code__c
            FROM Strategy__c
            WHERE Code__c IN :strategyCodes
        ]) {

            strategyByCode.put(
                fs.Code__c,
                fs.Id
            );
        }

        List<sessionSpeakerProduct__c> ssps =
            new List<sessionSpeakerProduct__c>();


        // Build les SSP
        for (ScheduleSspCsvHelper.RowData row : rows) {

            try {

                if (String.isBlank(row.scheduleId)) {

                    collectedErrors.add(
                        'scheduleId : UNKNOWN Error : missing TECH_ID'
                    );

                    continue;
                }

                Event__c ev =
                    eventsByScheduleId.get(
                        row.eventScheduleId
                    );

                if (ev == null) {

                    collectedErrors.add(
                        'scheduleId : ' +
                        row.scheduleId +
                        ' Error : Event not found'
                    );

                    continue;
                }

                Contact speaker =
                    contactsByEmail.get(
                        row.speakerEmail != null
                            ? row.speakerEmail.toLowerCase()
                            : null
                    );

                if (speaker == null) {

                    collectedErrors.add(
                        'scheduleId : ' +
                        row.scheduleId +
                        ' Error : Contact not found'
                    );

                    continue;
                }

                Id strategyId =
                    strategyByCode.get(
                        row.strategyCode
                    );

                if (strategyId == null) {

                    collectedErrors.add(
                        'scheduleId : ' +
                        row.scheduleId +
                        ' Error : Strategy not found'
                    );

                    continue;
                }

                sessionSpeakerProduct__c ssp =
                    ScheduleSspCsvHelper.buildSsp(
                        row,
                        ev.Id,
                        speaker.Id,
                        strategyId
                    );

                ssps.add(ssp);

            } catch (Exception e) {

                collectedErrors.add(
                    'scheduleId : ' +
                    row.scheduleId +
                    ' Error : ' +
                    e.getMessage()
                );
            }
        }


        // Upsert SSP
        if (!ssps.isEmpty()) {

            Database.UpsertResult[] results =
                Database.upsert(
                    ssps,
                    sessionSpeakerProduct__c.Fields.scheduleId__c,
                    false
                );


            // Collecte erreurs DML
            for (Integer i = 0;
                i < results.size();
                i++) {

                if (!results[i].isSuccess()) {

                    for (Database.Error err :
                        results[i].getErrors()) {

                        collectedErrors.add(
                            'scheduleId : ' +
                            ssps[i].scheduleId__c +
                            ' Error : ' +
                            err.getMessage()
                        );
                    }
                }
            }
        }
    }


    // Résumé final batch
    global void finish(
        Database.BatchableContext bc
    ) {

        System.debug(
            '=== SSP BATCH FINISHED ==='
        );

        if (collectedErrors.isEmpty()) {

            System.debug(
                'NO ERRORS FOUND'
            );

            return;
        }

        System.debug(
            '=== ERROR LIST START ==='
        );

        for (String err : collectedErrors) {

            System.debug(err);
        }

        System.debug(
            '=== ERROR LIST END ==='
        );
    }
}
