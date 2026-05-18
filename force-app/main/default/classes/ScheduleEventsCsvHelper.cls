public without sharing class ScheduleEventsCsvHelper {

    public class ParsedCsv {
        public Map<String, Integer> headerIndex = new Map<String, Integer>();
        public List<String> records = new List<String>();
    }

    public class RowData {
        public String scheduleId;
        public String rawName;
        public String ownerId;
        public String crmUserId;
        public String salesTeam;
        public String companyId;
        public Integer participants;
        public String description;
        public String locationName;
        public String address1;
        public String postCode;
        public String originalDigitalCity;
        public String city;
        public String country;
        public Date startDate;
        public Date endDate;
        public String startTimeText;
        public String endTimeText;
        public Time startTime;
        public Time endTime;
        public String originalLine;
        public String sourceRecordType;
        public String sourceType;
        public String sourceStatus;
        public String localZone;
        public Set<String> speakerEmails = new Set<String>();
        public Set<String> productNames = new Set<String>();
    }

    public static ParsedCsv loadFromStaticResource(String resourceName) {
        StaticResource sr = [
            SELECT Body
            FROM StaticResource
            WHERE Name = :resourceName
            LIMIT 1
        ];

        return loadFromCsvString(sr.Body.toString());
    }

    public static List<String> getDataRecords(ParsedCsv parsed) {
        List<String> data = new List<String>();
        if (parsed == null || parsed.records == null || parsed.records.size() <= 1) {
            return data;
        }

        for (Integer i = 1; i < parsed.records.size(); i++) {
            if (!String.isBlank(parsed.records[i])) {
                data.add(parsed.records[i]);
            }
        }
        return data;
    }

    public static String getFirstDataRecord(ParsedCsv parsed) {
        List<String> data = getDataRecords(parsed);
        return data.isEmpty() ? null : data[0];
    }

    public static RowData buildRow(Map<String, Integer> headerIndex, String originalLine) {
        if (headerIndex == null || headerIndex.isEmpty() || String.isBlank(originalLine)) {
            return null;
        }

        List<String> cols = parseCsvLine(originalLine);
        RowData row = new RowData();

        row.scheduleId       = getCol(cols, headerIndex, 'tech_id_schedule__c');
        row.rawName          = getCol(cols, headerIndex, 'name');
        row.ownerId          = getCol(cols, headerIndex, 'owner');
        row.crmUserId        = getCol(cols, headerIndex, 'crm_user__c');
        row.salesTeam        = getCol(cols, headerIndex, 'sales_team__c');
        row.companyId        = getCol(cols, headerIndex, 'company__c');
        row.description      = getCol(cols, headerIndex, 'description');
        row.locationName     = normalizeText(getCol(cols, headerIndex, 'location_name__c'));
        row.address1         = normalizeText(getCol(cols, headerIndex, 'address_1__c'));
        row.postCode         = getCol(cols, headerIndex, 'post_code__c');
        row.city             = normalizeText(getCol(cols, headerIndex, 'city__c'));
        row.country          = normalizeText(getCol(cols, headerIndex, 'country__c'));
        row.sourceRecordType = getCol(cols, headerIndex, 'recordtype');
        row.sourceType       = getCol(cols, headerIndex, 'type');
        row.sourceStatus     = getCol(cols, headerIndex, 'status');
        row.originalLine     = originalLine;
        row.localZone = getCol(cols, headerIndex, 'local_zone__c');
        String startRaw = getCol(cols, headerIndex, 'start_date_time__c');
        String endRaw   = getCol(cols, headerIndex, 'end_date_time__c');

        row.startDate     = parseDateFromIso(startRaw);
        row.endDate       = parseDateFromIso(endRaw);
        row.startTimeText = parseTimeTextFromIso(startRaw);
        row.endTimeText   = parseTimeTextFromIso(endRaw);
        row.startTime     = parseTime(row.startTimeText);
        row.endTime       = parseTime(row.endTimeText);

        row.participants = parseInteger(getCol(cols, headerIndex, 'participants_number__c'));

        String speakerEmailRaw = getCol(cols, headerIndex, 'speakeremail');
        if (speakerEmailRaw == null) {
            speakerEmailRaw = getCol(cols, headerIndex, 'speakeremail__c');
        }
        row.speakerEmails = splitSpeakerEmails(speakerEmailRaw);
        row.productNames  = splitMultiValues(getCol(cols, headerIndex, 'product_t__c'));
        if (isDigitalLocation(row.city)) {
            row.originalDigitalCity = row.city;
            row.city = 'Digital';
            row.country = 'Digital';
        }
        if (String.isBlank(row.city)) {
            row.city = 'Digital';
        }
        if (String.isBlank(row.country)) {
            row.country = 'Digital';
        }
        row.salesTeam = normalizeSalesTeam(row.salesTeam, row.country);

        return row;
    }

    public static Set<String> splitSpeakerEmails(String raw) {
        Set<String> out = new Set<String>();
        if (String.isBlank(raw)) return out;

        String normalized = raw.replace(',', ';');

        for (String part : normalized.split(';')) {
            String v = cleanCsvValue(part);
            if (!String.isBlank(v)) {
                out.add(v.toLowerCase());
            }
        }
        return out;
    }
    public static String mapTimeZoneIdToIana(String timeZoneIdRaw) {
        if (String.isBlank(timeZoneIdRaw)) {
            return null;
        }

        String key = timeZoneIdRaw.trim();

        Map<String, String> tzMap = new Map<String, String>{
            '1'  => 'Etc/GMT+12',
            '2'  => 'Pacific/Pago_Pago',
            '3'  => 'Pacific/Honolulu',
            '4'  => 'America/Anchorage',
            '5'  => 'America/Los_Angeles',
            '6'  => 'America/Phoenix',
            '7'  => 'America/Chihuahua',
            '8'  => 'America/Denver',
            '9'  => 'America/Guatemala',
            '10' => 'America/Chicago',
            '11' => 'America/Mexico_City',
            '12' => 'America/Regina',
            '13' => 'America/Bogota',
            '14' => 'America/New_York',
            '15' => 'America/Indiana/Indianapolis',
            '16' => 'America/Halifax',
            '17' => 'America/Caracas',
            '18' => 'America/Santiago',
            '19' => 'America/St_Johns',
            '20' => 'America/Sao_Paulo',
            '21' => 'America/Argentina/Buenos_Aires',
            '22' => 'America/Nuuk',
            '23' => 'Atlantic/South_Georgia',
            '24' => 'Atlantic/Azores',
            '25' => 'Atlantic/Cape_Verde',
            '26' => 'UTC',
            '27' => 'Europe/London',
            '28' => 'Europe/Berlin',
            '29' => 'Europe/Budapest',
            '30' => 'Europe/Paris',
            '31' => 'Europe/Warsaw',
            '32' => 'Africa/Lagos',
            '33' => 'Europe/Istanbul',
            '34' => 'Europe/Bucharest',
            '35' => 'Africa/Cairo',
            '36' => 'Africa/Johannesburg',
            '37' => 'Europe/Kyiv',
            '38' => 'Asia/Jerusalem',
            '39' => 'Asia/Baghdad',
            '40' => 'Asia/Riyadh',
            '41' => 'Africa/Nairobi',
            '42' => 'Asia/Tehran',
            '43' => 'Europe/Moscow',
            '44' => 'Asia/Dubai',
            '45' => 'Asia/Baku',
            '46' => 'Asia/Kabul',
            '47' => 'Asia/Yekaterinburg',
            '48' => 'Asia/Karachi',
            '49' => 'Asia/Kolkata',
            '50' => 'Asia/Kathmandu',
            '51' => 'Asia/Almaty',
            '52' => 'Asia/Dhaka',
            '53' => 'Asia/Colombo',
            '54' => 'Asia/Yangon',
            '55' => 'Asia/Bangkok',
            '56' => 'Asia/Krasnoyarsk',
            '57' => 'Asia/Shanghai',
            '58' => 'Asia/Ulaanbaatar',
            '59' => 'Asia/Singapore',
            '60' => 'Australia/Perth',
            '61' => 'Asia/Taipei',
            '62' => 'Asia/Tokyo',
            '63' => 'Asia/Seoul',
            '64' => 'Asia/Yakutsk',
            '65' => 'Australia/Adelaide',
            '66' => 'Australia/Darwin',
            '67' => 'Australia/Brisbane',
            '68' => 'Australia/Sydney',
            '69' => 'Pacific/Port_Moresby',
            '70' => 'Australia/Hobart',
            '71' => 'Asia/Vladivostok',
            '72' => 'Pacific/Guadalcanal',
            '73' => 'Pacific/Auckland',
            '74' => 'Pacific/Fiji',
            '75' => 'Pacific/Tongatapu'
        };

        return tzMap.get(key);
    }

    // mapCategory()

    public static String mapCategory(String sourceType) {
        if (String.isBlank(sourceType)) {
            return 'Client Event';
        }

        String v = sourceType.trim();

        // One-To-One Meeting => One to One meeting
        if (v == 'One-To-One Meeting') {
            return 'One to One meeting';
        }

        if (v == 'Sales Presentation' || v == 'Partnership') {
            return 'Event conference';
        }

        return v;
    }

    // mapStatus()

    public static String mapStatus(String sourceStatus) {
        if (String.isBlank(sourceStatus)) {
            return null;
        }

        String v = sourceStatus.trim();

        if (
            v == 'Event Validated' ||
            v == 'Outlook Invitation'
        ) {
            return 'FullyApproved';
        }

        // Request Created + Request Validated => Draft
        if (
            v == 'Request Created' ||
            v == 'Request Validated'
        ) {
            return 'Draft';
        }

        return null;
    }

    public static Id getEventRecordTypeId(String sourceType) {
        String developerName = (sourceType == 'One-To-One Meeting')
            ? 'Meeting'
            : 'event';

        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Event__c.getRecordTypeInfosByDeveloperName();

        Schema.RecordTypeInfo rtInfo = rtByDevName.get(developerName);

        if (rtInfo != null) {
            return rtInfo.getRecordTypeId();
        }

        return null;
    }

    public static Event__c buildEvent(RowData row) {
        if (row == null || String.isBlank(row.scheduleId)) {
            return null;
        }
        Event__c ev = new Event__c();

        ev.ScheduleID__c = row.scheduleId;
        ev.Name = safe80(row.rawName);
        ev.Title__c = safe50(extractTitle(row.rawName));

        // Owner => salesOwner__c
        if (isRealId(row.ownerId)) {
            ev.salesOwner__c = row.ownerId;
        }

        // CRM_User__c => Organizer__c
        if (isRealId(row.crmUserId)) {
            ev.Organizer__c = row.crmUserId;
        }

        ev.startDate__c = row.startDate;
        ev.endDate__c = row.endDate;
        ev.startTime__c = row.startTimeText;
        ev.endTime__c = row.endTimeText;

        ev.salesTeam__c = row.salesTeam;
        ev.city__c = row.city;
        ev.country__c = row.country;    
        ev.LocationName__c = row.locationName;
        ev.LocationAddress__c = row.address1;
        ev.LocationPostCode__c = row.postCode;
        ev.company__c = row.companyId;
        ev.speakersHTML__c = row.originalLine;
        ev.targetedAttendees__c = row.participants != null ? row.participants : 0;
        ev.timeZone__c = !String.isBlank(row.originalDigitalCity)
            ? mapDigitalCityToIana(row.originalDigitalCity, row.localZone)
            : mapTimeZoneIdToIana(row.localZone);
        ev.category__c = mapCategory(row.sourceType);
        // Copy description depending on category
        if (
            ev.category__c == 'One To One meeting' ||
            ev.category__c == 'Meeting day(s)'
        ) {
            ev.meetingBackground__c = row.description;
            ev.meetingGoal__c = row.description;
        } else {
            ev.description__c = row.description;
        }
        String mappedStatus = mapStatus(row.sourceStatus);
        ev.status__c = !String.isBlank(mappedStatus) ? mappedStatus : 'Draft';

        ev.Co_hosted__c = 'No';
        ev.clientType__c = 'Client';
        ev.format__c = !String.isBlank(row.originalDigitalCity) ? 'Digital' : 'Physical';
        ev.language__c = 'English';

        ev.RecordTypeId = getEventRecordTypeId(row.sourceType);

        ev.noAutomations__c = true;
        ev.bypasseApprovals__c = true;
        ev.bypasseNotifications__c = true;

        return ev;
    }

    public static List<sessionSpeakerProduct__c> buildSsps(
        RowData row,
        Id eventId,
        Map<String, Contact> contactsByEmail,
        Map<String, Id> strategyByProductName
    ) {
        List<sessionSpeakerProduct__c> out = new List<sessionSpeakerProduct__c>();

        if (row == null || eventId == null) {
            return out;
        }

        Set<Id> uniqueStrategyIds = new Set<Id>();
        for (String productName : row.productNames) {
            Id strategyId = strategyByProductName.get(productName);
            if (strategyId != null) {
                uniqueStrategyIds.add(strategyId);
            }
        }

        if (uniqueStrategyIds.isEmpty() || row.speakerEmails.isEmpty()) {
            return out;
        }

        for (String email : row.speakerEmails) {
            Contact speaker = contactsByEmail.get(email);
            if (speaker == null) continue;

            for (Id strategyId : uniqueStrategyIds) {
                sessionSpeakerProduct__c ssp = new sessionSpeakerProduct__c();
                ssp.Session__c = eventId;
                ssp.SpeakerContact__c = speaker.Id;
                ssp.Strategy__c = strategyId;
                ssp.Language__c = 'English';
                ssp.SpeakerLanguage__c = 'English';
                ssp.startTime__c = row.startTime;
                ssp.endTime__c = row.endTime;

                out.add(ssp);
            }
        }

        return out;
    }

    public static Map<String, Contact> loadContactsByEmail(Set<String> emails) {
        Map<String, Contact> out = new Map<String, Contact>();
        if (emails == null || emails.isEmpty()) return out;

        for (Contact c : [
            SELECT Id, Email
            FROM Contact
            WHERE Email IN :emails
        ]) {
            if (!String.isBlank(c.Email)) {
                out.put(c.Email.trim().toLowerCase(), c);
            }
        }
        return out;
    }

    public static Map<String, Id> loadStrategiesByProductName(Set<String> productNames) {
        Map<String, Id> out = new Map<String, Id>();
        if (productNames == null || productNames.isEmpty()) return out;

        for (Product__c p : [
            SELECT Id, Name, FundStrategy__c
            FROM Product__c
            WHERE Name IN :productNames
            AND FundStrategy__c != null
        ]) {
            if (!String.isBlank(p.Name) && p.FundStrategy__c != null) {
                out.put(p.Name.trim(), p.FundStrategy__c);
            }
        }
        return out;
    }

    public static String cleanCsvValue(String v) {
        if (String.isBlank(v)) return null;
        String x = v.trim();
        if (x == 'NULL' || x == 'null' || x == '(Blank)') return null;
        return x;
    }

    public static Boolean isRealId(String v) {
        String x = cleanCsvValue(v);
        if (x == null) return false;
        return x.length() == 15 || x.length() == 18;
    }

    private static String getCol(List<String> cols, Map<String, Integer> headerIndex, String headerName) {
        if (cols == null || headerIndex == null || String.isBlank(headerName)) return null;

        Integer idx = headerIndex.get(cleanHeader(headerName));
        if (idx == null || idx < 0 || idx >= cols.size()) return null;

        return cleanCsvValue(cols[idx]);
    }

    private static String cleanHeader(String h) {
        if (h == null) return null;

        String out = h.trim();

        if (!String.isBlank(out) && out.startsWith('\uFEFF')) {
            out = out.substring(1);
        }

        return out.toLowerCase();
    }

    public static Set<String> splitMultiValues(String raw) {
        Set<String> out = new Set<String>();
        if (String.isBlank(raw)) return out;

        for (String part : raw.split(';')) {
            String v = cleanCsvValue(part);
            if (!String.isBlank(v)) {
                out.add(v);
            }
        }
        return out;
    }

    public static Set<String> splitMultiValuesLower(String raw) {
        Set<String> out = new Set<String>();
        if (String.isBlank(raw)) return out;

        for (String part : raw.split(';')) {
            String v = cleanCsvValue(part);
            if (!String.isBlank(v)) {
                out.add(v.toLowerCase());
            }
        }
        return out;
    }

    public static Integer parseInteger(String raw) {
        if (String.isBlank(raw)) return 0;
        try {
            Decimal d = Decimal.valueOf(raw.trim());
            return Integer.valueOf(String.valueOf(d.intValue()));
        } catch (Exception e) {
            return 0;
        }
    }

    public static Date parseDateFromIso(String raw) {
        if (String.isBlank(raw) || raw.length() < 10) return null;
        return Date.valueOf(raw.substring(0, 10));
    }

    public static String parseTimeTextFromIso(String raw) {
        if (String.isBlank(raw) || raw.length() < 16) return null;
        return raw.substring(11, 16);
    }

    public static Time parseTime(String hhmm) {
        if (String.isBlank(hhmm)) return null;
        List<String> parts = hhmm.split(':');
        if (parts.size() < 2) return null;

        return Time.newInstance(
            Integer.valueOf(parts[0]),
            Integer.valueOf(parts[1]),
            0,
            0
        );
    }

    public static String safe50(String v) {
        if (String.isBlank(v)) return 'Legacy Event';
        return v.length() > 50 ? v.substring(0, 50) : v;
    }

    public static String safe80(String v) {
        if (String.isBlank(v)) return 'Legacy Event';
        return v.length() > 80 ? v.substring(0, 80) : v;
    }

    public static String extractTitle(String fullName) {
        if (String.isBlank(fullName)) return 'Legacy Event';

        List<String> parts = fullName.split(' - ');
        if (parts.size() >= 3) {
            List<String> titleParts = new List<String>();
            for (Integer i = 2; i < parts.size(); i++) {
                titleParts.add(parts[i]);
            }
            return String.join(titleParts, ' - ');
        }

        return fullName;
    }

    public static String normalizeSalesTeam(String salesTeamRaw, String countryRaw) {
        if (salesTeamRaw == 'CH') return 'Switzerland';
        if (salesTeamRaw == 'GB') return 'United Kingdom';
        if (salesTeamRaw == 'DE') return 'Germany';
        if (salesTeamRaw == 'FR') return 'France';
        if (!String.isBlank(countryRaw)) return countryRaw;
        return salesTeamRaw;
    }

    public static String normalizeText(String input) {
        if (String.isBlank(input)) return input;

        Map<String, String> mapChars = new Map<String, String>{
            'ä'=>'a','ö'=>'o','ü'=>'u','Ä'=>'A','Ö'=>'O','Ü'=>'U',
            'é'=>'e','è'=>'e','ê'=>'e','ë'=>'e',
            'à'=>'a','â'=>'a','á'=>'a',
            'î'=>'i','ï'=>'i','í'=>'i',
            'ô'=>'o','ó'=>'o',
            'ù'=>'u','û'=>'u','ú'=>'u',
            'ç'=>'c','ñ'=>'n','ß'=>'ss'
        };

        String result = input;
        for (String k : mapChars.keySet()) {
            result = result.replace(k, mapChars.get(k));
        }
        return result;
    }

    public static List<String> splitCsvRecords(String csv) {
        List<String> records = new List<String>();
        if (String.isBlank(csv)) return records;

        String current = '';
        Boolean inQuotes = false;

        for (Integer i = 0; i < csv.length(); i++) {
            String ch = csv.substring(i, i + 1);

            if (ch == '"') {
                current += ch;

                if (inQuotes && i + 1 < csv.length() && csv.substring(i + 1, i + 2) == '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            }else if ((ch == '\n' || ch == '\r') && !inQuotes) {
                if (!String.isBlank(current.trim())) {
                    records.add(current.trim());
                }
                current = '';

                if (ch == '\r' && i + 1 < csv.length() && csv.substring(i + 1, i + 2) == '\n') {
                    i++;
                }
            } else {
                current += ch;
            }
        }

        if (!String.isBlank(current.trim())) {
            records.add(current.trim());
        }

        return records;
    }

    public static List<String> parseCsvLine(String line) {
        List<String> result = new List<String>();
        if (line == null) return result;

        String current = '';
        Boolean inQuotes = false;

        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);

            if (ch == '"') {
                if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ';' && !inQuotes) {
                result.add(current);
                current = '';
            } else {
                current += ch;
            }
        }

        result.add(current);
        return result;
    }

    public static ParsedCsv loadFromCsvString(String csv) {
        ParsedCsv out = new ParsedCsv();
        out.records = splitCsvRecords(csv);

        if (out.records.isEmpty()) {
            return out;
        }

        List<String> headers = parseCsvLine(out.records[0]);
        for (Integer i = 0; i < headers.size(); i++) {
            out.headerIndex.put(cleanHeader(headers[i]), i);
        }

        return out;
    }

    private static Boolean isDigitalLocation(String cityRaw) {
        return !String.isBlank(cityRaw) && cityRaw.startsWith('Digital_');
    }

    private static String mapDigitalCityToIana(String cityRaw, String fallbackLocalZone) {
        if (String.isBlank(cityRaw)) {
            return mapTimeZoneIdToIana(fallbackLocalZone);
        }

        String v = cityRaw.trim();

        if (v == 'Digital_ParisTime') {
            return 'Europe/Paris';
        }
        if (v == 'Digital_LondonTime') {
            return 'Europe/London';
        }
        if (v == 'Digital_BerlinTime') {
            return 'Europe/Berlin';
        }
        if (v == 'Digital_MadridTime') {
            return 'Europe/Madrid';
        }
        if (v == 'Digital_RomeTime') {
            return 'Europe/Rome';
        }
        if (v == 'Digital_ZurichTime') {
            return 'Europe/Zurich';
        }
        if (v == 'Digital_ViennaTime') {
            return 'Europe/Vienna';
        }
        if (v == 'Digital_BrusselsTime') {
            return 'Europe/Brussels';
        }
        if (v == 'Digital_StockholmTime') {
            return 'Europe/Stockholm';
        }
        if (v == 'Digital_LuxembourgTime') {
            return 'Europe/Luxembourg';
        }
        if (v == 'Digital_CopenhagenTime') {
            return 'Europe/Copenhagen';
        }
        if (v == 'Digital_HelsinkiTime') {
            return 'Europe/Helsinki';
        }
        if (v == 'Digital_LisbonTime') {
            return 'Europe/Lisbon';
        }
        if (v == 'Digital_DublinTime') {
            return 'Europe/Dublin';
        }

        return mapTimeZoneIdToIana(fallbackLocalZone);
    }

    private static String mapFormat(String cityRaw) {
        return isDigitalLocation(cityRaw) ? 'Digital' : 'Physical';
    }

}