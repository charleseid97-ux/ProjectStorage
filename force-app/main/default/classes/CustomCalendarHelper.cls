public with sharing class CustomCalendarHelper {

    private static final String TRACE_BUILD_ISO = 'buildIsoFloating ';
    private static final String ISO_FMT = 'yyyy-MM-dd\'T\'HH:mm:ss';
    private static final String COLOR_BLACK = '#000000';
    private static final String COLOR_WHITE = '#FFFFFF';
    private static final String TZ_UTC00 = 'UTC+00';

    public class EventDto {
        @AuraEnabled public String id;
        @AuraEnabled public String title;

        @AuraEnabled public String start;
        @AuraEnabled public String startIso;

        @AuraEnabled public String endStr;
        @AuraEnabled public String endIso;

        @AuraEnabled public String color;
        @AuraEnabled public String textColor;

        @AuraEnabled public Id recordTypeId;
        @AuraEnabled public String salesTeam;
        @AuraEnabled public Id parentEventId;

        @AuraEnabled public String timezone;
        @AuraEnabled public Id sObjectId;
    }

    private class TraceLog {
        private List<String> lines = new List<String>();
        void add(String msg) {
            lines.add(DateTime.now().formatGmt('HH:mm:ss.SSS') + ' | ' + msg);
        }
        void flush(String prefix) {
            System.debug(LoggingLevel.DEBUG, prefix + '\n' + String.join(lines, '\n'));
        }
    }

    private static String twoDigits(Integer v) {
        if (v == null) return '00';
        return (v < 10 ? '0' : '') + String.valueOf(v);
    }

    @AuraEnabled(cacheable=true)
    public static String getUserUtcOffset() {
        String tzKey = UserInfo.getTimeZone().getID();
        TimeZone tz = TimeZone.getTimeZone(tzKey);

        DateTime ref = DateTime.newInstance(Date.today(), Time.newInstance(12, 0, 0, 0));
        Integer offsetMs = tz.getOffset(ref);
        Integer offsetMin = offsetMs / 60000;

        Integer hh = Math.abs(offsetMin) / 60;
        String sign = (offsetMin >= 0) ? '+' : '-';

        return 'UTC' + sign + twoDigits(hh);
    }

    @AuraEnabled(cacheable=true)
    public static List<EventDto> getEvents(
        String recordId,
        String childObject,
        String parentFieldName,
        String startDatetimeField,
        String endDatetimeField,
        String titleField,
        Date startDate,
        String colorField,
        Date endDate,
        List<String> salesTeams,
        List<Id> speakerIds,
        String targetTimezone
    ) {
        TraceLog t = new TraceLog();
        t.add('getEvents START');
        t.add('recordId=' + recordId + ' childObject=' + childObject + ' parentFieldName=' + parentFieldName);
        t.add('targetTimezone=' + targetTimezone);

        DateWindow dw = normalizeDateWindow(startDate, endDate);
        startDate = dw.startDate;
        endDate = dw.endDate;
        t.add('dateWindow startDate=' + startDate + ' endDate=' + endDate);

        targetTimezone = normalizeTargetTimezone(targetTimezone, t);

        Boolean isEventContext = isEventContext(recordId);
        t.add('eventPrefix=' + Event__c.SObjectType.getDescribe().getKeyPrefix() + ' isEventContext=' + isEventContext);

        List<String> whereParts = new List<String>();
        Id rtMeetingDays = isEventContext ? tryGetMeetingDaysRecordTypeId(t) : null;

        if (isEventContext) {
            whereParts.add(buildParentClause(parentFieldName, recordId, rtMeetingDays, t));
        }

        addDateOverlapClauses(whereParts);
        addSalesTeamClause(whereParts, salesTeams, t);

        Set<Id> sessionIdsFromSpeakers = resolveSessionIdsFromSpeakers(speakerIds, t);
        if (speakerIds != null && !speakerIds.isEmpty()) {
            if (sessionIdsFromSpeakers.isEmpty()) {
                t.add('no sessions found for speakers -> returning empty');
                t.flush('CustomCalendarHelper.getEvents TRACE');
                return new List<EventDto>();
            }
            whereParts.add('Id IN :sessionIdsFromSpeakers');
        } else {
            t.add('speakerIds empty');
        }

        String safeTitleField = String.isBlank(titleField) ? 'Name' : titleField;
        String safeColorField = String.isBlank(colorField) ? 'color__c' : colorField;

        String selectFields =
            'Id, RecordTypeId, ' +
            safeTitleField + ', ' +
            safeColorField + ', ' +
            'SalesTeam__c, ParentEvent__c, timezone__c, ' +
            'startDate__c, startTime__c, endDate__c, endTime__c';

        String soql =
            'SELECT ' + selectFields +
            ' FROM ' + childObject +
            ' WHERE ' + String.join(whereParts, ' AND ');

        t.add('SOQL=' + soql);

        List<SObject> records = Database.query(soql);
        t.add('records.size=' + records.size());

        applyColorsSafely(records, t);

        List<EventDto> outList = new List<EventDto>();
        Boolean convertToTarget = !isEventContext;

        for (SObject s : records) {
            outList.add(buildDto(
                s,
                safeTitleField,
                safeColorField,
                convertToTarget,
                targetTimezone,
                t
            ));
        }

        t.add('outList.size=' + outList.size());
        t.add('getEvents END');
        t.flush('CustomCalendarHelper.getEvents TRACE');

        return outList;
    }

    private class DateWindow {
        Date startDate;
        Date endDate;
        DateWindow(Date s, Date e) {
            startDate = s;
            endDate = e;
        }
    }

    private static DateWindow normalizeDateWindow(Date startDate, Date endDate) {
        if (startDate == null && endDate == null) {
            return new DateWindow(Date.today(), Date.today().addDays(30));
        }
        if (startDate == null) {
            return new DateWindow(endDate.addDays(-30), endDate);
        }
        if (endDate == null) {
            return new DateWindow(startDate, startDate.addDays(30));
        }
        return new DateWindow(startDate, endDate);
    }

    private static String normalizeTargetTimezone(String targetTimezone, TraceLog t) {
        if (String.isBlank(targetTimezone)) {
            if (t != null) t.add('targetTimezone blank -> default ' + TZ_UTC00);
            return TZ_UTC00;
        }
        return targetTimezone;
    }

    private static Boolean isEventContext(String recordId) {
        if (String.isBlank(recordId)) return false;
        String eventPrefix = Event__c.SObjectType.getDescribe().getKeyPrefix();
        return recordId.startsWith(eventPrefix);
    }

    private static Id tryGetMeetingDaysRecordTypeId(TraceLog t) {
        try {
            Id rtId = Event__c.SObjectType
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('MeetingDays')
                .getRecordTypeId();
            if (t != null) t.add('rtMeetingDays=' + rtId);
            return rtId;
        } catch (Exception e) {
            if (t != null) t.add('rtMeetingDays lookup failed: ' + e.getMessage());
            return null;
        }
    }

    private static String buildParentClause(String parentFieldName, String recordId, Id rtMeetingDays, TraceLog t) {
        String parentClause = '(' + parentFieldName + ' = :recordId OR Id = :recordId)';
        if (rtMeetingDays != null) {
            parentClause += ' AND RecordTypeId != :rtMeetingDays';
        }
        if (t != null) t.add('parentClause=' + parentClause);
        return parentClause;
    }

    private static void addDateOverlapClauses(List<String> whereParts) {
        whereParts.add('(startDate__c != null AND startDate__c <= :endDate)');
        whereParts.add('(endDate__c   != null AND endDate__c   >= :startDate)');
    }

    private static void addSalesTeamClause(List<String> whereParts, List<String> salesTeams, TraceLog t) {
        if (salesTeams != null && !salesTeams.isEmpty()) {
            whereParts.add('SalesTeam__c IN :salesTeams');
            if (t != null) t.add('salesTeams.size=' + salesTeams.size());
        } else {
            if (t != null) t.add('salesTeams empty');
        }
    }

    private static Set<Id> resolveSessionIdsFromSpeakers(List<Id> speakerIds, TraceLog t) {
        Set<Id> sessionIds = new Set<Id>();
        if (speakerIds == null || speakerIds.isEmpty()) return sessionIds;

        if (t != null) t.add('speakerIds.size=' + speakerIds.size());

        List<SessionSpeakerProduct__c> links = [
            SELECT Session__c
            FROM SessionSpeakerProduct__c
            WHERE speakerContact__c IN :speakerIds
        ];
        if (t != null) t.add('speakerLinks.size=' + links.size());

        for (SessionSpeakerProduct__c link : links) {
            if (link.Session__c != null) sessionIds.add(link.Session__c);
        }
        return sessionIds;
    }

    private static void applyColorsSafely(List<SObject> records, TraceLog t) {
        try {
            EventColorService.applyColorsInMemory((List<Event__c>) records);
            if (t != null) t.add('EventColorService applied');
        } catch (Exception ex) {
            if (t != null) t.add('EventColorService skipped: ' + ex.getMessage());
        }
    }

    private static EventDto buildDto(
        SObject s,
        String safeTitleField,
        String safeColorField,
        Boolean convertToTarget,
        String targetTimezone,
        TraceLog t
    ) {
        EventDto dto = new EventDto();

        Id rid = (Id) s.get('Id');
        dto.id = (String) rid;
        dto.sObjectId = rid;

        dto.recordTypeId = (Id) s.get('RecordTypeId');
        dto.salesTeam = (String) s.get('SalesTeam__c');
        dto.parentEventId = (Id) s.get('ParentEvent__c');

        Object tVal = s.get(safeTitleField);
        dto.title = (tVal == null) ? '(no title)' : String.valueOf(tVal);

        Object cVal = s.get(safeColorField);
        dto.color = (cVal == null) ? null : String.valueOf(cVal);
        dto.textColor = computeTextColor(dto.color);

        Date sd = (Date) s.get('startDate__c');
        String stTxt = (String) s.get('startTime__c');
        Date ed = (Date) s.get('endDate__c');
        String etTxt = (String) s.get('endTime__c');

        String srcTzId = (String) s.get('timezone__c');

        String startIso = buildIsoFloating(sd, stTxt, convertToTarget, srcTzId, targetTimezone, t, rid, 'start');
        String endIso   = buildIsoFloating(ed, etTxt, convertToTarget, srcTzId, targetTimezone, t, rid, 'end');

        dto.start = startIso;
        dto.startIso = startIso;

        dto.endStr = endIso;
        dto.endIso = endIso;

        dto.timezone = String.isBlank(srcTzId) ? TZ_UTC00 : srcTzId;

        return dto;
    }

    private static String buildIsoFloating(
        Date d,
        String timeTxt,
        Boolean convertToTarget,
        String srcTzId,
        String targetTzId,
        TraceLog t,
        Id rid,
        String label
    ) {
        DateTime base = buildBaseDateTime(d, timeTxt, t, rid, label);
        if (base == null) return null;

        if (!convertToTarget) {
            String outNoConvert = base.format(ISO_FMT);
            logBuildIso(t, label, 'no convert', rid, outNoConvert);
            return outNoConvert;
        }

        Integer srcOffsetMin = safeOffsetMinutes(srcTzId, 'src', t, label, rid);
        Integer targetOffsetMin = safeOffsetMinutes(targetTzId, 'tgt', t, label, rid);

        Integer deltaMin = targetOffsetMin - srcOffsetMin;
        DateTime shifted = base.addMinutes(deltaMin);
        String outShifted = shifted.format(ISO_FMT);

        if (t != null) {
            t.add(TRACE_BUILD_ISO + label + ': convert rid=' + rid + ' src=' + srcTzId + ' tgt=' + targetTzId
                + ' srcOffsetMin=' + srcOffsetMin + ' tgtOffsetMin=' + targetOffsetMin + ' deltaMin=' + deltaMin);
            t.add('  base=' + base.format(ISO_FMT) + ' out=' + outShifted);
        }

        return outShifted;
    }

    private static DateTime buildBaseDateTime(Date d, String timeTxt, TraceLog t, Id rid, String label) {
        if (d == null || String.isBlank(timeTxt)) {
            if (t != null) t.add(TRACE_BUILD_ISO + label + ': null input rid=' + rid + ' d=' + d + ' time=' + timeTxt);
            return null;
        }

        TimeParts tp = parseTimePartsSafe(timeTxt, t, rid, label);
        if (tp == null) return null;

        return DateTime.newInstance(d, Time.newInstance(tp.hh, tp.mm, tp.ss, 0));
    }

    private class TimeParts {
        Integer hh;
        Integer mm;
        Integer ss;
        TimeParts(Integer h, Integer m, Integer s) {
            hh = h; mm = m; ss = s;
        }
    }

    private static TimeParts parseTimePartsSafe(String timeTxt, TraceLog t, Id rid, String label) {
        List<Integer> parts = parseTimeParts(timeTxt);
        if (parts == null || parts.size() < 2) {
            if (t != null) t.add(TRACE_BUILD_ISO + label + ': parse failed rid=' + rid + ' timeTxt=' + timeTxt);
            return null;
        }

        Integer hh = parts[0];
        Integer mm = parts[1];
        Integer ss = (parts.size() >= 3) ? parts[2] : 0;

        if (hh == null || mm == null || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
            if (t != null) t.add(TRACE_BUILD_ISO + label + ': invalid time rid=' + rid + ' hh=' + hh + ' mm=' + mm + ' ss=' + ss);
            return null;
        }

        if (ss == null || ss < 0 || ss > 59) ss = 0;
        return new TimeParts(hh, mm, ss);
    }

    private static void logBuildIso(TraceLog t, String label, String mode, Id rid, String iso) {
        if (t != null) t.add(TRACE_BUILD_ISO + label + ': ' + mode + ' rid=' + rid + ' => ' + iso);
    }

    private static Integer safeOffsetMinutes(String tzId, String kind, TraceLog t, String label, Id rid) {
        Integer offsetMin = parseUtcOffsetMinutes(tzId);
        if (offsetMin != null) return offsetMin;

        if (t != null) t.add(TRACE_BUILD_ISO + label + ': invalid ' + kind + 'TzId=' + tzId + ' fallback offsetMin=0 rid=' + rid);
        return 0;
    }

    private static Integer parseUtcOffsetMinutes(String tzApi) {
        if (String.isBlank(tzApi)) return null;

        String v = tzApi.trim().toUpperCase();
        if (!v.startsWith('UTC')) return null;

        Integer idxPlus = v.indexOf('+');
        Integer idxMinus = v.indexOf('-');

        Integer sign = 1;
        Integer idx;

        if (idxPlus > -1) {
            sign = 1;
            idx = idxPlus;
        } else if (idxMinus > -1) {
            sign = -1;
            idx = idxMinus;
        } else {
            return 0;
        }

        String hhStr = v.substring(idx + 1);
        Integer hh;
        try {
            hh = Integer.valueOf(hhStr);
        } catch (Exception e) {
            return null;
        }

        return sign * hh * 60;
    }

    private static List<Integer> parseTimeParts(String timeTxt) {
        if (String.isBlank(timeTxt)) return null;

        String v = timeTxt.trim();
        if (!v.contains(':')) return null;

        List<String> seg = v.split(':');
        if (seg.size() < 2) return null;

        try {
            Integer hh = Integer.valueOf(seg[0]);
            Integer mm = Integer.valueOf(seg[1]);
            Integer ss = (seg.size() >= 3) ? Integer.valueOf(seg[2]) : 0;
            return new List<Integer>{ hh, mm, ss };
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer hexPairToInt(String pair) {
        if (String.isBlank(pair) || pair.length() != 2) return 0;

        String digits = '0123456789ABCDEF';
        String p = pair.toUpperCase();

        Integer hi = digits.indexOf(p.substring(0, 1));
        Integer lo = digits.indexOf(p.substring(1, 2));

        if (hi < 0 || lo < 0) return 0;
        return (hi * 16) + lo;
    }

    private static String computeTextColor(String hex) {
        if (String.isBlank(hex)) return COLOR_BLACK;

        String v = hex.trim();
        if (v.startsWith('#')) v = v.substring(1);

        if (v.length() == 3) {
            v = ''
                + v.substring(0,1) + v.substring(0,1)
                + v.substring(1,2) + v.substring(1,2)
                + v.substring(2,3) + v.substring(2,3);
        }

        if (v.length() != 6) return COLOR_BLACK;

        Integer r = hexPairToInt(v.substring(0,2));
        Integer g = hexPairToInt(v.substring(2,4));
        Integer b = hexPairToInt(v.substring(4,6));

        Decimal luminance = (r * 0.299) + (g * 0.587) + (b * 0.114);
        return (luminance > 186) ? COLOR_BLACK : COLOR_WHITE;
    }

    @AuraEnabled(cacheable=true)
    public static String getEventPrefix() {
        return Event__c.SObjectType.getDescribe().getKeyPrefix();
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getSpeakerContacts() {
        List<Option> results = new List<Option>();
        for (Contact c : [
            SELECT Id, Name
            FROM Contact
            WHERE isValidSpeaker__c = true
            ORDER BY Name
            LIMIT 2000
        ]) {
            results.add(new Option((String) c.Id, c.Name));
        }
        return results;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public Option(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}