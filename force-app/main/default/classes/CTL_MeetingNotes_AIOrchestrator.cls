public without sharing class CTL_MeetingNotes_AIOrchestrator {

    // -------------------- FLOW CONTRACT (from your metadata) --------------------
    // Flow API name & variable names:
    private static final String FLOW_NAME            = 'AL_VideoCall_GeneratePromptsResponses';
    private static final String FLOW_VAR_IN_VIDEOCALL= 'VideoCall';                 // SObject input:contentReference[oaicite:4]{index=4}
    public static final String FLOW_OUT_SUMMARY     = 'Output_VideoCallSummary';   // String output:contentReference[oaicite:5]{index=5}
    public static final String FLOW_OUT_INTERESTS   = 'Output_ClientInterests';    // String (JSON) output:contentReference[oaicite:6]{index=6}

    // -------------------- MEETING NOTE SCHEMA -----------------------------------
    private static final String MEETING_NOTE_SOBJ    = 'Meeting_Note__c';
    private static final String FN_NOTE_NAME         = 'Name';
    private static final String FN_NOTE_DATE         = 'Date__c';
    private static final String FN_NOTE_SUMMARY      = 'Note__c';                // Will store flow summary

    // -------------------- EVENT SCHEMA (standard) --------------------------------
    // Add/keep your custom lookup from Event -> Meeting Note if you have it:
    private static final String FN_EVENT_MEETING_NOTE = 'Meeting_Note__c';          // remove if not in your org

    // -------------------- CLIENT INTEREST SCHEMA ---------------------------------
    private static final String CLIENT_INTEREST_SOBJ = 'ClientInterest__c';         // use your exact API name
    private static final String FN_CI_MEETING_NOTE   = 'MeetingNote__c';            // link back to meeting note
    private static final String FN_CI_STRATEGY       = 'Strategy__c';               // will map ProductId to this
    private static final String FN_CI_INTEREST       = 'Interest__c';               // numeric 1..5 (Rating)
    // Optional: create if you want to persist more fields
    // private static final String FN_CI_PRODUCT_NAME = 'ProductName__c';
    // private static final String FN_CI_WHY         = 'Why__c';

    public interface FlowRunner {
        Map<String, Object> run(VideoCall vc);
    }

    // Implémentation standard (appelle réellement le Flow)
    private class DefaultFlowRunner implements FlowRunner {
        public Map<String, Object> run(VideoCall vc) {
            Flow.Interview iv = Flow.Interview.createInterview(
                FLOW_NAME,
                new Map<String, Object>{ FLOW_VAR_IN_VIDEOCALL => vc }
            );
            iv.start();
            Map<String, Object> out = new Map<String, Object>();
            try { out.put(FLOW_OUT_SUMMARY,   iv.getVariableValue(FLOW_OUT_SUMMARY)); } catch (Exception ignore) {}
            try { out.put(FLOW_OUT_INTERESTS, iv.getVariableValue(FLOW_OUT_INTERESTS)); } catch (Exception ignore) {}
            return out;
        }
    }

    @TestVisible
    static FlowRunner flowRunner = new DefaultFlowRunner();

    // Remplace l’ancienne méthode par un simple pass-through vers le runner
    private static Map<String, Object> runPromptsFlow(VideoCall vc) {
        return flowRunner.run(vc);
    }

    // -------------------- Data Classes for Flow --------------------
    public class FlowInput {
        @InvocableVariable(required=true)
        public Id videoCallId;
    }

    public class FlowResult {
        @InvocableVariable
        public Id meetingNoteId;

        public FlowResult(Id id) {
            this.meetingNoteId = id;
        }
    }
    
    @InvocableMethod(label='Create Meeting Notes from VideoCalls 2')
    public static List<FlowResult> createMeetingNotes(List<FlowInput> inputs) {
        List<FlowResult> results = new List<FlowResult>();

        // 1. Extract all video call IDs
        Set<Id> videoCallIds = new Set<Id>();
        for (FlowInput input : inputs) {
            if (input != null && input.videoCallId != null) {
                videoCallIds.add(input.videoCallId);
            }
        }

        if (videoCallIds.isEmpty()) return results;

        // 2. Query all VideoCalls at once
        Map<Id, VideoCall> videoCallMap = new Map<Id, VideoCall>(
            [SELECT Name, EndDateTime, StartDateTime, Description, IntelligenceScore,
                    (SELECT RelatedPersonId, RelatedPerson.Name, RelatedPerson.Email
                     FROM VideoCalls
                     WHERE RelatedPersonId IN (SELECT Id FROM Contact))
             FROM VideoCall
             WHERE Id IN :videoCallIds]
        );

        // 3. Process each VideoCall
        for (FlowInput input : inputs) {
            Id vcId = input.videoCallId;
            if (!videoCallMap.containsKey(vcId)) {
                results.add(new FlowResult(null));
                continue;
            }

            try {
                VideoCall vc = videoCallMap.get(vcId);
                Id meetingNoteId = handleVideoCall(vc);
                results.add(new FlowResult(meetingNoteId));
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error processing VC ' + vcId + ': ' + e.getMessage());
                results.add(new FlowResult(null));
            }
        }

        return results;
    }

    // -------------------- Process Single VideoCall --------------------
    private static Id handleVideoCall(VideoCall vc) {
        Map<String, Object> flowOut = runPromptsFlow(vc);
        String summaryText   = (String) flowOut.get(FLOW_OUT_SUMMARY);
        String interestsJson = (String) flowOut.get(FLOW_OUT_INTERESTS);

        System.debug('Summary: ' + summaryText);
        System.debug('Interests: ' + interestsJson);
        // Create Meeting Note
        Meeting_Note__c meetingNote = new Meeting_Note__c();
        meetingNote.put(FN_NOTE_NAME, vc.Name);
        meetingNote.SalesPresentation__c = true;
        meetingNote.VideoCall__c = vc.id;
        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_DATE) && vc.EndDateTime != null) {
            meetingNote.put(FN_NOTE_DATE, vc.EndDateTime.date());
        }
        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_SUMMARY) && !String.isBlank(summaryText)) {
            meetingNote.put(FN_NOTE_SUMMARY, summaryText);
        }
        insert meetingNote;

        // Create Event
        Event evt = new Event(
            StartDateTime = vc.StartDateTime,
            EndDateTime   = vc.EndDateTime,
            Subject       = vc.Name
        );
        if (fieldExists('Event', FN_EVENT_MEETING_NOTE)) {
            evt.put(FN_EVENT_MEETING_NOTE, meetingNote.Id);
        }

        Id firstContactId = getFirstContactId(vc);
        if (firstContactId != null) {
            evt.WhoId = firstContactId;
        }

        System.debug('Insert event: ' + evt);

        insert evt;

        // EventRelations
        Set<Id> relationIds = new Set<Id>();
        List<EventRelation> evtRelations = new List<EventRelation>();
        for (SObject child : vc.VideoCalls) {
            Id relId = (Id) child.get('RelatedPersonId');
            if (relId != null && relationIds.add(relId) && relId != firstContactId) {
                evtRelations.add(new EventRelation(
                    EventId    = evt.Id,
                    RelationId = relId,
                    IsInvitee  = false,
                    IsWhat     = false,
                    IsParent   = true
                ));
            }
        }
        if (!evtRelations.isEmpty()) {
            System.debug('Insert evtRelations: ' + evtRelations);

            insert evtRelations;
        }

        // Client Interests
        List<ClientInterest__c> interests = parseClientInterestsJSON(interestsJson, meetingNote.Id);

        if (!interests.isEmpty()) {
            System.debug('Insert interests: ' + interests);

            insert interests;
        }

        return meetingNote.Id;
    }

    // -------------------- PUBLIC: single create ----------------------------------
    @AuraEnabled
    public static Id createMeetingNoteFromVideoCall(Id videoCallId) {
        System.assertNotEquals(null, videoCallId, 'videoCallId is required');

        // 1) Query VideoCall with related persons (Contacts) — mirrors your snippet
        VideoCall vc = [
            SELECT Name, EndDateTime, StartDateTime, Description, IntelligenceScore,
                   (SELECT RelatedPersonId, RelatedPerson.Name, RelatedPerson.Email
                    FROM VideoCalls
                    WHERE RelatedPersonId IN (SELECT Id FROM Contact))
            FROM VideoCall
            WHERE Id = :videoCallId
            LIMIT 1
        ];

        // 2) Run the flow to get the Summary + ClientInterests JSON
        Map<String, Object> flowOut = runPromptsFlow(vc);
        String summaryText   = (String) flowOut.get(FLOW_OUT_SUMMARY);
        String interestsJson = (String) flowOut.get(FLOW_OUT_INTERESTS);
        // 3) Create Meeting Note using values from the VideoCall
        Meeting_Note__c meetingNote = new Meeting_Note__c();
        meetingNote.put(FN_NOTE_NAME, vc.Name);
        meetingNote.SalesPresentation__c = true; 

        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_DATE) && vc.EndDateTime != null) {
            meetingNote.put(FN_NOTE_DATE, vc.EndDateTime.date());
        }
        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_SUMMARY) && !String.isBlank(summaryText)) {
            meetingNote.put(FN_NOTE_SUMMARY, summaryText);
        }
        insert meetingNote;

        // 4) Create Event, link to Meeting Note (if your org has FN_EVENT_MEETING_NOTE)
        Event evt = new Event(
            StartDateTime = vc.StartDateTime,
            EndDateTime   = vc.EndDateTime,
            Subject       = vc.Name
        );
        if (fieldExists('Event', FN_EVENT_MEETING_NOTE)) {
            evt.put(FN_EVENT_MEETING_NOTE, meetingNote.get('Id'));
        }
        // Optionally set WhoId to the first contact, if any
        Id firstContactId = getFirstContactId(vc);
        if (firstContactId != null) {
            evt.WhoId = firstContactId;
        }
        insert evt;

        // 5) Create EventRelation for ALL related contacts (client + internal as needed)
        Set<Id> relationIds = new Set<Id>();
        List<EventRelation> evtRelations = new List<EventRelation>();

        for (SObject child : vc.VideoCalls) {
            Id relId = (Id) child.get('RelatedPersonId');
            if (relId != null && relationIds.add(relId) && relId != firstContactId) { // add() returns false if already in set
                evtRelations.add(new EventRelation(
                    EventId    = evt.Id,
                    RelationId = relId,
                    IsInvitee  = false,
                    IsWhat     = false,
                    IsParent   = true
                ));
            }
        }
        if (!evtRelations.isEmpty()) {
            insert evtRelations;
        }

        // 6) Parse the prompt JSON and create Client Interests
        List<ClientInterest__c> cis = parseClientInterestsJSON(interestsJson, (Id) meetingNote.get('Id'));
        if (!cis.isEmpty()) {
            insert cis;
        }

        return (Id) meetingNote.get('Id');
    }
    // Grab the first contact from the child relationship for WhoId convenience
    private static Id getFirstContactId(VideoCall vc) {
        for (SObject child : vc.VideoCalls) {
            Id relId = (Id) child.get('RelatedPersonId');
            if (relId != null && String.valueOf(relId).startsWith('003')) {
                return relId; // Contact Id prefix
            }
        }
        return null;
    }

    // Parse JSON from the prompt template and build ClientInterest__c rows
    private static List<ClientInterest__c> parseClientInterestsJSON(String jsonString, Id meetingNoteId) {
        List<ClientInterest__c> rows = new List<ClientInterest__c>();
        if (String.isBlank(jsonString)) return rows;

        try {
            List<ProductFeedback> arr = parseFeedback(jsonString);
            for (ProductFeedback m : arr) {
                ClientInterest__c ci = new ClientInterest__c();
                ci.put(FN_CI_MEETING_NOTE, meetingNoteId);
                ci.put(FN_CI_STRATEGY, m.ProductId);
                ci.put(FN_CI_INTEREST, m.Rating);
                rows.add(ci);
            }
            System.debug('Parsing result: ' + rows);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to parse ClientInterests JSON: ' + e.getMessage());
        }
        return rows;
    }

    private static Boolean fieldExists(String sobjectApi, String fieldApi) {
        if (String.isBlank(sobjectApi) || String.isBlank(fieldApi)) return false;
        try {
            Schema.SObjectType t = Schema.getGlobalDescribe().get(sobjectApi);
            if (t == null) return false;
            return t.getDescribe().fields.getMap().containsKey(fieldApi);
        } catch (Exception e) {
            return false;
        }
    }

    public static List<ProductFeedback> parseFeedback(String jsonString) {
        try {
            // Parse the JSON string into a list of wrapper objects
            List<ProductFeedback> feedbackList = (List<ProductFeedback>) JSON.deserialize(jsonString, List<ProductFeedback>.class);
            System.debug('feedbackListc=>'+feedbackList);
            return feedbackList;
        } catch (Exception e) {
            System.debug('Error parsing JSON: ' + e.getMessage());
            return new List<ProductFeedback>();
        }
    }

    public class ProductFeedback {
        public String productId { get; set; }
        public String productName { get; set; }
        public Integer rating { get; set; }
        public String why { get; set; }
    }
}