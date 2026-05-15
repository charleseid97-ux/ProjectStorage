public with sharing class VFC17_PrintEvents {

    private static final Integer COLS = 3;
    private static final Integer SLOTS_PER_COLUMN = 10000;

    private static final String DEFAULT_EVENT_COLOR = '#2C3E50';
    private static final String DEFAULT_TITLE = '(Sans titre)';
    private static final String ALL_SALES_TEAMS = '__ALL__';

    public Date startDate { get; set; }
    public Date endDate { get; set; }

    public String selectedSalesTeam { get; set; }
    public List<SelectOption> salesTeamOptions { get; private set; }

    public List<PageVM> pages { get; private set; }

    public Boolean isPdf {
        get { return ApexPages.currentPage().getParameters().get('pdf') == '1'; }
    }

    public VFC17_PrintEvents() {
        startDate = parseDateParam('start', Date.today().toStartOfMonth());
        endDate = parseDateParam('end', Date.today().toStartOfMonth().addMonths(2).addDays(-1));
        selectedSalesTeam = parseSalesTeamParam('salesTeam', ALL_SALES_TEAMS);
        buildSalesTeamOptions();

        build();
    }

    public PageReference applyDates() {
        normalizeDateRange();
        buildSalesTeamOptions();
        build();
        return null;
    }

    public PageReference openPdf() {
        PageReference pr = Page.VFP17_PrintEvents_PDF;
        pr.getParameters().put('pdf', '1');

        if (startDate != null) {
            pr.getParameters().put('start', String.valueOf(startDate));
        }
        if (endDate != null) {
            pr.getParameters().put('end', String.valueOf(endDate));
        }
        if (!String.isBlank(selectedSalesTeam) && selectedSalesTeam != ALL_SALES_TEAMS) {
            pr.getParameters().put('salesTeam', selectedSalesTeam);
        }

        pr.setRedirect(true);
        return pr;
    }

    // -----------------------
    // BUILD
    // -----------------------
    private void build() {
        pages = new List<PageVM>();

        if (startDate == null || endDate == null) {
            ensureAtLeastOnePage();
            return;
        }

        List<Event__c> meetings = loadMeetings(startDate, endDate, selectedSalesTeam);
        if (meetings.isEmpty()) {
            ensureAtLeastOnePage();
            return;
        }

        EventColorService.applyColorsInMemory(meetings);

        Set<Id> meetingIds = new Map<Id, Event__c>(meetings).keySet();
        Map<Id, MeetingMeta> metaByMeeting = loadMeetingMeta(meetingIds);
        Set<Id> conflictedMeetingIds = detectSpeakerConflicts(meetings, metaByMeeting);

        List<DayGroupVM> dayGroups = buildDayGroups(meetings, metaByMeeting, conflictedMeetingIds);
        packDayGroupsIntoPages(dayGroups);

        if (pages.isEmpty()) {
            ensureAtLeastOnePage();
        }
    }

    private void ensureAtLeastOnePage() {
        if (pages == null) {
            pages = new List<PageVM>();
        }
        if (pages.isEmpty()) {
            newPage();
        }
    }

    private void normalizeDateRange() {
        if (startDate == null && endDate == null) {
            startDate = Date.today().toStartOfMonth();
            endDate = startDate.addMonths(2).addDays(-1);
        } else if (startDate == null) {
            startDate = endDate.addMonths(-1);
        } else if (endDate == null) {
            endDate = startDate.addMonths(1);
        }

        if (startDate != null && endDate != null && endDate < startDate) {
            Date tmp = startDate;
            startDate = endDate;
            endDate = tmp;
        }
    }

    // -----------------------
    // DATA LOADING
    // -----------------------
    private static List<Event__c> loadMeetings(Date startDate, Date endDate, String salesTeamFilter) {
        if (String.isBlank(salesTeamFilter) || salesTeamFilter == ALL_SALES_TEAMS) {
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
                AND endDate__c != null
                AND startDate__c <= :endDate
                AND endDate__c >= :startDate
                ORDER BY startDate__c ASC, startTime__c ASC
            ];
        }

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
            AND endDate__c != null
            AND startDate__c <= :endDate
            AND endDate__c >= :startDate
            AND SalesTeam__c = :salesTeamFilter
            ORDER BY startDate__c ASC, startTime__c ASC
        ];
    }

    private static Map<String, String> getTimezoneValueToLabelMap() {
        Map<String, String> result = new Map<String, String>();

        for (Schema.PicklistEntry pe : Event__c.timezone__c.getDescribe().getPicklistValues()) {
            result.put(pe.getValue(), pe.getLabel());
        }

        return result;
    }
    // Construit les options de Sales Teams depuis la picklist.
    private void buildSalesTeamOptions() {
        salesTeamOptions = new List<SelectOption>();
        salesTeamOptions.add(new SelectOption(ALL_SALES_TEAMS, 'All sales teams'));

        // Récupère les valeurs de la picklist SalesTeam__c.
        Schema.DescribeFieldResult fieldDescribe =
            Event__c.SalesTeam__c.getDescribe();

        List<Schema.PicklistEntry> picklistValues =
            fieldDescribe.getPicklistValues();

        // Ajoute les valeurs actives dans les options.
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                salesTeamOptions.add(
                    new SelectOption(entry.getValue(), entry.getLabel())
                );
            }
        }

        // Initialise la valeur par défaut.
        if (String.isBlank(selectedSalesTeam)) {
            selectedSalesTeam = ALL_SALES_TEAMS;
        }
    }

    private class MeetingMeta {
        Set<String> speakers = new Set<String>();
        Set<String> strategies = new Set<String>();

        String speakersLabel() {
            List<String> values = new List<String>();
            values.addAll(speakers);
            values.sort();
            return values.isEmpty() ? '' : String.join(values, ', ');
        }

        String strategiesLabel() {
            List<String> values = new List<String>();
            values.addAll(strategies);
            values.sort();
            return values.isEmpty() ? '' : String.join(values, ', ');
        }
    }

    private static Map<Id, MeetingMeta> loadMeetingMeta(Set<Id> meetingIds) {
        Map<Id, MeetingMeta> metaByMeeting = new Map<Id, MeetingMeta>();
        if (meetingIds == null || meetingIds.isEmpty()) {
            return metaByMeeting;
        }

        for (SessionSpeakerProduct__c ssp : [
            SELECT Session__c,
                   speakerContact__r.Name,
                   Strategy__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :meetingIds
        ]) {
            if (ssp.Session__c == null) {
                continue;
            }

            MeetingMeta meta = metaByMeeting.get(ssp.Session__c);
            if (meta == null) {
                meta = new MeetingMeta();
                metaByMeeting.put(ssp.Session__c, meta);
            }

            String speakerName = (ssp.speakerContact__r == null) ? null : ssp.speakerContact__r.Name;
            if (!String.isBlank(speakerName)) {
                meta.speakers.add(speakerName);
            }

            String strategyName = (ssp.Strategy__r == null) ? null : ssp.Strategy__r.Name;
            if (!String.isBlank(strategyName)) {
                meta.strategies.add(strategyName);
            }
        }

        return metaByMeeting;
    }

    // -----------------------
    // CONFLICTS
    // -----------------------
    private static Set<Id> detectSpeakerConflicts(List<Event__c> meetings, Map<Id, MeetingMeta> metaByMeeting) {
        Set<Id> conflictedMeetingIds = new Set<Id>();
        Map<String, Map<String, List<Id>>> indexBySlot = new Map<String, Map<String, List<Id>>>();

        for (Event__c meeting : meetings) {
            if (meeting == null || meeting.Id == null) {
                continue;
            }

            MeetingMeta meta = metaByMeeting.get(meeting.Id);
            if (meta == null || meta.speakers.isEmpty()) {
                continue;
            }

            String slotKey = buildConflictSlotKey(meeting);
            if (String.isBlank(slotKey)) {
                continue;
            }

            Map<String, List<Id>> bySpeaker = indexBySlot.get(slotKey);
            if (bySpeaker == null) {
                bySpeaker = new Map<String, List<Id>>();
                indexBySlot.put(slotKey, bySpeaker);
            }

            for (String speaker : meta.speakers) {
                if (String.isBlank(speaker)) {
                    continue;
                }

                List<Id> ids = bySpeaker.get(speaker);
                if (ids == null) {
                    ids = new List<Id>();
                    bySpeaker.put(speaker, ids);
                }
                ids.add(meeting.Id);
            }
        }

        for (Map<String, List<Id>> bySpeaker : indexBySlot.values()) {
            for (List<Id> ids : bySpeaker.values()) {
                if (ids != null && ids.size() > 1) {
                    conflictedMeetingIds.addAll(ids);
                }
            }
        }

        return conflictedMeetingIds;
    }

    private static String buildConflictSlotKey(Event__c meeting) {
        if (meeting == null || meeting.startDate__c == null || String.isBlank(meeting.startTime__c)) {
            return null;
        }
        return String.valueOf(meeting.startDate__c) + '|' + meeting.startTime__c;
    }

    // -----------------------
    // VIEW BUILDING
    // -----------------------
    private static List<DayGroupVM> buildDayGroups(
        List<Event__c> meetings,
        Map<Id, MeetingMeta> metaByMeeting,
        Set<Id> conflictedMeetingIds
    ) {
        List<DayGroupVM> dayGroups = new List<DayGroupVM>();
        Map<String, DayGroupVM> byDayKey = new Map<String, DayGroupVM>();

        Map<Id, String> rtLabels = getRecordTypeLabels();
        Map<String, String> timezoneLabels = getTimezoneValueToLabelMap();

        for (Event__c meeting : meetings) {
            if (meeting == null || meeting.startDate__c == null) {
                continue;
            }

            String dayKey = String.valueOf(meeting.startDate__c);
            DayGroupVM dayGroup = byDayKey.get(dayKey);

            if (dayGroup == null) {
                dayGroup = new DayGroupVM();
                dayGroup.dayKey = dayKey;
                dayGroup.dayLabel = formatDayName(meeting.startDate__c);
                dayGroup.fullDateLabel = formatFullDate(meeting.startDate__c);
                dayGroup.events = new List<EventRowVM>();

                byDayKey.put(dayKey, dayGroup);
                dayGroups.add(dayGroup);
            }

            MeetingMeta meta = metaByMeeting.get(meeting.Id);

            EventRowVM row = new EventRowVM();
            row.id = String.valueOf(meeting.Id);
            row.timeRangeLabel = buildTimeRange(meeting.startTime__c, meeting.endTime__c, meeting.timezone__c);
            row.title = String.isBlank(meeting.Title__c) ? DEFAULT_TITLE : meeting.Title__c;
            row.speakersLabel = (meta == null) ? '' : meta.speakersLabel();
            row.strategiesLabel = (meta == null) ? '' : meta.strategiesLabel();
            row.eventColor = String.isBlank(meeting.Color__c) ? DEFAULT_EVENT_COLOR : meeting.Color__c;
            row.displayTimezone = timezoneLabels.containsKey(meeting.timezone__c)
                ? timezoneLabels.get(meeting.timezone__c)
                : meeting.timezone__c;
            row.isSpeakerConflict = conflictedMeetingIds != null && conflictedMeetingIds.contains(meeting.Id);
            row.salesTeamLabel = meeting.SalesTeam__c;

            String typeLabel = rtLabels.get(meeting.RecordTypeId);
            row.tooltipLabel =
                (String.isBlank(meeting.SalesTeam__c) ? '' : meeting.SalesTeam__c) +
                (String.isBlank(typeLabel) ? '' : ' - ' + typeLabel);

            dayGroup.events.add(row);
        }

        return dayGroups;
    }

    private void packDayGroupsIntoPages(List<DayGroupVM> dayGroups) {
        if (dayGroups == null || dayGroups.isEmpty()) {
            return;
        }

        PageVM currentPage = newPage();
        Integer colIndex = 0;
        Integer remainingSlots = SLOTS_PER_COLUMN;

        for (DayGroupVM groupVm : dayGroups) {
            Integer neededSlots = estimateSlots(groupVm);

            if (remainingSlots < neededSlots) {
                colIndex++;
                remainingSlots = SLOTS_PER_COLUMN;

                if (colIndex >= COLS) {
                    currentPage = newPage();
                    colIndex = 0;
                }
            }

            currentPage.columns[colIndex].dayGroups.add(groupVm);
            remainingSlots -= neededSlots;
        }
    }

    private static Integer estimateSlots(DayGroupVM groupVm) {
        Integer eventCount = (groupVm == null || groupVm.events == null) ? 0 : groupVm.events.size();
        Integer slots = 1 + eventCount; // 1 header + N events
        return Math.min(SLOTS_PER_COLUMN, Math.max(1, slots));
    }

    // -----------------------
    // PAGE FACTORY
    // -----------------------
    private PageVM newPage() {
        PageVM p = new PageVM();
        p.columns = new List<ColumnVM>();

        for (Integer i = 0; i < COLS; i++) {
            ColumnVM c = new ColumnVM();
            c.dayGroups = new List<DayGroupVM>();
            p.columns.add(c);
        }

        pages.add(p);
        return p;
    }

    // -----------------------
    // HELPERS
    // -----------------------
    private static Date parseDateParam(String key, Date defaultVal) {
        String v = ApexPages.currentPage().getParameters().get(key);
        if (String.isBlank(v)) {
            return defaultVal;
        }
        try {
            return Date.valueOf(v);
        } catch (Exception e) {
            return defaultVal;
        }
    }

    private static String parseSalesTeamParam(String key, String defaultVal) {
        String v = ApexPages.currentPage().getParameters().get(key);
        return String.isBlank(v) ? defaultVal : v;
    }

    private static String formatDayName(Date d) {
        return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('EEEE');
    }

    private static String formatFullDate(Date d) {
        return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('MMMM d, yyyy');
    }

    private static String buildTimeRange(String startTime, String endTime, String timezone) {
        String label = '';

        if (!String.isBlank(startTime) && !String.isBlank(endTime)) {
            label = startTime + ' - ' + endTime;
        } else if (!String.isBlank(startTime)) {
            label = startTime;
        } else if (!String.isBlank(endTime)) {
            label = endTime;
        } else {
            label = 'all-day';
        }
/*
        if (!String.isBlank(timezone)) {
            label += ' (' + timezone + ')';
        }
*/
        return label;
    }

    // -----------------------
    // VIEW MODELS
    // -----------------------
    public class PageVM {
        public List<ColumnVM> columns { get; set; }
    }

    public class ColumnVM {
        public List<DayGroupVM> dayGroups { get; set; }
    }

    public class DayGroupVM {
        public String dayKey { get; set; }
        public String dayLabel { get; set; }
        public String fullDateLabel { get; set; }
        public List<EventRowVM> events { get; set; }
    }

    public class EventRowVM {
        public String timeRangeLabel { get; set; }
        public String title { get; set; }
        public String speakersLabel { get; set; }
        public String strategiesLabel { get; set; }
        public String eventColor { get; set; }
        public String displayTimezone { get; set; }
        public Boolean isSpeakerConflict { get; set; }
        public String id { get; set; }
        public String salesTeamLabel { get; set; }
        public String tooltipLabel { get; set; }
    }
    private static Map<Id, String> getRecordTypeLabels() {

            Map<Id, String> result = new Map<Id, String>();

            Map<String, Schema.RecordTypeInfo> rtInfos =
                Event__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

            if (rtInfos.containsKey('MeetingDays')) {
                result.put(rtInfos.get('MeetingDays').getRecordTypeId(), 'Meeting Days');
            }
            if (rtInfos.containsKey('Meeting')) {
                result.put(rtInfos.get('Meeting').getRecordTypeId(), 'One to one');
            }
            if (rtInfos.containsKey('event')) {
                result.put(rtInfos.get('event').getRecordTypeId(), 'Event');
            }

            return result;
    }
}