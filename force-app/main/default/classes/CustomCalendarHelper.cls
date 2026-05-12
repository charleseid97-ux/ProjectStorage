public with sharing class CustomCalendarHelper {

    private static final String ISO_FMT = 'yyyy-MM-dd\'T\'HH:mm:ss';
    private static final String COLOR_BLACK = '#000000';
    private static final String COLOR_WHITE = '#FFFFFF';
    private static final String DEFAULT_TIMEZONE = 'UTC';

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
        @AuraEnabled public String category;
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

    @AuraEnabled(cacheable=true)
    public static String getUserUtcOffset() {
        return UserInfo.getTimeZone().getID();
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
        List<String> speakerJobTitles,
        String targetTimezone
    ) {
        TraceLog t = new TraceLog();
        t.add('getEvents START');

        DateWindow dw = normalizeDateWindow(startDate, endDate);
        startDate = dw.startDate;
        endDate = dw.endDate;

        targetTimezone = normalizeTargetTimezone(targetTimezone);

        Boolean isEventContext = isEventContext(recordId);
        Id rtMeetingDays = isEventContext ? tryGetMeetingDaysRecordTypeId(t) : null;

        List<String> whereParts = new List<String>();
        if (isEventContext) {
            whereParts.add(buildParentClause(parentFieldName, recordId, rtMeetingDays));
        }

        addDateOverlapClauses(whereParts);
        addSalesTeamClause(whereParts, salesTeams);

        Set<Id> sessionIdsFromSpeakerFilters = resolveSessionIdsFromSpeakerFilters(
            speakerIds,
            speakerJobTitles,
            t
        );

        if ((speakerIds != null && !speakerIds.isEmpty()) ||
            (speakerJobTitles != null && !speakerJobTitles.isEmpty())) {
            if (sessionIdsFromSpeakerFilters.isEmpty()) {
                t.add('no sessions found for speaker filters -> returning empty');
                t.flush('CustomCalendarHelper.getEvents TRACE');
                return new List<EventDto>();
            }
            whereParts.add('Id IN :sessionIdsFromSpeakerFilters');
        }

        String safeTitleField = String.isBlank(titleField) ? 'Name' : titleField;
        String safeColorField = String.isBlank(colorField) ? 'color__c' : colorField;

        String selectFields =
            'Id, RecordTypeId, ' +
            safeTitleField + ', ' +
            safeColorField + ', ' +
            'SalesTeam__c, ParentEvent__c, timezone__c, category__c, ' +
            'startDate__c, startTime__c, endDate__c, endTime__c';

        String soql =
            'SELECT ' + selectFields +
            ' FROM ' + childObject +
            ' WHERE ' + String.join(whereParts, ' AND ');

        List<SObject> records = Database.query(soql);
        applyColorsSafely(records, t);

        List<EventDto> outList = new List<EventDto>();
        Boolean convertToTarget = !isEventContext;

        for (SObject s : records) {
            outList.add(buildDto(
                (Event__c) s,
                safeTitleField,
                safeColorField,
                convertToTarget,
                targetTimezone
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

    private static String normalizeTargetTimezone(String targetTimezone) {
        return String.isBlank(targetTimezone) ? DEFAULT_TIMEZONE : targetTimezone;
    }

    private static Boolean isEventContext(String recordId) {
        if (String.isBlank(recordId)) {
            return false;
        }
        return recordId.startsWith(Event__c.SObjectType.getDescribe().getKeyPrefix());
    }

    private static Id tryGetMeetingDaysRecordTypeId(TraceLog t) {
        try {
            return Event__c.SObjectType
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('MeetingDays')
                .getRecordTypeId();
        } catch (Exception e) {
            if (t != null) {
                t.add('rtMeetingDays lookup failed: ' + e.getMessage());
            }
            return null;
        }
    }

    private static String buildParentClause(String parentFieldName, String recordId, Id rtMeetingDays) {
        String parentClause = '(' + parentFieldName + ' = :recordId OR Id = :recordId)';
        if (rtMeetingDays != null) {
            parentClause += ' AND RecordTypeId != :rtMeetingDays';
        }
        return parentClause;
    }

    private static void addDateOverlapClauses(List<String> whereParts) {
        whereParts.add('(startDate__c != null AND startDate__c <= :endDate)');
        whereParts.add('(endDate__c != null AND endDate__c >= :startDate)');
    }

    private static void addSalesTeamClause(List<String> whereParts, List<String> salesTeams) {
        if (salesTeams != null && !salesTeams.isEmpty()) {
            whereParts.add('SalesTeam__c IN :salesTeams');
        }
    }

    private static Set<Id> resolveSessionIdsFromSpeakerFilters(
        List<Id> speakerIds,
        List<String> speakerJobTitles,
        TraceLog t
    ) {
        Set<Id> sessionIds = new Set<Id>();

        Boolean hasSpeakerIds = speakerIds != null && !speakerIds.isEmpty();
        Boolean hasJobTitles = speakerJobTitles != null && !speakerJobTitles.isEmpty();

        if (!hasSpeakerIds && !hasJobTitles) {
            return sessionIds;
        }

        List<SessionSpeakerProduct__c> links;

        if (hasSpeakerIds && hasJobTitles) {
            links = [
                SELECT Session__c
                FROM SessionSpeakerProduct__c
                WHERE speakerContact__c IN :speakerIds
                AND speakerContact__r.JobTitle__c IN :speakerJobTitles
            ];
        } else if (hasSpeakerIds) {
            links = [
                SELECT Session__c
                FROM SessionSpeakerProduct__c
                WHERE speakerContact__c IN :speakerIds
            ];
        } else {
            links = [
                SELECT Session__c
                FROM SessionSpeakerProduct__c
                WHERE speakerContact__r.JobTitle__c IN :speakerJobTitles
            ];
        }

        for (SessionSpeakerProduct__c link : links) {
            if (link.Session__c != null) {
                sessionIds.add(link.Session__c);
            }
        }

        return sessionIds;
    }

    private static void applyColorsSafely(List<SObject> records, TraceLog t) {
        try {
            EventColorService.applyColorsInMemory((List<Event__c>) records);
        } catch (Exception ex) {
            if (t != null) {
                t.add('EventColorService skipped: ' + ex.getMessage());
            }
        }
    }

    private static EventDto buildDto(
        Event__c sourceEvent,
        String safeTitleField,
        String safeColorField,
        Boolean convertToTarget,
        String targetTimezone
    ) {
        Event__c eventForDto = sourceEvent;

        // La conversion repose sur la timezone portée par le record.
        if (convertToTarget) {
            eventForDto = EventTimezoneUtil.convertTimeZone(
                new List<Event__c>{ sourceEvent },
                targetTimezone
            )[0];
        }

        EventDto dto = new EventDto();
        dto.id = (String) eventForDto.Id;
        dto.sObjectId = eventForDto.Id;
        dto.recordTypeId = eventForDto.RecordTypeId;
        dto.salesTeam = eventForDto.SalesTeam__c;
        dto.parentEventId = eventForDto.ParentEvent__c;
        dto.category = eventForDto.category__c;
        Object tVal = eventForDto.get(safeTitleField);
        dto.title = (tVal == null) ? '(no title)' : String.valueOf(tVal);

        Object cVal = eventForDto.get(safeColorField);
        dto.color = (cVal == null) ? null : String.valueOf(cVal);
        dto.textColor = computeTextColor(dto.color);

        dto.start = toIsoLocal(eventForDto.startDate__c, eventForDto.startTime__c);
        dto.startIso = dto.start;
        dto.endStr = toIsoLocal(eventForDto.endDate__c, eventForDto.endTime__c);
        dto.endIso = dto.endStr;
        dto.timezone = String.isBlank(eventForDto.timezone__c) ? DEFAULT_TIMEZONE : eventForDto.timezone__c;

        return dto;
    }

    private static String toIsoLocal(Date d, String timeTxt) {
        if (d == null || String.isBlank(timeTxt)) {
            return null;
        }

        List<Integer> parts = parseHourMinute(timeTxt);
        if (parts == null) {
            return null;
        }

        Datetime dt = Datetime.newInstance(
            d.year(),
            d.month(),
            d.day(),
            parts[0],
            parts[1],
            0
        );

        return dt.format(ISO_FMT);
    }

    private static List<Integer> parseHourMinute(String timeTxt) {
        if (String.isBlank(timeTxt)) {
            return null;
        }

        List<String> parts = timeTxt.trim().split(':');
        if (parts.size() != 2) {
            return null;
        }

        try {
            Integer hh = Integer.valueOf(parts[0]);
            Integer mm = Integer.valueOf(parts[1]);

            if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
                return null;
            }

            return new List<Integer>{ hh, mm };
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer hexPairToInt(String pair) {
        if (String.isBlank(pair) || pair.length() != 2) {
            return 0;
        }

        String digits = '0123456789ABCDEF';
        String p = pair.toUpperCase();

        Integer hi = digits.indexOf(p.substring(0, 1));
        Integer lo = digits.indexOf(p.substring(1, 2));

        if (hi < 0 || lo < 0) {
            return 0;
        }
        return (hi * 16) + lo;
    }

    private static String computeTextColor(String hex) {
        if (String.isBlank(hex)) {
            return COLOR_BLACK;
        }

        String v = hex.trim();
        if (v.startsWith('#')) {
            v = v.substring(1);
        }

        if (v.length() == 3) {
            v = ''
                + v.substring(0, 1) + v.substring(0, 1)
                + v.substring(1, 2) + v.substring(1, 2)
                + v.substring(2, 3) + v.substring(2, 3);
        }

        if (v.length() != 6) {
            return COLOR_BLACK;
        }

        Integer r = hexPairToInt(v.substring(0, 2));
        Integer g = hexPairToInt(v.substring(2, 4));
        Integer b = hexPairToInt(v.substring(4, 6));

        Decimal luminance = (r * 0.299) + (g * 0.587) + (b * 0.114);
        return (luminance > 186) ? COLOR_BLACK : COLOR_WHITE;
    }

    @AuraEnabled(cacheable=true)
    public static String getEventPrefix() {
        return Event__c.SObjectType.getDescribe().getKeyPrefix();
    }


    @AuraEnabled(cacheable=true)
    public static List<EventColorLegendDto> getEventColors() {
        List<EventColorLegendDto> results = new List<EventColorLegendDto>();

        for (EventColors__c rec : [
            SELECT Id, Name, SalesTeam__c, meetingDays__c, oneToOne__c, Event__c
            FROM EventColors__c
            ORDER BY Name
        ]) {
            EventColorLegendDto dto = new EventColorLegendDto();
            dto.id = (String) rec.Id;
            dto.label = String.isBlank(rec.SalesTeam__c) ? rec.Name : rec.SalesTeam__c;
            dto.meetingDays = rec.meetingDays__c;
            dto.oneToOne = rec.oneToOne__c;
            dto.eventColor = rec.Event__c;
            results.add(dto);
        }

        return results;
    }
    @AuraEnabled(cacheable=true)
    public static List<Option> getSpeakerContacts(Id parentEventId) {
        List<Option> results = new List<Option>();
        List<Contact> contacts;

        if (parentEventId == null) {
            contacts = [
                SELECT Id, Name, JobTitle__c
                FROM Contact
                WHERE isValidSpeaker__c = true
              //  AND SpeakerAssistant__c != null
                ORDER BY Name
                LIMIT 2000
            ];
        } else {
            contacts = [
                SELECT Id, Name, JobTitle__c
                FROM Contact
                WHERE isValidSpeaker__c = true
                //AND SpeakerAssistant__c != null
                AND Id IN (
                    SELECT speakerContact__c
                    FROM sessionSpeakerProduct__c
                    WHERE Session__c = :parentEventId
                    AND speakerContact__c != null
                )
                ORDER BY Name
                LIMIT 2000
            ];
        }

        for (Contact c : contacts) {
            results.add(new Option((String) c.Id, c.Name, c.JobTitle__c));
        }

        return results;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String jobTitle;

        public Option(String value, String label, String jobTitle) {
            this.value = value;
            this.label = label;
            this.jobTitle = jobTitle;
        }
    }

    public class EventColorLegendDto {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String meetingDays;
        @AuraEnabled public String oneToOne;
        @AuraEnabled public String eventColor;
    }
}