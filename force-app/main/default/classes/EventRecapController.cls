public with sharing class EventRecapController {

    /**
     * DTOs used by the LWC to keep the payload UI-friendly.
     */
    public class AttendeeDTO {
        @AuraEnabled public Id attendeeId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;

        public AttendeeDTO(Id aid, String fn, String ln) {
            attendeeId = aid;
            firstName  = fn;
            lastName   = ln;
        }
    }

    public class SpeakerProductsDTO {
        @AuraEnabled public String speakerName;
        @AuraEnabled public List<String> products;

        public SpeakerProductsDTO(String n, List<String> p) {
            speakerName = n;
            products    = p;
        }
    }

    public class EventDTO {
        @AuraEnabled public Id id;

        @AuraEnabled public String title;
        @AuraEnabled public String category;
        @AuraEnabled public Date   startDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public Date   endDate;
        @AuraEnabled public String endTime;
        @AuraEnabled public String timezone;
        @AuraEnabled public String status;
        @AuraEnabled public String salesTeam;
        @AuraEnabled public String format;
        @AuraEnabled public Id     parentEventId;

        @AuraEnabled public String company;
        @AuraEnabled public String meetingBackground;
        @AuraEnabled public String meetingGoal;

        @AuraEnabled public List<SpeakerProductsDTO> speakers;
        @AuraEnabled public List<AttendeeDTO> attendees;

        public EventDTO() {
            speakers  = new List<SpeakerProductsDTO>();
            attendees = new List<AttendeeDTO>();
        }
    }

    public class RecapDTO {
        @AuraEnabled public EventDTO parent;
        @AuraEnabled public List<EventDTO> children;
        public RecapDTO() { children = new List<EventDTO>(); }
    }

    @AuraEnabled(cacheable=true)
    public static RecapDTO getEventRecap(Id eventId) {
        System.debug(LoggingLevel.DEBUG, 'EventRecapController.getEventRecap start, eventId=' + eventId);

        RecapDTO out = new RecapDTO();
        if (eventId == null) {
            System.debug(LoggingLevel.WARN, 'Missing eventId, returning empty recap');
            return out;
        }

        Event__c parentE = loadParentEvent(eventId);
        if (parentE == null) {
            System.debug(LoggingLevel.WARN, 'Parent not found for Id=' + eventId);
            return out;
        }
        System.debug(LoggingLevel.DEBUG, 'Parent loaded: ' + parentE.Id);

        List<Event__c> childrenE = loadChildEvents(eventId);
        System.debug(LoggingLevel.DEBUG, 'Children count=' + childrenE.size());

        childrenE = dedupeById(childrenE);

        Set<Id> allEventIds = new Set<Id>();
        allEventIds.add(parentE.Id);
        for (Event__c ce : childrenE) allEventIds.add(ce.Id);

        Map<Id, Map<String, Set<String>>> spIndex = buildSpeakerProductsIndex(allEventIds);

        Map<Id, List<AttendeeDTO>> attendeesByEvent = buildAttendeesIndex(childrenE);

        out.parent = toDto(parentE, spIndex, null);
        for (Event__c ce : childrenE) {
            out.children.add(toDto(ce, spIndex, attendeesByEvent.get(ce.Id)));
        }

        System.debug(LoggingLevel.DEBUG, 'EventRecapController.getEventRecap done, childrenDTO=' + out.children.size());
        return out;
    }

    /**
     * Loads the parent event (the one requested by Id).
     */
    private static Event__c loadParentEvent(Id eventId) {
        List<Event__c> parentList = [
            SELECT Id, Title__c, Category__c, StartDate__c, StartTime__c, EndDate__c, EndTime__c,
                   Timezone__c, Status__c, SalesTeam__c, Format__c, ParentEvent__c,
                   Company__r.Name,
                   MeetingBackground__c,
                   MeetingGoal__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];
        return parentList.isEmpty() ? null : parentList[0];
    }

    /**
     * Loads direct child events of the parent event.
     */
    private static List<Event__c> loadChildEvents(Id eventId) {
        return [
            SELECT Id, Title__c, Category__c, StartDate__c, StartTime__c, EndDate__c, EndTime__c,
                   Timezone__c, Status__c, SalesTeam__c, Format__c, ParentEvent__c,
                   Company__r.Name,
                   MeetingBackground__c,
                   MeetingGoal__c
            FROM Event__c
            WHERE ParentEvent__c = :eventId
            ORDER BY StartDate__c ASC, StartTime__c ASC
        ];
    }

    /**
     * Deduplicates a list of sObjects by Id.
     */
    private static List<Event__c> dedupeById(List<Event__c> input) {
        if (input == null || input.isEmpty()) return new List<Event__c>();
        Map<Id, Event__c> uniqueMap = new Map<Id, Event__c>();
        for (Event__c e : input) uniqueMap.put(e.Id, e);
        return uniqueMap.values();
    }

    /**
     * Builds an index: eventId -> speakerName -> set(productName).
     */
    private static Map<Id, Map<String, Set<String>>> buildSpeakerProductsIndex(Set<Id> eventIds) {
        // Index of all products per speaker per session
        Map<Id, Map<String, Set<String>>> spIndex = new Map<Id, Map<String, Set<String>>>();
        if (eventIds == null || eventIds.isEmpty()) {
            return spIndex;
        }

        List<SessionSpeakerProduct__c> links = [
            SELECT Session__c, SpeakerContact__r.Name, strategy__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
        ];
        System.debug(LoggingLevel.DEBUG, 'SpeakerProduct links=' + links.size());

        for (SessionSpeakerProduct__c link : links) {
            addLinkToSpeakerProductsIndex(spIndex, link);
        }

        return spIndex;
    }

    /**
     * Adds a single link (session/speaker/product) into the index, if valid.
     */
    private static void addLinkToSpeakerProductsIndex(
        Map<Id, Map<String, Set<String>>> spIndex,
        SessionSpeakerProduct__c link
    ) {
        Id sessionId = link.Session__c;
        if (sessionId == null) {
            return;
        }

        String speakerName = extractSpeakerName(link);
        if (String.isBlank(speakerName)) {
            return;
        }

        String productName = extractProductName(link);

        Map<String, Set<String>> bySpeaker = spIndex.get(sessionId);
        if (bySpeaker == null) {
            bySpeaker = new Map<String, Set<String>>();
            spIndex.put(sessionId, bySpeaker);
        }

        Set<String> prods = bySpeaker.get(speakerName);
        if (prods == null) {
            prods = new Set<String>();
            bySpeaker.put(speakerName, prods);
        }

        prods.add(productName);
    }

    /**
     * Safely extracts the speaker name from the link.
     */
    private static String extractSpeakerName(SessionSpeakerProduct__c link) {
        return (link.SpeakerContact__r == null) ? null : link.SpeakerContact__r.Name;
    }

    /**
     * Safely extracts the product name from the link and normalizes blanks.
     */
    private static String extractProductName(SessionSpeakerProduct__c link) {
        String productName = (link.strategy__r == null) ? null : link.strategy__r.Name;
        if (String.isBlank(productName)) {
            productName = '(No product)';
        }
        return productName;
    }


    /**
     * Builds an index of attendees for children only: eventId -> attendees.
     */
    private static Map<Id, List<AttendeeDTO>> buildAttendeesIndex(List<Event__c> children) {
        Map<Id, List<AttendeeDTO>> attendeesByEvent = new Map<Id, List<AttendeeDTO>>();
        if (children == null || children.isEmpty()) return attendeesByEvent;

        Set<Id> childIds = new Set<Id>();
        for (Event__c ce : children) childIds.add(ce.Id);
        if (childIds.isEmpty()) return attendeesByEvent;

        List<EventAttendee__c> atts = [
            SELECT Id, Event__c, Contact__r.FirstName, Contact__r.LastName
            FROM EventAttendee__c
            WHERE Event__c IN :childIds
            ORDER BY Contact__r.LastName ASC, Contact__r.FirstName ASC
        ];
        System.debug(LoggingLevel.DEBUG, 'Attendee rows=' + atts.size());

        for (EventAttendee__c ea : atts) {
            Id evId = ea.Event__c;
            if (evId == null) continue;

            List<AttendeeDTO> listDto = attendeesByEvent.get(evId);
            if (listDto == null) {
                listDto = new List<AttendeeDTO>();
                attendeesByEvent.put(evId, listDto);
            }

            String fn = (ea.Contact__r == null) ? null : ea.Contact__r.FirstName;
            String ln = (ea.Contact__r == null) ? null : ea.Contact__r.LastName;
            listDto.add(new AttendeeDTO(ea.Id, fn, ln));
        }

        return attendeesByEvent;
    }

    private static EventDTO toDto(
        Event__c e,
        Map<Id, Map<String, Set<String>>> spIndex,
        List<AttendeeDTO> attendees
    ) {
        EventDTO dto = new EventDTO();
        dto.id = e.Id;

        dto.title     = e.Title__c;
        dto.category  = e.Category__c;
        dto.startDate = e.StartDate__c;
        dto.startTime = (e.StartTime__c == null) ? null : String.valueOf(e.StartTime__c);
        dto.endDate   = e.EndDate__c;
        dto.endTime   = (e.EndTime__c == null) ? null : String.valueOf(e.EndTime__c);

        dto.timezone      = e.Timezone__c;
        dto.status        = e.Status__c;
        dto.salesTeam     = e.SalesTeam__c;
        dto.format        = e.Format__c;
        dto.parentEventId = e.ParentEvent__c;

        dto.company           = (e.Company__r == null) ? null : e.Company__r.Name;
        dto.meetingBackground = e.MeetingBackground__c;
        dto.meetingGoal       = e.MeetingGoal__c;

        addSpeakers(dto, e.Id, spIndex);
        addAttendees(dto, attendees);

        return dto;
    }

    /**
     * Adds speakers grouped per event: speaker -> sorted product list.
     */
    private static void addSpeakers(EventDTO dto, Id eventId, Map<Id, Map<String, Set<String>>> spIndex) {
        if (dto == null || eventId == null || spIndex == null) return;

        Map<String, Set<String>> bySpeaker = spIndex.get(eventId);
        if (bySpeaker == null || bySpeaker.isEmpty()) return;

        List<String> speakerNames = new List<String>();
        speakerNames.addAll(bySpeaker.keySet());
        speakerNames.sort();

        for (String spName : speakerNames) {
            List<String> prodList = new List<String>();
            Set<String> prodSet = bySpeaker.get(spName);
            if (prodSet != null && !prodSet.isEmpty()) {
                prodList.addAll(prodSet);
                prodList.sort();
            }
            dto.speakers.add(new SpeakerProductsDTO(spName, prodList));
        }
    }

    /**
     * Adds attendees to the DTO (children only; parent passes null).
     */
    private static void addAttendees(EventDTO dto, List<AttendeeDTO> attendees) {
        if (dto == null || attendees == null || attendees.isEmpty()) return;
        dto.attendees.addAll(attendees);
    }
}