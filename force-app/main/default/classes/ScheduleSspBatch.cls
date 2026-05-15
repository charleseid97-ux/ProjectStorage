global without sharing class ScheduleSspBatch
implements Database.Batchable<String>, Database.Stateful {

    private Integer fromLine;
    private Integer toLine;

    private static final String RESOURCE_NAME =
        'ScheduleEventsToBatch_SSP';

    @TestVisible
    private static String testCsvContent;

    private Map<String, Integer> headerIndex;

    // Conserve les erreurs du batch
    private List<String> collectedErrors =
        new List<String>();


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

        // Applique le filtre de lignes si demandé
        for (Integer i = 0;
            i < allRecords.size();
            i++) {

            Boolean afterStart =
                fromLine == null || i >= fromLine;

            Boolean beforeEnd =
                toLine == null || i <= toLine;

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

        Set<String> productNames =
            new Set<String>();

        Set<String> strategyCodes =
            new Set<String>();


        // Parse les lignes et prépare les clés de recherche
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

                    for (String code :
                        row.strategyCode.split(';')) {

                        String cleanCode =
                            ScheduleSspCsvHelper.normalizeStrategyCode(
                                code
                            );

                        if (String.isBlank(cleanCode)) {
                            continue;
                        }

                        // Les codes mappés pointent directement vers Strategy.Code__c
                        if (ScheduleSspCsvHelper.hasStrategyMapping(code)) {

                            strategyCodes.add(
                                cleanCode
                            );

                        } else {

                            productNames.add(
                                cleanCode
                            );
                        }
                    }
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
            SELECT Id, Email, isTopSpeaker__c
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


        // Charge les Products et leurs Strategies
        Map<String, Id> strategyByProductName =
            new Map<String, Id>();

        for (Product__c p : [
            SELECT Id, Name, FundStrategy__c
            FROM Product__c
            WHERE Name IN :productNames
            AND FundStrategy__c != null
        ]) {

            strategyByProductName.put(
                p.Name.trim().toUpperCase(),
                p.FundStrategy__c
            );
        }


        // Charge les Strategies directes par code
        Map<String, Id> strategyByCode =
            new Map<String, Id>();

        for (Strategy__c strategy : [
            SELECT Id, Code__c
            FROM Strategy__c
            WHERE Code__c IN :strategyCodes
        ]) {

            if (!String.isBlank(strategy.Code__c)) {

                strategyByCode.put(
                    strategy.Code__c.trim().toUpperCase(),
                    strategy.Id
                );
            }
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

                // Speaker optionnel métier
                if (row.speakerEmail != null
                    && speaker == null) {

                    collectedErrors.add(
                        'scheduleId : ' +
                        row.scheduleId +
                        ' Error : Contact not found'
                    );

                    continue;
                }

                Map<String, Boolean> rowCodesByMapping =
                    new Map<String, Boolean>();


                // Prépare les codes de la ligne
                if (!String.isBlank(row.strategyCode)) {

                    for (String code :
                        row.strategyCode.split(';')) {

                        String cleanCode =
                            ScheduleSspCsvHelper.normalizeStrategyCode(
                                code
                            );

                        if (String.isBlank(cleanCode)) {
                            continue;
                        }

                        rowCodesByMapping.put(
                            cleanCode,
                            ScheduleSspCsvHelper.hasStrategyMapping(code)
                        );
                    }
                }


                // Aucun produit / code strategy valide métier -> insert sans strategy
                if (rowCodesByMapping.isEmpty()) {

                    sessionSpeakerProduct__c ssp =
                        ScheduleSspCsvHelper.buildSsp(
                            row,
                            ev.Id,
                            speaker != null
                                ? speaker.Id
                                : null,
                            null
                        );

                    // Status obligatoire pour top speaker
                    if (speaker != null
                        && speaker.isTopSpeaker__c) {

                        ssp.presentationStatus__c =
                            'required';
                    }

                    ssps.add(ssp);

                    continue;
                }

                Set<Id> rowStrategyIds =
                    new Set<Id>();

                for (String cleanCode : rowCodesByMapping.keySet()) {

                    Boolean isDirectStrategy =
                        rowCodesByMapping.get(cleanCode);

                    Id strategyId =
                        isDirectStrategy
                            ? strategyByCode.get(cleanCode)
                            : strategyByProductName.get(cleanCode);

                    if (strategyId == null) {

                        collectedErrors.add(
                            'scheduleId : ' +
                            row.scheduleId +
                            ' Error : Strategy not found for ' +
                            (
                                isDirectStrategy
                                    ? 'strategy code : '
                                    : 'product : '
                            ) +
                            cleanCode
                        );

                        continue;
                    }

                    if (rowStrategyIds.contains(strategyId)) {
                        continue;
                    }

                    rowStrategyIds.add(strategyId);

                    sessionSpeakerProduct__c ssp =
                        ScheduleSspCsvHelper.buildSsp(
                            row,
                            ev.Id,
                            speaker != null
                                ? speaker.Id
                                : null,
                            strategyId
                        );

                    // Status obligatoire pour top speaker
                    if (speaker != null
                        && speaker.isTopSpeaker__c) {

                        ssp.presentationStatus__c =
                            'required';
                    }

                    ssps.add(ssp);
                }

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