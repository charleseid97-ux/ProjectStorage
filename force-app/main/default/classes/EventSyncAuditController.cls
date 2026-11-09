public without sharing class EventSyncAuditController {
    private static final String GRAPH_NAMED_CREDENTIAL = 'MicrosoftGraphSF';
    private static final String GRAPH_EVENT_ID_FIELD = 'MicrosoftEventId__c';
    private static final String FULLY_APPROVED_STATUS = 'FullyApproved';

    public Date startDate { get; set; }
    public Date endDate { get; set; }
    public String eventNameFilter { get; set; }
    public List<AuditRow> rows { get; private set; }
    public Integer totalCount { get; private set; }
    public Integer syncedCount { get; private set; }
    public Integer missingGraphCount { get; private set; }
    public Integer missingSalesforceCount { get; private set; }
    public Integer duplicateGraphCount { get; private set; }
    public String errorMessage { get; private set; }

    public Id resendEventId { get; set; }
    public String resendMessage { get; private set; }
    public String selectedMicrosoftEventId { get; set; }
    public String selectedMicrosoftSubject { get; set; }
    public String selectedMicrosoftDate { get; set; }
    public Id selectedBooklyEventId { get; set; }
    public List<BooklyCandidate> booklyCandidates { get; private set; }
    public String linkMessage { get; private set; }

    // Initializes the default 30-day audit window.
    public EventSyncAuditController() {
        startDate = Date.today();
        endDate = Date.today().addDays(30);
        booklyCandidates = new List<BooklyCandidate>();
        resetResults();
    }

    // Loads Salesforce and Graph events independently, then reconciles them.
    public PageReference searchEvents() {
        resetResults();
        if (startDate == null || endDate == null || startDate > endDate) {
            errorMessage = 'Please select a valid date range.';
            return null;
        }

        try {
            List<SalesforceEvent> salesforceEvents = loadSalesforceEvents();
            List<GraphEvent> graphEvents = loadGraphEvents();
            rows = reconcile(salesforceEvents, graphEvents);
            rows = sortRowsByMicrosoftDate(rows);
            rows = filterRowsByEventName(rows);
            calculateCounters();
        } catch (Exception ex) {
            errorMessage = ex.getMessage();
        }
        return null;
    }

    // Sorts rows by Microsoft date and title, keeping synchronized events before their duplicates.
    private static List<AuditRow> sortRowsByMicrosoftDate(List<AuditRow> auditRows) {
        Map<String, AuditRow> rowsByKey = new Map<String, AuditRow>();
        List<String> sortKeys = new List<String>();
        Integer index = 0;

        for (AuditRow row : auditRows) {
            Date eventDate = row.eventDate;
            String eventTitle = row.salesforceName;

            if (row.graphEvents != null && !row.graphEvents.isEmpty()) {
                eventDate = row.graphEvents[0].eventDate;
                eventTitle = row.graphEvents[0].subject;
            }

            String dateKey = eventDate == null ? '9999-12-31' : String.valueOf(eventDate);
            String titleKey = normalizeEventName(eventTitle);
            String statusRank = row.status == 'Synced'
                ? '0'
                : row.status == 'Duplicate in Graph' ? '1' : '2';

            String sortKey = dateKey + '|' + titleKey + '|' + statusRank + '|' + index;
            rowsByKey.put(sortKey, row);
            sortKeys.add(sortKey);
            index++;
        }

        sortKeys.sort();

        List<AuditRow> sortedRows = new List<AuditRow>();
        for (String sortKey : sortKeys) {
            sortedRows.add(rowsByKey.get(sortKey));
        }

        return sortedRows;
    }

    // Queries fully approved Event__c records without using Graph Id as a retrieval filter.
    private List<SalesforceEvent> loadSalesforceEvents() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Event__c.fields.getMap();
        List<String> selectedFields = new List<String>{'Id', 'Name', 'startDate__c', 'Status__c'};
        if (fields.containsKey('category__c')) selectedFields.add('category__c');
        if (fields.containsKey('SalesTeam__c')) selectedFields.add('SalesTeam__c');
        if (fields.containsKey(GRAPH_EVENT_ID_FIELD)) selectedFields.add(GRAPH_EVENT_ID_FIELD);
        if (fields.containsKey('noAutomations__c')) selectedFields.add('noAutomations__c');
        if (fields.containsKey('ScheduleID__c')) selectedFields.add('ScheduleID__c');

        String soql = 'SELECT ' + String.join(selectedFields, ',') +
            ' FROM Event__c WHERE (Status__c = :FULLY_APPROVED_STATUS' +
            ' OR MicrosoftEventId__c != null)' +
            ' AND startDate__c >= :startDate AND startDate__c <= :endDate' +
            ' ORDER BY startDate__c, Name';

        List<SalesforceEvent> result = new List<SalesforceEvent>();
        for (SObject record : Database.query(soql)) {
            SalesforceEvent item = new SalesforceEvent();
            item.id = (Id) record.get('Id');
            item.name = (String) record.get('Name');
            item.eventDate = (Date) record.get('startDate__c');
            item.status = (String) record.get('Status__c');
            item.type = fields.containsKey('category__c') ? (String) record.get('category__c') : null;
            item.salesTeam = fields.containsKey('SalesTeam__c') ? (String) record.get('SalesTeam__c') : null;
            item.graphId = fields.containsKey(GRAPH_EVENT_ID_FIELD) ? (String) record.get(GRAPH_EVENT_ID_FIELD) : null;
            item.noAutomations = fields.containsKey('noAutomations__c') && (Boolean) record.get('noAutomations__c');
            item.legacy = fields.containsKey('ScheduleID__c') && record.get('ScheduleID__c') != null;
            result.add(item);
        }
        return result;
    }

    // Retrieves Microsoft Graph calendar events independently for the selected period.
    private List<GraphEvent> loadGraphEvents() {
        String startValue = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String endValue = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String endpoint = 'callout:' + GRAPH_NAMED_CREDENTIAL + '/me/calendarView' +
            '?startDateTime=' + EncodingUtil.urlEncode(startValue, 'UTF-8') +
            '&endDateTime=' + EncodingUtil.urlEncode(endValue, 'UTF-8') +
            '&$select=id,subject,start,end';

        List<GraphEvent> result = new List<GraphEvent>();
        while (String.isNotBlank(endpoint)) {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Accept', 'application/json');

            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                throw new EventSyncAuditException('Graph callout failed: ' + response.getStatusCode() + ' ' + response.getStatus());
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            for (Object raw : (List<Object>) payload.get('value')) {
                Map<String, Object> graphRecord = (Map<String, Object>) raw;
                String subject = (String) graphRecord.get('subject');

                // Ignore Microsoft Calendar public holiday entries.
                if (
                    String.isNotBlank(subject) &&
                    subject.trim().equalsIgnoreCase('PUBLIC HOLIDAY')
                ) {
                    continue;
                }

                GraphEvent item = new GraphEvent();
                item.id = (String) graphRecord.get('id');
                item.subject = subject;
                item.eventDate = extractGraphDate((Map<String, Object>) graphRecord.get('start'));
                result.add(item);
            }

            String nextLink = (String) payload.get('@odata.nextLink');
            endpoint = String.isBlank(nextLink) ? null : normalizeNextLink(nextLink);
        }
        return result;
    }

    // Converts Graph start.dateTime into a Date for reconciliation.
    private static Date extractGraphDate(Map<String, Object> startValue) {
        if (startValue == null || startValue.get('dateTime') == null) return null;
        String value = String.valueOf(startValue.get('dateTime'));
        return value.length() >= 10 ? Date.valueOf(value.substring(0, 10)) : null;
    }

    // Converts an absolute Graph nextLink to the configured Named Credential endpoint.
    private static String normalizeNextLink(String nextLink) {
        String graphVersion = '/v1.0';
        Integer versionIndex = nextLink.indexOf(graphVersion + '/');
        if (versionIndex < 0) return null;

        return 'callout:' + GRAPH_NAMED_CREDENTIAL +
            nextLink.substring(versionIndex + graphVersion.length());
    }

    // Reconciles Salesforce and Graph events using only MicrosoftEventId__c.
    private static List<AuditRow> reconcile(List<SalesforceEvent> salesforceEvents, List<GraphEvent> graphEvents) {
        Map<String, GraphEvent> graphById = new Map<String, GraphEvent>();
        Set<GraphEvent> matchedGraphEvents = new Set<GraphEvent>();
        List<AuditRow> result = new List<AuditRow>();

        for (GraphEvent graphEvent : graphEvents) {
            graphById.put(graphEvent.id, graphEvent);
        }

        for (SalesforceEvent salesforceEvent : salesforceEvents) {
            List<GraphEvent> matches = new List<GraphEvent>();

            if (String.isNotBlank(salesforceEvent.graphId) && graphById.containsKey(salesforceEvent.graphId)) {
                GraphEvent graphEvent = graphById.get(salesforceEvent.graphId);
                matches.add(graphEvent);
                matchedGraphEvents.add(graphEvent);
            }

            result.add(buildSalesforceRow(salesforceEvent, matches));
        }

        for (GraphEvent graphEvent : graphEvents) {
            if (!matchedGraphEvents.contains(graphEvent)) {
                AuditRow row = buildGraphOnlyRow(graphEvent);

                if (isDuplicateGraphEvent(graphEvent, matchedGraphEvents)) {
                    row.status = 'Duplicate in Graph';
                    row.statusClass = 'status status-duplicate';
                }

                result.add(row);
            }
        }

        return result;
    }

        // Identifies a duplicate Microsoft event using the same start date and normalized title.
    private static Boolean isDuplicateGraphEvent(
        GraphEvent graphEvent,
        Set<GraphEvent> matchedGraphEvents
    ) {
        String normalizedSubject = normalizeEventName(graphEvent.subject);

        for (GraphEvent matchedGraphEvent : matchedGraphEvents) {
            if (
                graphEvent.eventDate == matchedGraphEvent.eventDate &&
                normalizedSubject == normalizeEventName(matchedGraphEvent.subject)
            ) {
                return true;
            }
        }

        return false;
    }

    // Builds one comparison row for a Salesforce Event and all independently matched Graph events.
    private static AuditRow buildSalesforceRow(SalesforceEvent salesforceEvent, List<GraphEvent> matches) {
        AuditRow row = new AuditRow();
        row.salesforceId = salesforceEvent.id;
        row.salesforceName = salesforceEvent.name;
        row.eventDate = salesforceEvent.eventDate;
        row.salesforceStatus = salesforceEvent.status;
        row.type = salesforceEvent.type;
        row.salesTeam = salesforceEvent.salesTeam;
        row.salesforceGraphId = salesforceEvent.graphId;
        row.salesforceUrl = '/' + salesforceEvent.id;
        row.noAutomations = salesforceEvent.noAutomations;
        row.legacy = salesforceEvent.legacy;
        row.graphEvents = new List<GraphDisplay>();

        if (matches == null || matches.isEmpty()) {
            row.status = 'Missing in Graph';
            row.statusClass = 'status status-error';
            return row;
        }

        for (GraphEvent graphEvent : matches) {
            GraphDisplay display = new GraphDisplay();
            display.id = graphEvent.id;
            display.subject = graphEvent.subject;
            display.eventDate = graphEvent.eventDate;
            display.linkCorrect = String.isNotBlank(salesforceEvent.graphId) && salesforceEvent.graphId == graphEvent.id;
            display.linkClass = display.linkCorrect ? 'link-icon link-ok' : 'link-icon link-broken';
            display.linkSymbol = display.linkCorrect ? '&#10003;' : '&#10005;';
            row.graphEvents.add(display);
        }

        if (matches.size() > 1) {
            row.status = 'Duplicate in Graph';
            row.statusClass = 'status status-duplicate';
        } else if (row.graphEvents[0].linkCorrect) {
            row.status = 'Synced';
            row.statusClass = 'status status-ok';
        } else {
            row.status = 'ID mismatch';
            row.statusClass = 'status status-error';
        }
        return row;
    }

    // Builds a row for a Graph event that has no Salesforce business-key counterpart.
    private static AuditRow buildGraphOnlyRow(GraphEvent graphEvent) {
        AuditRow row = new AuditRow();
        row.eventDate = graphEvent.eventDate;
        row.status = 'Missing in Salesforce';
        row.statusClass = 'status status-warning';
        row.graphEvents = new List<GraphDisplay>();
        GraphDisplay display = new GraphDisplay();
        display.id = graphEvent.id;
        display.subject = graphEvent.subject;
        display.eventDate = graphEvent.eventDate;
        display.linkCorrect = false;
        display.linkClass = 'link-icon link-broken';
        display.linkSymbol = '&#10005;';
        row.graphEvents.add(display);
        return row;
    }

    // Finds Bookly Events matching the Microsoft subject on the same start date.
    public PageReference findInBookly() {
        System.debug('========================findInBookly===');
        booklyCandidates = new List<BooklyCandidate>();
        linkMessage = null;

        System.debug(
            LoggingLevel.INFO,
            'FindInBookly params | eventId=' + selectedMicrosoftEventId +
            ' | subject=' + selectedMicrosoftSubject +
            ' | date=' + selectedMicrosoftDate
        );

        if (
            String.isBlank(selectedMicrosoftEventId) ||
            String.isBlank(selectedMicrosoftSubject) ||
            String.isBlank(selectedMicrosoftDate)
        ) {
            linkMessage = 'Unable to identify the Microsoft Calendar event.';
            return null;
        }

        Date microsoftDate = Date.valueOf(selectedMicrosoftDate);
        
        System.debug(
            LoggingLevel.INFO,
            'FindInBookly | selectedMicrosoftDate=' + selectedMicrosoftDate +
            ' | microsoftDate=' + microsoftDate +
            ' | selectedMicrosoftSubject=' + selectedMicrosoftSubject
        );
        String normalizedSubject = normalizeEventName(selectedMicrosoftSubject);

        for (Event__c eventRecord : [
            SELECT Id,
                   Name,
                   Title__c,
                   Status__c,
                   StartDate__c,
                   MicrosoftEventId__c
            FROM Event__c
            WHERE StartDate__c = :microsoftDate
            ORDER BY Name
            LIMIT 100
        ]) {
            String normalizedTitle = normalizeEventName(eventRecord.Title__c);

            System.debug(
                LoggingLevel.INFO,
                'FindInBookly candidate | Id=' + eventRecord.Id +
                ' | Name=' + eventRecord.Name +
                ' | Title=' + eventRecord.Title__c +
                ' | normalizedTitle=' + normalizedTitle +
                ' | match=' + normalizedSubject.contains(normalizedTitle)
            );

            

            if (
                String.isBlank(normalizedTitle) ||
                !normalizedSubject.contains(normalizedTitle)
            ) {
                continue;
            }

            BooklyCandidate candidate = new BooklyCandidate();
            candidate.id = eventRecord.Id;
            candidate.name = eventRecord.Name;
            candidate.status = eventRecord.Status__c;
            candidate.eventUrl = '/' + eventRecord.Id;
            candidate.canLink = String.isBlank(eventRecord.MicrosoftEventId__c);
            booklyCandidates.add(candidate);
        }
        return null;
    }

    // Links the selected Salesforce Event to the selected Microsoft Calendar event.
    public PageReference linkBooklyEvent() {
        if (selectedBooklyEventId == null || String.isBlank(selectedMicrosoftEventId)) {
            linkMessage = 'Unable to link the selected Event.';
            return null;
        }

        Event__c eventRecord = [
            SELECT Id, MicrosoftEventId__c
            FROM Event__c
            WHERE Id = :selectedBooklyEventId
            LIMIT 1
        ];

        if (String.isNotBlank(eventRecord.MicrosoftEventId__c)) {
            linkMessage = 'This Event is already linked to Microsoft Calendar.';
            return null;
        }

        try {
            eventRecord.MicrosoftEventId__c = selectedMicrosoftEventId;
            update eventRecord;

            linkMessage = 'Event successfully linked to Microsoft Calendar.';
        } catch (DmlException ex) {
            linkMessage = 'Unable to link Event: ' + ex.getDmlMessage(0);
        }

        return null;
    }

    // Extracts the most relevant Event title from a Microsoft Calendar subject.
    private static String extractBooklySearchText(String subject) {
        String cleanedSubject = subject.replace('[Bookly]', '').trim();

        if (cleanedSubject.startsWith('–')) {
            cleanedSubject = cleanedSubject.substring(1).trim();
        } else if (cleanedSubject.startsWith('-')) {
            cleanedSubject = cleanedSubject.substring(1).trim();
        }

        List<String> parts = cleanedSubject.split('–');

        if (parts.size() == 1) {
            parts = cleanedSubject.split(' - ');
        }

        String searchText = '';

        for (String part : parts) {
            String candidate = part.trim();

            if (candidate.length() > searchText.length()) {
                searchText = candidate;
            }
        }

        return searchText;
    }
    
    // Normalizes Event names to make Bookly and Microsoft titles comparable.
    private static String normalizeEventName(String value) {
        if (String.isBlank(value)) {
            return '';
        }

        return value
            .replace('[Bookly]', '')
            .replace('–', '-')
            .replace('—', '-')
            .replaceAll('\\s+', ' ')
            .trim()
            .toLowerCase();
    }

    // Filters displayed events using case-insensitive LIKE %text% behavior.
    private List<AuditRow> filterRowsByEventName(List<AuditRow> auditRows) {
        if (String.isBlank(eventNameFilter)) {
            return auditRows;
        }

        String normalizedFilter = eventNameFilter.trim().toLowerCase();
        List<AuditRow> filteredRows = new List<AuditRow>();

        for (AuditRow row : auditRows) {
            String eventName = row.salesforceName;

            if (String.isBlank(eventName) && !row.graphEvents.isEmpty()) {
                eventName = row.graphEvents[0].subject;
            }

            if (
                String.isNotBlank(eventName) &&
                eventName.toLowerCase().contains(normalizedFilter)
            ) {
                filteredRows.add(row);
            }
        }

        return filteredRows;
    }

    // Calculates the summary cards displayed above the audit table.
    private void calculateCounters() {
        totalCount = rows.size();
        for (AuditRow row : rows) {
            if (row.status == 'Synced') syncedCount++;
            else if (row.status == 'Missing in Graph') missingGraphCount++;
            else if (row.status == 'Missing in Salesforce') missingSalesforceCount++;
            else if (row.status == 'Duplicate in Graph') duplicateGraphCount++;
        }
    }

    // Clears previous search results and counters.
    private void resetResults() {
        rows = new List<AuditRow>();
        totalCount = 0;
        syncedCount = 0;
        missingGraphCount = 0;
        missingSalesforceCount = 0;
        duplicateGraphCount = 0;
        errorMessage = null;
    }

    public class AuditRow {
        public Id salesforceId { get; set; }
        public String salesforceName { get; set; }
        public String salesforceUrl { get; set; }
        public String salesforceGraphId { get; set; }
        public String salesforceStatus { get; set; }
        public Boolean noAutomations { get; set; }
        public Boolean legacy { get; set; }
        public Date eventDate { get; set; }
        public String type { get; set; }
        public String salesTeam { get; set; }
        public List<GraphDisplay> graphEvents { get; set; }
        public String status { get; set; }
        public String statusClass { get; set; }
    }

    public class BooklyCandidate {
        public Id id { get; set; }
        public String name { get; set; }
        public String status { get; set; }
        public String eventUrl { get; set; }
        public Boolean canLink { get; set; }
    }

    public class GraphDisplay {
        public String id { get; set; }
        public String subject { get; set; }
        public Date eventDate { get; set; }
        public Boolean linkCorrect { get; set; }
        public String linkClass { get; set; }
        public String linkSymbol { get; set; }
    }

    private class SalesforceEvent {
        Id id;
        String name;
        Date eventDate;
        String status;
        String type;
        String salesTeam;
        String graphId;
        Boolean noAutomations;
        Boolean legacy;
    }

    private class GraphEvent {
        String id;
        String subject;
        Date eventDate;
    }

    // Represents a functional error raised while auditing Salesforce and Graph events.
    private class EventSyncAuditException extends Exception {
    }


    // Deletes the selected Microsoft Calendar event and refreshes the audit.
    public PageReference deleteMicrosoftEvent() {
        if (String.isBlank(selectedMicrosoftEventId)) {
            errorMessage = 'No Microsoft Calendar Event selected.';
            return null;
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:' + GRAPH_NAMED_CREDENTIAL +
            '/me/events/' +
            EncodingUtil.urlEncode(selectedMicrosoftEventId, 'UTF-8')
        );
        request.setMethod('DELETE');

        HttpResponse response = new Http().send(request);

        if (response.getStatusCode() != 204) {
            errorMessage =
                'Unable to delete Microsoft Calendar Event: ' +
                response.getStatusCode() + ' ' +
                response.getStatus();
            return null;
        }

        return searchEvents();
    }


    // Enqueues the selected Event for a Microsoft invitation creation or update.
    public PageReference resendEvent() {
        resendMessage = null;

        if (resendEventId == null) {
            resendMessage = 'No Event selected.';
            return null;
        }

        Event__c eventRecord = [
            SELECT Id, MicrosoftEventId__c
            FROM Event__c
            WHERE Id = :resendEventId
            LIMIT 1
        ];

        Boolean isUpdate = String.isNotBlank(eventRecord.MicrosoftEventId__c);

        System.enqueueJob(
            new BooklyMeetingInvitationQueueable(
                new Set<Id>{ resendEventId },
                isUpdate
            )
        );

        resendMessage = isUpdate
            ? 'Invitation update has been queued.'
            : 'Invitation send has been queued.';

        return null;
    }
}