public with sharing class VFC17_PrintEvents {

    private static final Integer COLS = 3;
    private static final Integer SLOTS_PER_COLUMN = 6;

    private static final String TZ_UTC00 = 'UTC+00';
    private static final String DEFAULT_EVENT_COLOR = '#2C3E50';
    private static final String DEFAULT_TITLE = '(Sans titre)';
    private static final String DEFAULT_MONTH_COLOR = '#34495E';

    public Date startDate { get; set; }
    public Date endDate   { get; set; }

    public String selectedTimezone { get; set; }
    public List<SelectOption> timezoneOptions { get; private set; }

    public List<PageVM> pages { get; private set; }

    public Boolean isPdf {
        get { return ApexPages.currentPage().getParameters().get('pdf') == '1'; }
    }

    public VFC17_PrintEvents() {
        startDate = parseDateParam('start', Date.today().toStartOfMonth());
        endDate   = parseDateParam('end',   Date.today().toStartOfMonth().addMonths(2).addDays(-1));

        buildTimezoneOptions();
        selectedTimezone = parseTzParam('tz', getUserUtcOffset());

        build();
    }

    public PageReference applyDates() {
        normalizeDateRange();
        build();
        return null;
    }

    public PageReference openPdf() {
        PageReference pr = Page.VFP17_PrintEvents_PDF;
        pr.getParameters().put('pdf', '1');

        if (startDate != null) pr.getParameters().put('start', String.valueOf(startDate));
        if (endDate != null)   pr.getParameters().put('end',   String.valueOf(endDate));
        if (!String.isBlank(selectedTimezone)) pr.getParameters().put('tz', selectedTimezone);

        pr.setRedirect(true);
        return pr;
    }

    // -----------------------
    // BUILD
    // -----------------------
    /**
     * Refactored to reduce Cognitive Complexity:
     * - Early-return checks delegated to helpers
     * - Data preparation split into dedicated methods
     * - Main build() becomes orchestration only
     */
    private void build() {
        pages = new List<PageVM>();

        if (hasMissingDates()) {
            ensureAtLeastOnePage();
            return;
        }

        List<Event__c> meetings = loadMeetings(startDate, endDate);
        if (meetings.isEmpty()) {
            ensureAtLeastOnePage();
            return;
        }

        BuildContext ctx = prepareBuildContext(meetings);

        packIntoPages(
            meetings,
            ctx.speakersByMeeting,
            ctx.conv.startConvById,
            ctx.conv.endConvById,
            ctx.conflictedMeetingIds,
            ctx.targetTz
        );
    }

    private Boolean hasMissingDates() {
        return startDate == null || endDate == null;
    }

    private void ensureAtLeastOnePage() {
        newPage();
    }

    private class BuildContext {
        String targetTz;
        Map<Id, List<String>> speakersByMeeting;
        ConversionData conv;
        Set<Id> conflictedMeetingIds;

        BuildContext() {
            speakersByMeeting = new Map<Id, List<String>>();
            conv = new ConversionData();
            conflictedMeetingIds = new Set<Id>();
        }
    }

    private BuildContext prepareBuildContext(List<Event__c> meetings) {
        BuildContext ctx = new BuildContext();

        EventColorService.applyColorsInMemory(meetings);

        Set<Id> meetingIds = new Map<Id, Event__c>(meetings).keySet();
        ctx.speakersByMeeting = loadSpeakersByMeeting(meetingIds);

        ctx.targetTz = normalizeTargetTz(selectedTimezone);

        ctx.conv = buildConversionData(meetings, ctx.targetTz);

        ctx.conflictedMeetingIds = detectSpeakerConflicts(
            meetings,
            ctx.conv.startConvById,
            ctx.conv.speakerSetByMeeting
        );

        return ctx;
    }

    /**
     * Normalizes and fixes common user input issues on the date range.
     */
    private void normalizeDateRange() {
        if (startDate == null && endDate == null) {
            startDate = Date.today().toStartOfMonth();
            endDate   = startDate.addMonths(2).addDays(-1);
        } else if (startDate == null) {
            startDate = endDate.addMonths(-1);
        } else if (endDate == null) {
            endDate = startDate.addMonths(1);
        }

        if (startDate != null && endDate != null && endDate < startDate) {
            Date tmp = startDate; startDate = endDate; endDate = tmp;
        }
    }

    /**
     * Loads events overlapping the date window.
     * Uses startDate__c/endDate__c (date overlap) and orders by (startDate__c, startTime__c).
     */
    private static List<Event__c> loadMeetings(Date startDate, Date endDate) {
        return [
            SELECT Id,
                RecordTypeId,
                SalesTeam__c,
                Color__c,
                Title__c,
                timezone__c,
                startDate__c,
                startTime__c,
                endDate__c,
                endTime__c
            FROM Event__c
            WHERE startDate__c != null
            AND endDate__c   != null
            AND startDate__c <= :endDate
            AND endDate__c   >= :startDate
            ORDER BY startDate__c ASC, startTime__c ASC
        ];
    }


    /**
     * Loads speakers per meeting and returns a sorted list of names per meeting.
     */
    private static Map<Id, List<String>> loadSpeakersByMeeting(Set<Id> meetingIds) {
        Map<Id, Set<String>> speakerSetByMeeting = new Map<Id, Set<String>>();
        if (meetingIds == null || meetingIds.isEmpty()) return new Map<Id, List<String>>();

        for (SessionSpeakerProduct__c link : [
            SELECT Session__c, speakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :meetingIds
        ]) {
            Id mid = link.Session__c;
            String name = (link.speakerContact__r == null) ? null : link.speakerContact__r.Name;

            if (mid == null || String.isBlank(name)) continue;

            Set<String> s = speakerSetByMeeting.get(mid);
            if (s == null) {
                s = new Set<String>();
                speakerSetByMeeting.put(mid, s);
            }
            s.add(name);
        }

        Map<Id, List<String>> speakersByMeeting = new Map<Id, List<String>>();
        for (Id mid : speakerSetByMeeting.keySet()) {
            List<String> l = new List<String>();
            l.addAll(speakerSetByMeeting.get(mid));
            l.sort();
            speakersByMeeting.put(mid, l);
        }
        return speakersByMeeting;
    }

    private class ConversionData {
        Map<Id, DateTime> startConvById;
        Map<Id, DateTime> endConvById;
        Map<Id, String> srcTzById;
        Map<Id, Set<String>> speakerSetByMeeting;

        ConversionData() {
            startConvById = new Map<Id, DateTime>();
            endConvById   = new Map<Id, DateTime>();
            srcTzById     = new Map<Id, String>();
            speakerSetByMeeting = new Map<Id, Set<String>>();
        }
    }

   /**
     * Precomputes start/end conversions to the target timezone and caches source tz.
     * Now based on startDate__c/startTime__c and endDate__c/endTime__c.
     */
    private static ConversionData buildConversionData(List<Event__c> meetings, String tgtTz) {
        ConversionData data = new ConversionData();

        for (Event__c e : meetings) {
            String srcTz = String.isBlank(e.timezone__c) ? TZ_UTC00 : e.timezone__c;
            data.srcTzById.put(e.Id, srcTz);

            DateTime startBase = buildBaseDateTime(e.startDate__c, e.startTime__c);
            DateTime endBase   = buildBaseDateTime(e.endDate__c,   e.endTime__c);

            if (startBase != null) {
                data.startConvById.put(e.Id, convertUtcOffset(startBase, srcTz, tgtTz));
            }
            if (endBase != null) {
                data.endConvById.put(e.Id, convertUtcOffset(endBase, srcTz, tgtTz));
            }
        }

        data.speakerSetByMeeting = loadSpeakerSetByMeeting(new Map<Id, Event__c>(meetings).keySet());
        return data;
    }


    /**
     * Loads speakers as sets per meeting (used for conflict detection).
     */
    private static Map<Id, Set<String>> loadSpeakerSetByMeeting(Set<Id> meetingIds) {
        Map<Id, Set<String>> speakerSetByMeeting = new Map<Id, Set<String>>();
        if (meetingIds == null || meetingIds.isEmpty()) return speakerSetByMeeting;

        for (SessionSpeakerProduct__c link : [
            SELECT Session__c, speakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :meetingIds
        ]) {
            Id mid = link.Session__c;
            String name = (link.speakerContact__r == null) ? null : link.speakerContact__r.Name;

            if (mid == null || String.isBlank(name)) continue;

            Set<String> s = speakerSetByMeeting.get(mid);
            if (s == null) {
                s = new Set<String>();
                speakerSetByMeeting.put(mid, s);
            }
            s.add(name);
        }

        return speakerSetByMeeting;
    }

    /**
     * Detects conflicts when a speaker is booked on more than one meeting at the same converted start time.
     */
    private static Set<Id> detectSpeakerConflicts(
        List<Event__c> meetings,
        Map<Id, DateTime> startConvById,
        Map<Id, Set<String>> speakerSetByMeeting
    ) {
        // Index: startTime -> speakerName -> list(meetingId)
        Map<DateTime, Map<String, List<Id>>> conflictIndex = new Map<DateTime, Map<String, List<Id>>>();

        if (meetings == null || meetings.isEmpty()) {
            return new Set<Id>();
        }

        // Build the conflict index
        for (Event__c meeting : meetings) {
            addMeetingToConflictIndex(meeting, startConvById, speakerSetByMeeting, conflictIndex);
        }

        // Extract conflicted meeting ids from the index
        return collectConflictedMeetingIds(conflictIndex);
    }

    /**
     * Adds a single meeting into the conflict index if it has a valid start time and speakers.
     */
    private static void addMeetingToConflictIndex(
        Event__c meeting,
        Map<Id, DateTime> startConvById,
        Map<Id, Set<String>> speakerSetByMeeting,
        Map<DateTime, Map<String, List<Id>>> conflictIndex
    ) {
        if (meeting == null || meeting.Id == null) {
            return;
        }

        DateTime startKey = startConvById.get(meeting.Id);
        if (startKey == null) {
            return;
        }

        Set<String> speakers = (speakerSetByMeeting == null)
            ? null
            : speakerSetByMeeting.get(meeting.Id);
        if (speakers == null || speakers.isEmpty()) {
            return;
        }

        Map<String, List<Id>> bySpeaker = getOrCreateSpeakerIndex(conflictIndex, startKey);

        for (String sp : speakers) {
            addSpeakerMeeting(bySpeaker, sp, meeting.Id);
        }
    }

    /**
     * Returns the speaker index for a given start time, creating it if needed.
     */
    private static Map<String, List<Id>> getOrCreateSpeakerIndex(
        Map<DateTime, Map<String, List<Id>>> conflictIndex,
        DateTime startKey
    ) {
        Map<String, List<Id>> bySpeaker = conflictIndex.get(startKey);
        if (bySpeaker == null) {
            bySpeaker = new Map<String, List<Id>>();
            conflictIndex.put(startKey, bySpeaker);
        }
        return bySpeaker;
    }

    /**
     * Adds the meeting to the speaker's list if the speaker name is not blank.
     */
    private static void addSpeakerMeeting(
        Map<String, List<Id>> bySpeaker,
        String speakerName,
        Id meetingId
    ) {
        if (String.isBlank(speakerName)) {
            return;
        }

        List<Id> meetingIds = bySpeaker.get(speakerName);
        if (meetingIds == null) {
            meetingIds = new List<Id>();
            bySpeaker.put(speakerName, meetingIds);
        }
        meetingIds.add(meetingId);
    }

    /**
     * Traverses the conflict index to collect all meetings that are in conflict.
     */
    private static Set<Id> collectConflictedMeetingIds(
        Map<DateTime, Map<String, List<Id>>> conflictIndex
    ) {
        Set<Id> conflictedMeetingIds = new Set<Id>();

        for (DateTime dt : conflictIndex.keySet()) {
            Map<String, List<Id>> bySpeaker = conflictIndex.get(dt);
            addConflictsForTimeSlot(bySpeaker, conflictedMeetingIds);
        }

        return conflictedMeetingIds;
    }

    /**
     * Adds all meetings where a speaker has more than one meeting at the same time.
     */
    private static void addConflictsForTimeSlot(
        Map<String, List<Id>> bySpeaker,
        Set<Id> conflictedMeetingIds
    ) {
        if (bySpeaker == null || bySpeaker.isEmpty()) {
            return;
        }

        for (String sp : bySpeaker.keySet()) {
            List<Id> meetingIds = bySpeaker.get(sp);
            if (meetingIds != null && meetingIds.size() > 1) {
                conflictedMeetingIds.addAll(meetingIds);
            }
        }
    }


    /**
     * Packs blocks into pages/columns while inserting month banners and respecting slot limits.
     */
    private void packIntoPages(
        List<Event__c> meetings,
        Map<Id, List<String>> speakersByMeeting,
        Map<Id, DateTime> startConvById,
        Map<Id, DateTime> endConvById,
        Set<Id> conflictedMeetingIds,
        String tgtTz
    ) {
        PagePacker packer = new PagePacker(this);

        Integer lastMonthKey = -1;
        for (Event__c e : meetings) {
            DateTime startConv = startConvById.get(e.Id);
            if (startConv == null) continue;

            Date d = startConv.date();
            Integer monthKey = d.year() * 100 + d.month();

            if (monthKey != lastMonthKey) {
                packer.ensureSlots(2);
                packer.addMonthBanner(formatMonthLabel(d), monthColor(d.month()));
                lastMonthKey = monthKey;
            }

            packer.ensureSlots(1);

            String title = String.isBlank(e.Title__c) ? DEFAULT_TITLE : e.Title__c;
            String speakers = buildSpeakersLabel(e.Id, speakersByMeeting);
            String color = String.isBlank(e.Color__c) ? DEFAULT_EVENT_COLOR : e.Color__c;

            DateTime endConv = endConvById.get(e.Id);
            String timeRange = buildTimeRange(startConv, endConv);

            Boolean hasConflict = conflictedMeetingIds != null && conflictedMeetingIds.contains(e.Id);

            packer.addEventBlock(
                formatDayLabel(startConv),
                timeRange,
                title,
                speakers,
                color,
                tgtTz,
                hasConflict
            );
        }
    }

    private static String buildSpeakersLabel(Id meetingId, Map<Id, List<String>> speakersByMeeting) {
        if (meetingId == null || speakersByMeeting == null) return '';
        List<String> l = speakersByMeeting.get(meetingId);
        return (l == null || l.isEmpty()) ? '' : String.join(l, ', ');
    }

    private static String normalizeTargetTz(String selectedTimezone) {
        return String.isBlank(selectedTimezone) ? TZ_UTC00 : selectedTimezone;
    }

    // -----------------------
    // FACTORIES
    // -----------------------
    private static PrintBlockVM createMonthBanner(String label, String color) {
        PrintBlockVM b = new PrintBlockVM();
        b.isMonthBanner = true;
        b.monthLabel = label;
        b.monthColor = color;
        return b;
    }

    private static PrintBlockVM createEventBlock(
        String dayLabel,
        String timeRange,
        String title,
        String speakers,
        String color,
        String displayTz,
        Boolean isSpeakerConflict
    ) {
        PrintBlockVM b = new PrintBlockVM();
        b.isMonthBanner = false;
        b.dayLabel = dayLabel;
        b.timeRangeLabel = timeRange;
        b.title = title;
        b.speakersLabel = speakers;
        b.eventColor = color;
        b.displayTimezone = displayTz;
        b.isSpeakerConflict = isSpeakerConflict;
        return b;
    }

    // -----------------------
    // PAGE/COLUMN MANAGEMENT
    // -----------------------
    private PageVM newPage() {
        PageVM p = new PageVM();
        p.columns = new List<ColumnVM>();
        for (Integer i = 0; i < COLS; i++) {
            ColumnVM c = new ColumnVM();
            c.blocks = new List<PrintBlockVM>();
            p.columns.add(c);
        }
        pages.add(p);
        return p;
    }

    private class ColumnMoveResult {
        PageVM page;
        Integer colIndex;
        Integer remainingSlots;
        ColumnMoveResult(PageVM p, Integer c, Integer r) {
            page = p; colIndex = c; remainingSlots = r;
        }
    }

    private ColumnMoveResult moveToNextColumnOrPage(PageVM currentPage, Integer colIndex) {
        Integer nextCol = colIndex + 1;
        if (nextCol >= COLS) {
            PageVM newP = newPage();
            return new ColumnMoveResult(newP, 0, SLOTS_PER_COLUMN);
        }
        return new ColumnMoveResult(currentPage, nextCol, SLOTS_PER_COLUMN);
    }

    /**
     * Small helper that manages current page/column and available slots.
     */
    private class PagePacker {
        private VFC17_PrintEvents ctrl;
        private PageVM currentPage;
        private Integer colIndex;
        private Integer remainingSlots;

        PagePacker(VFC17_PrintEvents c) {
            ctrl = c;
            currentPage = ctrl.newPage();
            colIndex = 0;
            remainingSlots = SLOTS_PER_COLUMN;
        }

        void ensureSlots(Integer needed) {
            if (remainingSlots >= needed) return;
            ColumnMoveResult moveRes = ctrl.moveToNextColumnOrPage(currentPage, colIndex);
            currentPage = moveRes.page;
            colIndex = moveRes.colIndex;
            remainingSlots = moveRes.remainingSlots;
        }

        void addMonthBanner(String label, String color) {
            currentPage.columns[colIndex].blocks.add(createMonthBanner(label, color));
            remainingSlots -= 1;
        }

        void addEventBlock(
            String dayLabel,
            String timeRange,
            String title,
            String speakers,
            String color,
            String displayTz,
            Boolean isSpeakerConflict
        ) {
            currentPage.columns[colIndex].blocks.add(
                createEventBlock(dayLabel, timeRange, title, speakers, color, displayTz, isSpeakerConflict)
            );
            remainingSlots -= 1;
        }
    }

    // -----------------------
    // HELPERS
    // -----------------------
    private static Date parseDateParam(String key, Date defaultVal) {
        String v = ApexPages.currentPage().getParameters().get(key);
        if (String.isBlank(v)) return defaultVal;
        try { return Date.valueOf(v); } catch (Exception e) { return defaultVal; }
    }

    private static String parseTzParam(String key, String defaultVal) {
        String v = ApexPages.currentPage().getParameters().get(key);
        return String.isBlank(v) ? defaultVal : v;
    }

    private static DateTime midnight(Date d) {
        return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
    }

    private static String formatDayLabel(DateTime dt) {
        return dt.format('EEE dd/MM/yyyy');
    }

    private static String formatMonthLabel(Date d) {
        Date first = Date.newInstance(d.year(), d.month(), 1);
        return DateTime.newInstance(first, Time.newInstance(0,0,0,0)).format('MMMM yyyy');
    }

    private static String monthColor(Integer monthNumber) {
        Map<Integer, String> colors = new Map<Integer, String>{
            1 => '#2E86AB', 2 => '#8E44AD', 3 => '#16A085', 4 => '#D35400',
            5 => '#27AE60', 6 => '#C0392B', 7 => '#2980B9', 8 => '#7F8C8D',
            9 => '#2C3E50', 10 => '#9B59B6', 11 => '#1ABC9C', 12 => '#E67E22'
        };
        return colors.containsKey(monthNumber) ? colors.get(monthNumber) : DEFAULT_MONTH_COLOR;
    }

    private static String buildTimeRange(DateTime startConv, DateTime endConv) {
        if (startConv == null && endConv == null) return '';
        if (startConv != null && endConv != null) return startConv.format('HH:mm') + ' - ' + endConv.format('HH:mm');
        if (startConv != null) return startConv.format('HH:mm');
        return endConv.format('HH:mm');
    }

    // -----------------------
    // TIMEZONE UTILS (UTC±HH)
    // -----------------------
    private static String twoDigits(Integer v) {
        if (v == null) return '00';
        return (v < 10 ? '0' : '') + String.valueOf(v);
    }

    private void buildTimezoneOptions() {
        timezoneOptions = new List<SelectOption>();
        for (Integer h = -12; h <= 14; h++) {
            String sign = (h >= 0) ? '+' : '-';
            String abs = twoDigits(Math.abs(h));
            String v = 'UTC' + sign + abs;
            timezoneOptions.add(new SelectOption(v, v));
        }
    }

    private static String getUserUtcOffset() {
        String tzKey = UserInfo.getTimeZone().getID();
        TimeZone tz = TimeZone.getTimeZone(tzKey);

        DateTime ref = DateTime.newInstance(Date.today(), Time.newInstance(12, 0, 0, 0));
        Integer offsetMs = tz.getOffset(ref);
        Integer offsetMin = offsetMs / 60000;

        Integer hh = Math.abs(offsetMin) / 60;
        String sign = (offsetMin >= 0) ? '+' : '-';

        return 'UTC' + sign + twoDigits(hh);
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
        try { hh = Integer.valueOf(hhStr); }
        catch (Exception e) { return null; }

        return sign * hh * 60;
    }

    private static DateTime convertUtcOffset(DateTime base, String srcTz, String tgtTz) {
        if (base == null) return null;

        Integer srcMin = parseUtcOffsetMinutes(srcTz);
        if (srcMin == null) srcMin = 0;

        Integer tgtMin = parseUtcOffsetMinutes(tgtTz);
        if (tgtMin == null) tgtMin = 0;

        Integer deltaMin = tgtMin - srcMin;
        return base.addMinutes(deltaMin);
    }

    // -----------------------
    // VIEW MODELS
    // -----------------------
    public class PageVM { public List<ColumnVM> columns { get; set; } }
    public class ColumnVM { public List<PrintBlockVM> blocks { get; set; } }

    public class PrintBlockVM {
        public Boolean isMonthBanner { get; set; }
        public String monthLabel { get; set; }
        public String monthColor { get; set; }

        public String dayLabel { get; set; }
        public String timeRangeLabel { get; set; }
        public String title { get; set; }
        public String speakersLabel { get; set; }
        public String eventColor { get; set; }
        public String displayTimezone { get; set; }

        public Boolean isSpeakerConflict { get; set; }
    }

    private class TimeParts {
        Integer hh;
        Integer mm;
        Integer ss;
        TimeParts(Integer h, Integer m, Integer s) { hh = h; mm = m; ss = s; }
    }

    private static DateTime buildBaseDateTime(Date d, String timeTxt) {
        if (d == null || String.isBlank(timeTxt)) return null;

        TimeParts tp = parseTimePartsSafe(timeTxt);
        if (tp == null) return null;

        return DateTime.newInstance(d, Time.newInstance(tp.hh, tp.mm, tp.ss, 0));
    }

    private static TimeParts parseTimePartsSafe(String timeTxt) {
        List<Integer> parts = parseTimeParts(timeTxt);
        if (parts == null || parts.size() < 2) return null;

        Integer hh = parts[0];
        Integer mm = parts[1];
        Integer ss = (parts.size() >= 3) ? parts[2] : 0;

        if (hh == null || mm == null || hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;
        if (ss == null || ss < 0 || ss > 59) ss = 0;

        return new TimeParts(hh, mm, ss);
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

}