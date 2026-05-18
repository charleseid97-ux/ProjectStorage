public without sharing class ScheduleSspCsvHelper {

    private static final Map<String, String> STRATEGY_MAPPING =
        new Map<String, String>{
            'CAELS' => 'CLSGE',
            'CPR100' => 'CME',
            'CPR75' => 'CME',
            'PIL' => 'CIL',
            'PSC' => 'CS',
            'UKCED' => 'CED',
            'UKCEMP' => 'CEMP',
            'UKCP' => 'CP',
            'GLMA' => 'GLMACRO',
            'BND' => 'BRAND',
            'BRND' => 'BRAND',
            'ESG1' => 'ESG',
            'CED' => 'CED',
            'INSO' => 'IS',
            'CUGB' => 'CUGB',
            'CSC' => 'CS',
            'CC25' => 'CC'
        };

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
            normalizeSpeakerEmail(
                getCol(cols, headerIndex, 'name')
            );

        row.strategyCode =
            getCol(cols, headerIndex, 'thematic__c');

        String startRaw =
            getCol(cols, headerIndex, 'start_date_time__c');

        String endRaw =
            getCol(cols, headerIndex, 'end_date_time__c');

        // Parse date session
        row.sessionDate =
            parseFrenchDate(startRaw);

        // Parse heures
        row.startTime =
            parseFrenchTime(startRaw);

        row.endTime =
            parseFrenchTime(endRaw);

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

        // Evite "_null" pour les lignes sans strategy
        ssp.scheduleId__c =
            strategyId != null
                ? row.scheduleId + '_' + String.valueOf(strategyId)
                : row.scheduleId;

        ssp.Session__c = eventId;

        ssp.SpeakerContact__c = contactId;

        ssp.Strategy__c = strategyId;

        ssp.date__c = row.sessionDate;

        ssp.startTime__c = row.startTime;

        ssp.endTime__c = row.endTime;

        return ssp;
    }


    // Parse date dd/MM/yyyy OR yyyy/MM/dd
    public static Date parseFrenchDate(String raw) {

        if (String.isBlank(raw)) {
            return null;
        }

        List<String> parts =
            raw.split(' ');

        List<String> d =
            parts[0].split('/');

        if (d.size() != 3) {
            return null;
        }

        Integer first =
            Integer.valueOf(d[0]);

        Integer second =
            Integer.valueOf(d[1]);

        Integer third =
            Integer.valueOf(d[2]);

        // yyyy/MM/dd
        if (d[0].length() == 4) {

            return Date.newInstance(
                first,
                second,
                third
            );
        }

        // dd/MM/yyyy
        return Date.newInstance(
            third,
            second,
            first
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


    // Normalise les emails speakers connus
    public static String normalizeSpeakerEmail(
        String email
    ) {

        if (String.isBlank(email)) {
            return null;
        }

        String cleanEmail =
            email.trim().toLowerCase();

        // Speakers vides métier
        if (cleanEmail == 'nospeaker@carmignac.com'
            || cleanEmail == 'micfmtobedefined@carmignac.com') {

            return null;
        }

        // Corrections emails
        if (cleanEmail == 'axelle.pinon@carmignac.com') {
            return 'apinon@carmignac.com';
        }

        if (cleanEmail == 'lloyd.mcallister@carmignac') {
            return 'llyod.mcallister@carmignac.com';
        }

        if (cleanEmail == 'jean-marc.viguie@carmignac.com') {
            return 'jeanmarc.viguie@carmignac.com';
        }
        if (cleanEmail == 'eliezer.ben-zimra@carmignac.com') {
            return 'eliezer.benzimra@carmignac.com';
        }
        if (cleanEmail == 'alexandre.combes@carmignac.com') {
            return 'acombes@carmignac.com';
        }
        if (cleanEmail == 'ariona.bundo@carmignac.com') {
            return 'ariona.bundo@carmignac.com.inactif';
        }
        if (cleanEmail == 'celine.demonsang@carmignac.com') {
            return 'celine.demonsang@carmignac.com.inactif';
        }
        if (cleanEmail == 'haiyan.li@carmignac.com') {
            return 'haiyan.li@carmignac.com.inactif';
        }
        if (cleanEmail == 'lloyd.mcallister@carmignac.com') {
            return 'llyod.mcallister@carmignac.com';
        }
        /*if (cleanEmail == 'malte.heininger@carmignac.com') {
            return 'eliezer.benzimra@carmignac.com';
        }*/
        if (cleanEmail == 'nicolas.dementhon@carmignac.com') {
            return 'ndementhon@carmignac.com';
        }
        /*if (cleanEmail == 'rosie.turner@carmignac.com') {
            return 'eliezer.benzimra@carmignac.com';
        }*/
        







        return cleanEmail;
    }


    // Normalise le code CSV en code Strategy ou Product
    public static String normalizeStrategyCode(
        String code
    ) {

        if (String.isBlank(code)) {
            return null;
        }

        String cleanCode =
            code.trim().toUpperCase();

        // Produit ignoré
        if (cleanCode == 'NOTH'
            || cleanCode == 'EMEQ') {

            return null;
        }

        if (STRATEGY_MAPPING.containsKey(cleanCode)) {
            return STRATEGY_MAPPING.get(cleanCode);
        }

        return cleanCode;
    }


    // Indique si le code CSV doit être cherché directement comme Strategy.Code__c
    public static Boolean hasStrategyMapping(
        String code
    ) {

        if (String.isBlank(code)) {
            return false;
        }

        String cleanCode =
            code.trim().toUpperCase();

        return STRATEGY_MAPPING.containsKey(cleanCode);
    }
}