public with sharing class VFC17_PrintEvents {

    private static final Integer COLS = 3;
    private static final Integer SLOTS_PER_COLUMN = 10000;

    private static final String DEFAULT_EVENT_COLOR = '#2C3E50';
    private static final String DEFAULT_TITLE = '(Sans titre)';
    private static final String ALL_SALES_TEAMS = '__ALL__';

    public List<String> selectedSalesTeams { get; set; }
    public List<String> selectedSpeakerIds { get; set; }
    public List<String> selectedJobTitles { get; set; }
    public String selectedTimezone { get; set; }
    public List<SelectOption> timezoneOptions { get; private set; }
    public List<SelectOption> speakerOptions { get; private set; }
    public List<SelectOption> jobTitleOptions { get; private set; }

    public Date startDate { get; set; }
    public Date endDate { get; set; }

    public String selectedSalesTeam { get; set; }
    public List<SelectOption> salesTeamOptions { get; private set; }

    public List<PageVM> pages { get; private set; }
    public List<EventColorLegendDto> colorLegend { get; private set; }
    
    public Boolean isPdf {
        get { return ApexPages.currentPage().getParameters().get('pdf') == '1'; }
    }

    public VFC17_PrintEvents() {
        startDate = parseDateParam('start', Date.today().toStartOfMonth());
        endDate = parseDateParam('end', Date.today().toStartOfMonth().addMonths(2).addDays(-1));
        selectedSalesTeams = parseCsvParam('salesTeams');
        selectedSpeakerIds = parseCsvParam('speakerIds');
        selectedJobTitles = parseCsvParam('jobTitles');
        selectedTimezone = ApexPages.currentPage().getParameters().get('timezone');

        buildSalesTeamOptions();
        buildSpeakerOptions();
        buildJobTitleOptions();
        buildTimezoneOptions();
        colorLegend = loadEventColors();

        build();
    }

    public PageReference applyDates() {
        normalizeDateRange();
        buildSalesTeamOptions();
        build();
        return null;
    }

    // Ouvre le PDF en conservant les filtres actifs de la page.
    public PageReference openPdf() {
        PageReference pr = Page.VFP17_PrintEvents_PDF;
        pr.getParameters().put('pdf', '1');

        if (startDate != null) {
            pr.getParameters().put('start', String.valueOf(startDate));
        }
        if (endDate != null) {
            pr.getParameters().put('end', String.valueOf(endDate));
        }

        // Transmet les filtres multi-sélection au PDF.
        if (selectedSalesTeams != null && !selectedSalesTeams.isEmpty()) {
            pr.getParameters().put('salesTeams', String.join(selectedSalesTeams, ','));
        }
        if (selectedSpeakerIds != null && !selectedSpeakerIds.isEmpty()) {
            pr.getParameters().put('speakerIds', String.join(selectedSpeakerIds, ','));
        }
        if (selectedJobTitles != null && !selectedJobTitles.isEmpty()) {
            pr.getParameters().put('jobTitles', String.join(selectedJobTitles, ','));
        }
        if (!String.isBlank(selectedTimezone)) {
            pr.getParameters().put('timezone', selectedTimezone);
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

        List<Event__c> meetings = loadMeetings(
            startDate,
            endDate,
            selectedSalesTeams,
            selectedSpeakerIds,
            selectedJobTitles
        );
        if (meetings.isEmpty()) {
            ensureAtLeastOnePage();
            return;
        }

        EventColorService.applyColorsInMemory(meetings);

        Set<Id> meetingIds = new Map<Id, Event__c>(meetings).keySet();
        Map<Id, MeetingMeta> metaByMeeting = loadMeetingMeta(meetingIds);
        Set<Id> conflictedMeetingIds = detectSpeakerConflicts(meetings, metaByMeeting);

        List<DayGroupVM> dayGroups = buildDayGroups(
            meetings,
            metaByMeeting,
            conflictedMeetingIds,
            selectedTimezone
        );        
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
    private static List<Event__c> loadMeetings(
        Date startDate,
        Date endDate,
        List<String> salesTeamFilters,
        List<String> speakerIdFilters,
        List<String> jobTitleFilters
    ) {
        Set<Id> sessionIds = resolveSessionIdsFromSpeakerFilters(
            speakerIdFilters,
            jobTitleFilters
        );

        Boolean hasSpeakerFilter =
            (speakerIdFilters != null && !speakerIdFilters.isEmpty()) ||
            (jobTitleFilters != null && !jobTitleFilters.isEmpty());

        if (hasSpeakerFilter && sessionIds.isEmpty()) {
            return new List<Event__c>();
        }

        String soql =
            'SELECT Id, RecordTypeId, SalesTeam__c, Color__c, Title__c, timezone__c, ' +
            'city__c, country__c, locationAddress__c, ' +
            'startDate__c, startTime__c, endDate__c, endTime__c ' +
            'FROM Event__c ' +
            'WHERE startDate__c != null ' +
            'AND endDate__c != null ' +
            'AND startDate__c <= :endDate ' +
            'AND endDate__c >= :startDate';

        if (salesTeamFilters != null && !salesTeamFilters.isEmpty()) {
            soql += ' AND SalesTeam__c IN :salesTeamFilters';
        }

        if (hasSpeakerFilter) {
            soql += ' AND Id IN :sessionIds';
        }

        soql += ' ORDER BY startDate__c ASC, startTime__c ASC';

        return Database.query(soql);
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

    // Construit les groupes de jours et duplique les événements multi-jours sur chaque date concernée.
    private static List<DayGroupVM> buildDayGroups(
        List<Event__c> meetings,
        Map<Id, MeetingMeta> metaByMeeting,
        Set<Id> conflictedMeetingIds,
        String selectedTimezone
    ) {
        List<DayGroupVM> dayGroups = new List<DayGroupVM>();
        Map<String, DayGroupVM> byDayKey = new Map<String, DayGroupVM>();

        Map<Id, String> rtLabels = getRecordTypeLabels();
        Map<String, String> timezoneLabels = getTimezoneValueToLabelMap();

        for (Event__c meeting : meetings) {
            if (meeting == null || meeting.startDate__c == null || meeting.endDate__c == null) {
                continue;
            }

            Date currentDate = meeting.startDate__c;

            // Ajoute l'événement sur chaque jour entre startDate__c et endDate__c inclus.
            while (currentDate <= meeting.endDate__c) {
                String dayKey = String.valueOf(currentDate);
                DayGroupVM dayGroup = byDayKey.get(dayKey);

                if (dayGroup == null) {
                    dayGroup = new DayGroupVM();
                    dayGroup.dayKey = dayKey;
                    dayGroup.dayLabel = formatDayName(currentDate);
                    dayGroup.fullDateLabel = formatFullDate(currentDate);
                    dayGroup.events = new List<EventRowVM>();

                    byDayKey.put(dayKey, dayGroup);
                    dayGroups.add(dayGroup);
                }

                MeetingMeta meta = metaByMeeting.get(meeting.Id);

                EventRowVM row = new EventRowVM();
                row.id = String.valueOf(meeting.Id);
                row.timeRangeLabel = buildTimeRange(meeting.startTime__c, meeting.endTime__c, meeting.timezone__c);
                // Calcule uniquement l'affichage converti sans modifier la date de grouping.
                row.convertedTimeRangeLabel = buildConvertedTimeRangeLabel(
                    meeting,
                    currentDate,
                    selectedTimezone
                );
                row.title = String.isBlank(meeting.Title__c) ? DEFAULT_TITLE : meeting.Title__c;
                row.speakersLabel = (meta == null) ? '' : meta.speakersLabel();
                row.strategiesLabel = (meta == null) ? '' : meta.strategiesLabel();

                // Conserve les informations d'affichage existantes pour chaque occurrence journalière.
                row.eventColor = String.isBlank(meeting.Color__c) ? DEFAULT_EVENT_COLOR : meeting.Color__c;
                row.displayTimezone = timezoneLabels.containsKey(meeting.timezone__c)
                    ? timezoneLabels.get(meeting.timezone__c)
                    : meeting.timezone__c;
                row.isSpeakerConflict = conflictedMeetingIds != null && conflictedMeetingIds.contains(meeting.Id);
                row.salesTeamLabel = meeting.SalesTeam__c;
                if (meeting.country__c == 'Digital') {
                    row.locationLabel = meeting.country__c;
                } else {
                    List<String> locationParts = new List<String>();

                    if (!String.isBlank(meeting.locationAddress__c)) {
                        locationParts.add(meeting.locationAddress__c);
                    }

                    if (!String.isBlank(meeting.city__c)) {
                        locationParts.add(meeting.city__c);
                    }

                    if (!String.isBlank(meeting.country__c)) {
                        locationParts.add(meeting.country__c);
                    }

                    row.locationLabel = String.join(locationParts, ', ');
                }
                String typeLabel = rtLabels.get(meeting.RecordTypeId);
                row.tooltipLabel =
                    (String.isBlank(meeting.SalesTeam__c) ? '' : meeting.SalesTeam__c) +
                    (String.isBlank(typeLabel) ? '' : ' - ' + typeLabel);

                dayGroup.events.add(row);
                currentDate = currentDate.addDays(1);
            }
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

    // Charge la légende des couleurs depuis la configuration EventColors__c.
    private static List<EventColorLegendDto> loadEventColors() {
        List<EventColorLegendDto> results = new List<EventColorLegendDto>();

        for (EventColors__c rec : [
            SELECT Id, Name, SalesTeam__c, meetingDays__c, oneToOne__c, Event__c
            FROM EventColors__c
            ORDER BY Name
        ]) {
            EventColorLegendDto dto = new EventColorLegendDto();
            dto.label = String.isBlank(rec.SalesTeam__c) ? rec.Name : rec.SalesTeam__c;
            dto.meetingDays = rec.meetingDays__c;
            dto.oneToOne = rec.oneToOne__c;
            dto.eventColor = rec.Event__c;
            results.add(dto);
        }

        return results;
    }

    public class EventColorLegendDto {
        public String label { get; set; }
        public String meetingDays { get; set; }
        public String oneToOne { get; set; }
        public String eventColor { get; set; }
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
        public String convertedTimeRangeLabel { get; set; }
        public Boolean isSpeakerConflict { get; set; }
        public String id { get; set; }
        public String salesTeamLabel { get; set; }
        public String tooltipLabel { get; set; }
        public String locationLabel { get; set; }
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

        // Parse les paramètres CSV venant du LWC.
    private static List<String> parseCsvParam(String key) {
        String rawValue = ApexPages.currentPage().getParameters().get(key);
        List<String> values = new List<String>();

        if (String.isBlank(rawValue)) {
            return values;
        }

        for (String item : rawValue.split(',')) {
            if (!String.isBlank(item)) {
                // Décode les espaces encodés en "+" dans les paramètres URL.
                values.add(item.trim().replace('+', ' '));            }
        }

        return values;
    }

    // Construit les options Speakers depuis les contacts valides.
    private void buildSpeakerOptions() {
        speakerOptions = new List<SelectOption>();

        for (Contact c : [
            SELECT Id, Name
            FROM Contact
            WHERE isValidSpeaker__c = true
            ORDER BY Name
            LIMIT 2000
        ]) {
            speakerOptions.add(new SelectOption((String) c.Id, c.Name));
        }
    }

    // Construit les options Job Titles depuis Contact.JobTitle__c.
    private void buildJobTitleOptions() {
        jobTitleOptions = new List<SelectOption>();
        Set<String> titles = new Set<String>();

        for (Contact c : [
            SELECT JobTitle__c
            FROM Contact
            WHERE isValidSpeaker__c = true
            AND JobTitle__c != null
            LIMIT 2000
        ]) {
            titles.add(c.JobTitle__c);
        }

        List<String> sortedTitles = new List<String>();
        sortedTitles.addAll(titles);
        sortedTitles.sort();

        for (String title : sortedTitles) {
            jobTitleOptions.add(new SelectOption(title, title));
        }
    }

    // Retrouve les sessions liées aux filtres Speaker / Job Title.
    private static Set<Id> resolveSessionIdsFromSpeakerFilters(
        List<String> speakerIdFilters,
        List<String> jobTitleFilters
    ) {
        Set<Id> sessionIds = new Set<Id>();

        Boolean hasSpeakerIds = speakerIdFilters != null && !speakerIdFilters.isEmpty();
        Boolean hasJobTitles = jobTitleFilters != null && !jobTitleFilters.isEmpty();

        if (!hasSpeakerIds && !hasJobTitles) {
            return sessionIds;
        }

        List<SessionSpeakerProduct__c> links;

        if (hasSpeakerIds && hasJobTitles) {
            links = [
                SELECT Session__c
                FROM SessionSpeakerProduct__c
                WHERE speakerContact__c IN :speakerIdFilters
                AND speakerContact__r.JobTitle__c IN :jobTitleFilters
            ];
        } else if (hasSpeakerIds) {
            links = [
                SELECT Session__c
                FROM SessionSpeakerProduct__c
                WHERE speakerContact__c IN :speakerIdFilters
            ];
        } else {
            links = [
                SELECT Session__c
                FROM SessionSpeakerProduct__c
                WHERE speakerContact__r.JobTitle__c IN :jobTitleFilters
            ];
        }

        for (SessionSpeakerProduct__c link : links) {
            if (link.Session__c != null) {
                sessionIds.add(link.Session__c);
            }
        }

        return sessionIds;
    }
        // Construit le label horaire converti avec indication J-1 / J+1 si la date glisse.
    private static String buildConvertedTimeRangeLabel(Event__c meeting, Date displayDate, String targetTimezone) {
        if (
            meeting == null ||
            displayDate == null ||
            String.isBlank(targetTimezone) ||
            String.isBlank(meeting.startTime__c) ||
            String.isBlank(meeting.endTime__c) ||
            String.isBlank(meeting.timezone__c)
        ) {
            return '';
        }

        Event__c tmp = meeting.clone(true, false, false, false);
        tmp.startDate__c = displayDate;
        tmp.endDate__c = displayDate;

        // Convertit une occurrence d'affichage, sans toucher à l'event original.
        List<Event__c> convertedEvents = EventTimezoneUtil.convertTimeZone(
            new List<Event__c>{ tmp },
            targetTimezone
        );

        if (convertedEvents.isEmpty()) {
            return '';
        }

        Event__c converted = convertedEvents[0];

        String startShift = buildDayShiftLabel(displayDate, converted.startDate__c);
        String endShift = buildDayShiftLabel(displayDate, converted.endDate__c);

        return converted.startTime__c + startShift + ' - ' + converted.endTime__c + endShift;
    }

    // Retourne J-1 / J+1 si la conversion change le jour affiché.
    private static String buildDayShiftLabel(Date originalDate, Date convertedDate) {
        if (originalDate == null || convertedDate == null || originalDate == convertedDate) {
            return '';
        }

        Integer diff = originalDate.daysBetween(convertedDate);

        if (diff > 0) {
            return ' J+' + diff;
        }

        return ' J' + diff;
    }

    // Construit les timezones disponibles pour l'affichage converti.
    private void buildTimezoneOptions() {
        timezoneOptions = new List<SelectOption>();

        timezoneOptions.add(new SelectOption('UTC', 'UTC'));
        timezoneOptions.add(new SelectOption('Europe/Paris', 'Europe/Paris'));
        timezoneOptions.add(new SelectOption('Europe/London', 'Europe/London'));
        timezoneOptions.add(new SelectOption('America/Toronto', 'America/Toronto'));
        timezoneOptions.add(new SelectOption('Europe/Helsinki', 'Europe/Helsinki'));
        timezoneOptions.add(new SelectOption('Asia/Dubai', 'Asia/Dubai'));
        timezoneOptions.add(new SelectOption('Asia/Singapore', 'Asia/Singapore'));
    }
}