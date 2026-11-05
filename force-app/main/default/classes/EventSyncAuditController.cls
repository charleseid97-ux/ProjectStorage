public without sharing class EventSyncAuditController {
    private static final String GRAPH_NAMED_CREDENTIAL = 'MicrosoftGraphSF';
    private static final String GRAPH_EVENT_ID_FIELD = 'MicrosoftEventId__c';
    private static final String FULLY_APPROVED_STATUS = 'FullyApproved';

    public Date startDate { get; set; }
    public Date endDate { get; set; }
    public List<AuditRow> rows { get; private set; }
    public Integer totalCount { get; private set; }
    public Integer syncedCount { get; private set; }
    public Integer missingGraphCount { get; private set; }
    public Integer missingSalesforceCount { get; private set; }
    public Integer duplicateGraphCount { get; private set; }
    public String errorMessage { get; private set; }

    // Initializes the default 30-day audit window.
    public EventSyncAuditController() {
        startDate = Date.today();
        endDate = Date.today().addDays(30);
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
            calculateCounters();
        } catch (Exception ex) {
            errorMessage = ex.getMessage();
        }
        return null;
    }

    // Queries fully approved Event__c records without using Graph Id as a retrieval filter.
    private List<SalesforceEvent> loadSalesforceEvents() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Event__c.fields.getMap();
        List<String> selectedFields = new List<String>{'Id', 'Name', 'startDate__c', 'Status__c'};
        if (fields.containsKey('category__c')) selectedFields.add('category__c');
        if (fields.containsKey('SalesTeam__c')) selectedFields.add('SalesTeam__c');
        if (fields.containsKey(GRAPH_EVENT_ID_FIELD)) selectedFields.add(GRAPH_EVENT_ID_FIELD);

        String soql = 'SELECT ' + String.join(selectedFields, ',') +
            ' FROM Event__c WHERE Status__c = :FULLY_APPROVED_STATUS' +
            ' AND startDate__c >= :startDate AND startDate__c <= :endDate' +
            ' ORDER BY startDate__c, Name';

        List<SalesforceEvent> result = new List<SalesforceEvent>();
        for (SObject record : Database.query(soql)) {
            SalesforceEvent item = new SalesforceEvent();
            item.id = (Id) record.get('Id');
            item.name = (String) record.get('Name');
            item.eventDate = (Date) record.get('startDate__c');
            item.type = fields.containsKey('category__c') ? (String) record.get('category__c') : null;
            item.salesTeam = fields.containsKey('SalesTeam__c') ? (String) record.get('SalesTeam__c') : null;
            item.graphId = fields.containsKey(GRAPH_EVENT_ID_FIELD) ? (String) record.get(GRAPH_EVENT_ID_FIELD) : null;
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
                GraphEvent item = new GraphEvent();
                item.id = (String) graphRecord.get('id');
                item.subject = (String) graphRecord.get('subject');
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

    // Reconciles both independent datasets by normalized subject and date, never by stored Graph Id.
    private static List<AuditRow> reconcile(List<SalesforceEvent> salesforceEvents, List<GraphEvent> graphEvents) {
        Map<String, List<GraphEvent>> graphByBusinessKey = new Map<String, List<GraphEvent>>();
        Set<GraphEvent> matchedGraphEvents = new Set<GraphEvent>();
        List<AuditRow> result = new List<AuditRow>();

        for (GraphEvent graphEvent : graphEvents) {
            String key = businessKey(graphEvent.subject, graphEvent.eventDate);
            if (!graphByBusinessKey.containsKey(key)) graphByBusinessKey.put(key, new List<GraphEvent>());
            graphByBusinessKey.get(key).add(graphEvent);
        }

        for (SalesforceEvent salesforceEvent : salesforceEvents) {
            String key = businessKey(salesforceEvent.name, salesforceEvent.eventDate);
            List<GraphEvent> matches = graphByBusinessKey.get(key);
            AuditRow row = buildSalesforceRow(salesforceEvent, matches);
            result.add(row);
            if (matches != null) matchedGraphEvents.addAll(matches);
        }

        for (GraphEvent graphEvent : graphEvents) {
            if (!matchedGraphEvents.contains(graphEvent)) result.add(buildGraphOnlyRow(graphEvent));
        }
        return result;
    }

    // Builds one comparison row for a Salesforce Event and all independently matched Graph events.
    private static AuditRow buildSalesforceRow(SalesforceEvent salesforceEvent, List<GraphEvent> matches) {
        AuditRow row = new AuditRow();
        row.salesforceId = salesforceEvent.id;
        row.salesforceName = salesforceEvent.name;
        row.eventDate = salesforceEvent.eventDate;
        row.type = salesforceEvent.type;
        row.salesTeam = salesforceEvent.salesTeam;
        row.salesforceGraphId = salesforceEvent.graphId;
        row.salesforceUrl = '/' + salesforceEvent.id;
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
            display.linkSymbol = display.linkCorrect ? '&#128279;' : '&#128683;';
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
        display.linkSymbol = '&#128683;';
        row.graphEvents.add(display);
        return row;
    }

    // Produces a stable comparison key from date and normalized event label.
    private static String businessKey(String name, Date eventDate) {
        String normalized = String.isBlank(name) ? '' : name.toLowerCase().replaceAll('[^a-z0-9]+', ' ').trim();
        return String.valueOf(eventDate) + '|' + normalized;
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
        public Date eventDate { get; set; }
        public String type { get; set; }
        public String salesTeam { get; set; }
        public List<GraphDisplay> graphEvents { get; set; }
        public String status { get; set; }
        public String statusClass { get; set; }
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
        String type;
        String salesTeam;
        String graphId;
    }

    private class GraphEvent {
        String id;
        String subject;
        Date eventDate;
    }

    // Represents a functional error raised while auditing Salesforce and Graph events.
    private class EventSyncAuditException extends Exception {
    }
}