public without sharing class VFC18_EventAgenda {

    private static final String PARAM_EVENT_ID  = 'EventId';
    private static final String PARAM_SHOW_NOTE = 'SMN';

    private static final String TZ_UTC00 = 'UTC+00';
    private static final String DEFAULT_TITLE = '(Sans titre)';

    public Id parentEventId { get; private set; }
    public Boolean showMeetingNote { get; private set; }

    public ParentVM parent { get; private set; }
    public List<DayGroupVM> days { get; private set; }
    public String errorMessage { get; private set; }

    public VFC18_EventAgenda() {
        days = new List<DayGroupVM>();

        parentEventId = (Id) ApexPages.currentPage().getParameters().get(PARAM_EVENT_ID);
        showMeetingNote = parseBool(ApexPages.currentPage().getParameters().get(PARAM_SHOW_NOTE), false);

        if (parentEventId == null) {
            errorMessage = 'Missing required URL parameter: EventId';
            return;
        }

        loadData();
    }

    // -----------------------
    // Data loading
    // -----------------------
    private void loadData() {
        System.debug(LoggingLevel.INFO, '======VFC18_EventAgenda.loadData - parentEventId=' + parentEventId);

        // 1) Parent
        Event__c p = [
            SELECT Id,
                   Title__c,
                   Company__c,
                   Company__r.Name,
                   Timezone__c,
                   StartDate__c,
                   StartTime__c,
                   EndDate__c,
                   EndTime__c,
                   SalesTeam__c,
                   MeetingBackground__c,
                   MeetingGoal__c
            FROM Event__c
            WHERE Id = :parentEventId
            LIMIT 1
        ];

        String targetTz = String.isBlank(p.Timezone__c) ? TZ_UTC00 : p.Timezone__c;

        parent = new ParentVM();
        parent.id = p.Id;
        parent.title = safeStr(p.Title__c);
        parent.company = (p.Company__r != null) ? safeStr(p.Company__r.Name) : '';
        parent.timezone = targetTz;
        parent.salesTeam = safeStr(p.SalesTeam__c);
        parent.meetingBackground = safeStr(p.MeetingBackground__c);
        parent.meetingGoal = safeStr(p.MeetingGoal__c);

        DateTime pStart = buildDateTime(p.StartDate__c, p.StartTime__c);
        DateTime pEnd   = buildDateTime(p.EndDate__c,   p.EndTime__c);

        parent.startLabel = (pStart == null) ? '' : pStart.format('dd/MM/yyyy HH:mm');
        parent.endLabel   = (pEnd   == null) ? '' : pEnd.format('dd/MM/yyyy HH:mm');

        // 2) Children (ORDER BY start date/time)
        List<Event__c> children = [
            SELECT Id,
                   Title__c,
                   StartDate__c,
                   StartTime__c,
                   EndDate__c,
                   EndTime__c,
                   Timezone__c,
                   MeetingBackground__c,
                   MeetingGoal__c,                   
                   MeetingNote__c,
                   MeetingNote__r.Note__c
            FROM Event__c
            WHERE ParentEvent__c = :parentEventId
            ORDER BY StartDate__c ASC, StartTime__c ASC
        ];

        System.debug(LoggingLevel.INFO, '======children.size=' + children.size());

        Set<Id> childIds = new Set<Id>();
        for (Event__c c : children) childIds.add(c.Id);

        // 3) Preload ALL required data (attendees + speakers/products)
        AccessData acc = testAccessibility(childIds);
        if (acc == null) {
            if (String.isBlank(errorMessage)) errorMessage = 'Guest access error (unknown).';
            return;
        }

        // 4) Group by converted day and build rows
        Map<Date, DayGroupVM> byDay = new Map<Date, DayGroupVM>();

        for (Event__c c : children) {
            String srcTz = String.isBlank(c.Timezone__c) ? targetTz : c.Timezone__c;

            DateTime childStart = buildDateTime(c.StartDate__c, c.StartTime__c);
            DateTime childEnd   = buildDateTime(c.EndDate__c,   c.EndTime__c);

            DateTime startConv = convertUtcOffset(childStart, srcTz, targetTz);
            DateTime endConv   = convertUtcOffset(childEnd,   srcTz, targetTz);

            if (startConv == null) continue;

            Date dayKey = startConv.date();

            DayGroupVM g = byDay.get(dayKey);
            if (g == null) {
                g = new DayGroupVM();
                g.day = dayKey;
                g.dayLabel = formatDaySeparator(dayKey);
                g.rows = new List<RowVM>();
                byDay.put(dayKey, g);
            }

            RowVM r = new RowVM();
            r.startSort = startConv;
            r.timeRange = buildTimeRange(startConv, endConv);
            r.title = String.isBlank(c.Title__c) ? DEFAULT_TITLE : c.Title__c;

            r.bgGoal = buildBgGoalLabel(safeStr(c.MeetingBackground__c), safeStr(c.MeetingGoal__c));
           r.note = (c.MeetingNote__r != null) ? safeStr(c.MeetingNote__r.Note__c) : '-';

            r.attendees = acc.attendeesByEvent.containsKey(c.Id)
                ? acc.attendeesByEvent.get(c.Id)
                : new List<String>();

            r.speakers = acc.speakersByEvent.containsKey(c.Id)
                ? acc.speakersByEvent.get(c.Id)
                : new List<SpeakerLineVM>();

            g.rows.add(r);
        }

        // 5) Sort rows INSIDE each day by start datetime
        for (DayGroupVM g : byDay.values()) {
            if (g.rows != null && !g.rows.isEmpty()) {
                g.rows.sort(new RowStartComparator());
            }
        }

        // 6) Sort days and add to output list
        List<Date> keys = new List<Date>();
        keys.addAll(byDay.keySet());
        keys.sort();

        for (Date d : keys) {
            days.add(byDay.get(d));
        }

        System.debug(LoggingLevel.INFO, '======days.size=' + days.size());
    }

    // -----------------------
    // Accessibility test / preload data
    // -----------------------
    private class AccessData {
        Map<Id, List<String>> attendeesByEvent;
        Map<Id, List<SpeakerLineVM>> speakersByEvent;

        AccessData() {
            attendeesByEvent = new Map<Id, List<String>>();
            speakersByEvent = new Map<Id, List<SpeakerLineVM>>();
        }
    }

    /**
     * Runs ALL queries required for the page (attendees, speakers/products) and returns preloaded maps.
     * If any query fails (Guest permissions), sets errorMessage and returns null.
     */
    private AccessData testAccessibility(Set<Id> childIds) {
        AccessData data = new AccessData();
        if (childIds == null) childIds = new Set<Id>();

        // 1) Attendees
        List<EventAttendee__c> attendeeLinks;
        try {
            attendeeLinks = [
                SELECT Id, Event__c, Contact__c
                FROM EventAttendee__c
                WHERE Event__c IN :childIds
            ];
            System.debug(LoggingLevel.INFO, '======attendeeLinks.size=' + attendeeLinks.size());
        } catch (Exception e) {
            errorMessage = 'Access error on EventAttendee__c query: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, e);
            return null;
        }

        Set<Id> attendeeContactIds = new Set<Id>();
        for (EventAttendee__c a : attendeeLinks) if (a.Contact__c != null) attendeeContactIds.add(a.Contact__c);

        Map<Id, String> contactNameById = new Map<Id, String>();
        if (!attendeeContactIds.isEmpty()) {
            try {
                for (Contact c : [
                    SELECT Id, FirstName, LastName
                    FROM Contact
                    WHERE Id IN :attendeeContactIds
                ]) {
                    String fn = (c.FirstName == null) ? '' : c.FirstName;
                    String ln = (c.LastName == null) ? '' : c.LastName;
                    String fullName = String.join(new List<String>{fn, ln}, ' ').trim();
                    contactNameById.put(c.Id, String.isBlank(fullName) ? 'Attendee' : fullName);
                }
            } catch (Exception e) {
                // Best effort only
                System.debug(LoggingLevel.WARN, 'Cannot read Contact (attendees): ' + e.getMessage());
            }
        }

        for (EventAttendee__c a : attendeeLinks) {
            if (a.Event__c == null) continue;

            if (!data.attendeesByEvent.containsKey(a.Event__c)) {
                data.attendeesByEvent.put(a.Event__c, new List<String>());
            }

            String label = 'Attendee';
            if (a.Contact__c != null && contactNameById.containsKey(a.Contact__c)) {
                label = contactNameById.get(a.Contact__c);
            }

            data.attendeesByEvent.get(a.Event__c).add(label);
        }

        for (Id eid : data.attendeesByEvent.keySet()) {
            data.attendeesByEvent.get(eid).sort();
        }

        // 2) Speaker/Product links
        List<SessionSpeakerProduct__c> links;
        try {
            links = [
                SELECT Session__c, SpeakerContact__c, Product__c
                FROM SessionSpeakerProduct__c
                WHERE Session__c IN :childIds
            ];
            System.debug(LoggingLevel.INFO, '======speakerProductLinks.size=' + links.size());
        } catch (Exception e) {
            errorMessage = 'Access error on SessionSpeakerProduct__c query: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, e);
            return null;
        }

        // Group: session -> speakerId -> set(productIds)
        Map<Id, Map<Id, Set<Id>>> tmp = new Map<Id, Map<Id, Set<Id>>>();
        Set<Id> speakerIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();

        for (SessionSpeakerProduct__c l : links) {
            if (l.Session__c == null) continue;

            if (!tmp.containsKey(l.Session__c)) tmp.put(l.Session__c, new Map<Id, Set<Id>>());
            Map<Id, Set<Id>> bySpeaker = tmp.get(l.Session__c);

            Id spId = l.SpeakerContact__c;
            if (!bySpeaker.containsKey(spId)) bySpeaker.put(spId, new Set<Id>());

            if (spId != null) speakerIds.add(spId);

            if (l.Product__c != null) {
                bySpeaker.get(spId).add(l.Product__c);
                productIds.add(l.Product__c);
            }
        }

        // Resolve speaker names (best effort)
        Map<Id, String> speakerNameById = new Map<Id, String>();
        if (!speakerIds.isEmpty()) {
            try {
                for (Contact c : [SELECT Id, Name FROM Contact WHERE Id IN :speakerIds]) {
                    speakerNameById.put(c.Id, c.Name);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Cannot read Contact (speakers): ' + e.getMessage());
            }
        }

        // Resolve Product__c names (best effort)
        Map<Id, String> productNameById = new Map<Id, String>();
        if (!productIds.isEmpty()) {
            try {
                for (Product__c p : [
                    SELECT Id, Name
                    FROM Product__c
                    WHERE Id IN :productIds
                ]) {
                    productNameById.put(p.Id, p.Name);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Cannot read Product__c: ' + e.getMessage());
            }
        }

        // Build speakersByEvent
        for (Id sessionId : tmp.keySet()) {
            Map<Id, Set<Id>> bySpeaker = tmp.get(sessionId);

            List<SpeakerLineVM> lines = new List<SpeakerLineVM>();

            // Sort speakers by resolved name (best effort)
            List<Id> spKeys = new List<Id>();
            spKeys.addAll(bySpeaker.keySet());
            spKeys.sort();

            for (Id spId : spKeys) {
                String spName = (spId != null && speakerNameById.containsKey(spId))
                    ? speakerNameById.get(spId)
                    : '-';

                // Only resolved product names; no "Product" fallback
                Set<String> prodSet = new Set<String>();
                for (Id pid : bySpeaker.get(spId)) {
                    if (pid != null && productNameById.containsKey(pid)) {
                        prodSet.add(productNameById.get(pid));
                    }
                }

                List<String> prodNames = new List<String>();
                prodNames.addAll(prodSet);
                prodNames.sort();

                SpeakerLineVM line = new SpeakerLineVM();
                line.speakerName = spName;
                line.productsLabel = prodNames.isEmpty() ? '' : String.join(prodNames, ', ');

                lines.add(line);
            }

            data.speakersByEvent.put(sessionId, lines);
        }

        return data;
    }

    // -----------------------
    // Date+Time helpers
    // -----------------------
    private static DateTime buildDateTime(Date d, Time t) {
        if (d == null) return null;
        if (t == null) t = Time.newInstance(0, 0, 0, 0);
        return DateTime.newInstance(d, t);
    }

    private static DateTime buildDateTime(Date d, String timeStr) {
        if (d == null) return null;
        Time t = parseTime(timeStr);
        if (t == null) t = Time.newInstance(0, 0, 0, 0);
        return DateTime.newInstance(d, t);
    }

    private static Time parseTime(String v) {
        if (String.isBlank(v)) return null;
        try {
            List<String> parts = v.split(':');
            Integer h = Integer.valueOf(parts[0]);
            Integer m = (parts.size() > 1) ? Integer.valueOf(parts[1]) : 0;
            Integer s = (parts.size() > 2) ? Integer.valueOf(parts[2]) : 0;
            return Time.newInstance(h, m, s, 0);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Invalid time string: ' + v);
            return null;
        }
    }

    // -----------------------
    // Formatting helpers
    // -----------------------
    private static String safeStr(Object o) {
        return (o == null) ? '' : String.valueOf(o);
    }

    private static String buildBgGoalLabel(String bg, String goal) {
        List<String> parts = new List<String>();
        if (!String.isBlank(bg)) parts.add('Meeting Background:\n' + bg);
        if (!String.isBlank(goal)) parts.add('Meeting Goal:\n' + goal);
        return String.join(parts, '\n\n');
    }

    private static String buildTimeRange(DateTime startConv, DateTime endConv) {
        if (startConv == null && endConv == null) return '';
        if (startConv != null && endConv != null) return startConv.format('HH:mm') + ' - ' + endConv.format('HH:mm');
        if (startConv != null) return startConv.format('HH:mm');
        return endConv.format('HH:mm');
    }

    private static String formatDaySeparator(Date d) {
        DateTime noon = DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        String dow = noon.format('EEEE');
        String mon = noon.format('MMMM');
        Integer dayNum = d.day();
        return dow + ' ' + String.valueOf(dayNum) + ordinalSuffix(dayNum) + ' ' + mon;
    }

    private static String ordinalSuffix(Integer n) {
        if (n == null) return '';
        Integer mod100 = Math.mod(n, 100);
        if (mod100 >= 11 && mod100 <= 13) return 'th';
        Integer mod10 = Math.mod(n, 10);
        if (mod10 == 1) return 'st';
        if (mod10 == 2) return 'nd';
        if (mod10 == 3) return 'rd';
        return 'th';
    }

    private static Boolean parseBool(String v, Boolean defaultVal) {
        if (String.isBlank(v)) return defaultVal;
        String s = v.trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
        if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
        return defaultVal;
    }

    // -----------------------
    // Timezone conversion: UTC±HH only
    // -----------------------
    private static Integer parseUtcOffsetMinutes(String tzApi) {
        if (String.isBlank(tzApi)) return 0;
        String v = tzApi.trim().toUpperCase();
        if (!v.startsWith('UTC')) return 0; // e.g. Europe/Paris -> no conversion
        Integer idxPlus = v.indexOf('+');
        Integer idxMinus = v.indexOf('-');
        Integer sign = 1;
        Integer idx;
        if (idxPlus > -1) { sign = 1; idx = idxPlus; }
        else if (idxMinus > -1) { sign = -1; idx = idxMinus; }
        else { return 0; }

        String hhStr = v.substring(idx + 1);
        Integer hh;
        try { hh = Integer.valueOf(hhStr); }
        catch (Exception e) { return 0; }

        return sign * hh * 60;
    }

    private static DateTime convertUtcOffset(DateTime base, String srcTz, String tgtTz) {
        if (base == null) return null;
        Integer srcMin = parseUtcOffsetMinutes(srcTz);
        Integer tgtMin = parseUtcOffsetMinutes(tgtTz);
        Integer deltaMin = tgtMin - srcMin;
        return base.addMinutes(deltaMin);
    }

    // -----------------------
    // Comparator: sort rows by start datetime (within each day)
    // -----------------------
    private class RowStartComparator implements Comparator<RowVM> {
        public Integer compare(RowVM a, RowVM b) {
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;

            DateTime da = a.startSort;
            DateTime db = b.startSort;

            if (da == null && db == null) return 0;
            if (da == null) return 1;   // nulls at bottom
            if (db == null) return -1;

            if (da == db) return 0;
            return (da < db) ? -1 : 1;
        }
    }

    // -----------------------
    // View models
    // -----------------------
    public class ParentVM {
        public Id id { get; set; }
        public String title { get; set; }
        public String company { get; set; }
        public String timezone { get; set; }
        public String startLabel { get; set; }
        public String endLabel { get; set; }
        public String salesTeam { get; set; }
        public String meetingBackground { get; set; }
        public String meetingGoal { get; set; }
    }

    public class DayGroupVM {
        public Date day { get; set; }
        public String dayLabel { get; set; }
        public List<RowVM> rows { get; set; }
    }

    public class SpeakerLineVM {
        public String speakerName { get; set; }
        public String productsLabel { get; set; }
    }

    public class RowVM {
        public String timeRange { get; set; }
        public String title { get; set; }
        public String bgGoal { get; set; }
        public String note { get; set; }

        public List<String> attendees { get; set; }
        public List<SpeakerLineVM> speakers { get; set; }

        public DateTime startSort { get; set; }
    }
}