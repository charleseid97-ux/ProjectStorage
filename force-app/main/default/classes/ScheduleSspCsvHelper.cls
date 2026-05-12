public without sharing class ScheduleSspCsvHelper {

    public class RowData {
        public String scheduleId;
        public String eventScheduleId;
        public String speakerEmail;
        public String strategyCode;

        public Date sessionDate;

        public Time startTime;
        public Time endTime;
    }


    // Build une ligne SSP depuis le CSV
    public static RowData buildRow(
        Map<String, Integer> headerIndex,
        String originalLine
    ) {

        if (headerIndex == null || String.isBlank(originalLine)) {
            return null;
        }

        List<String> cols =
            ScheduleEventsCsvHelper.parseCsvLine(originalLine);

        RowData row = new RowData();

        row.scheduleId =
            getCol(cols, headerIndex, 'tech_id_speaker_schedule__c');

        row.eventScheduleId =
            getCol(cols, headerIndex, 'schedule_key_event__c');

        row.speakerEmail =
            getCol(cols, headerIndex, 'name');

        row.strategyCode =
            getCol(cols, headerIndex, 'thematic__c');

        String startRaw =
            getCol(cols, headerIndex, 'start_date_time__c');

        String endRaw =
            getCol(cols, headerIndex, 'end_date_time__c');


        // Parse date session
        row.sessionDate = parseFrenchDate(startRaw);

        // Parse heures
        row.startTime = parseFrenchTime(startRaw);

        row.endTime = parseFrenchTime(endRaw);

        return row;
    }


    // Build le SSP final
    public static sessionSpeakerProduct__c buildSsp(
        RowData row,
        Id eventId,
        Id contactId,
        Id strategyId
    ) {

        if (row == null) {
            return null;
        }

        sessionSpeakerProduct__c ssp =
            new sessionSpeakerProduct__c();

        ssp.scheduleId__c = row.scheduleId;

        ssp.Session__c = eventId;

        ssp.SpeakerContact__c = contactId;

        ssp.Strategy__c = strategyId;

        ssp.date__c = row.sessionDate;

        ssp.startTime__c = row.startTime;

        ssp.endTime__c = row.endTime;

        return ssp;
    }


    // Parse date FR dd/MM/yyyy HH:mm
    public static Date parseFrenchDate(String raw) {

        if (String.isBlank(raw)) {
            return null;
        }

        List<String> parts =
            raw.split(' ');

        List<String> d =
            parts[0].split('/');

        return Date.newInstance(
            Integer.valueOf(d[2]),
            Integer.valueOf(d[1]),
            Integer.valueOf(d[0])
        );
    }


    // Parse heure FR dd/MM/yyyy HH:mm
    public static Time parseFrenchTime(String raw) {

        if (String.isBlank(raw)) {
            return null;
        }

        List<String> parts =
            raw.split(' ');

        List<String> t =
            parts[1].split(':');

        return Time.newInstance(
            Integer.valueOf(t[0]),
            Integer.valueOf(t[1]),
            0,
            0
        );
    }


    // Lecture colonne CSV
    private static String getCol(
        List<String> cols,
        Map<String, Integer> headerIndex,
        String header
    ) {

        Integer idx =
            headerIndex.get(header.toLowerCase());

        if (idx == null || idx >= cols.size()) {
            return null;
        }

        return ScheduleEventsCsvHelper.cleanCsvValue(
            cols[idx]
        );
    }
}
