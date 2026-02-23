public without sharing class CTL_MeetingNotes_AIOrchestrator {

    // -------------------- FLOW CONTRACT (from your metadata) --------------------
    private static final String FLOW_NAME             = 'AL_VideoCall_GeneratePromptsResponses';
    private static final String FLOW_VAR_IN_VIDEOCALL = 'VideoCall';
    public  static final String FLOW_OUT_SUMMARY      = 'Output_VideoCallSummary';
    public  static final String FLOW_OUT_INTERESTS    = 'Output_ClientInterests';

    // -------------------- MEETING NOTE SCHEMA -----------------------------------
    private static final String MEETING_NOTE_SOBJ     = 'Meeting_Note__c';
    private static final String FN_NOTE_NAME          = 'Name';
    private static final String FN_NOTE_DATE          = 'Date__c';
    private static final String FN_NOTE_SUMMARY       = 'Note__c';
    private static final String FN_NOTE_COMPANY       = 'Company__c'; // ✅ NEW

    // -------------------- EVENT SCHEMA (standard) --------------------------------
    private static final String FN_EVENT_MEETING_NOTE = 'Meeting_Note__c';

    // -------------------- CLIENT INTEREST SCHEMA ---------------------------------
    private static final String CLIENT_INTEREST_SOBJ  = 'ClientInterest__c';
    private static final String FN_CI_MEETING_NOTE    = 'MeetingNote__c';
    private static final String FN_CI_STRATEGY        = 'Strategy__c';
    private static final String FN_CI_INTEREST        = 'Interest__c';

    public interface FlowRunner {
        Map<String, Object> run(VideoCall vc);
    }

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

        Set<Id> videoCallIds = new Set<Id>();
        for (FlowInput input : inputs) {
            if (input != null && input.videoCallId != null) {
                videoCallIds.add(input.videoCallId);
            }
        }
        if (videoCallIds.isEmpty()) return results;

        // ✅ NEW: query RelatedRecordId
        Map<Id, VideoCall> videoCallMap = new Map<Id, VideoCall>(
            [SELECT Name, EndDateTime, StartDateTime, Description, IntelligenceScore, RelatedRecordId,OwnerId,
                    (SELECT RelatedPersonId, RelatedPerson.Name, RelatedPerson.Email
                     FROM VideoCalls
                     WHERE RelatedPersonId IN (SELECT Id FROM Contact))
             FROM VideoCall
             WHERE Id IN :videoCallIds]
        );

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

        Meeting_Note__c meetingNote = new Meeting_Note__c();
        meetingNote.put(FN_NOTE_NAME, vc.Name);
        meetingNote.SalesPresentation__c = true;
        meetingNote.VideoCall__c = vc.Id;
        meetingNote.OwnerId = vc.OwnerId;

        // ✅ NEW: set Company__c from VideoCall.RelatedRecordId (with safety checks)
        setCompanyFromVideoCall(meetingNote, vc);

        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_DATE) && vc.EndDateTime != null) {
            meetingNote.put(FN_NOTE_DATE, vc.EndDateTime.date());
        }
        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_SUMMARY) && !String.isBlank(summaryText)) {
            meetingNote.put(FN_NOTE_SUMMARY, summaryText);
        }
        insert meetingNote;
        try {
            meetingNote.OwnerId = vc.OwnerId;
            update meetingNote;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to update MeetingNote OwnerId for VC ' + vc.Id + ': ' + e.getMessage());            
        }

        Event evt = new Event(
            StartDateTime = vc.StartDateTime,
            EndDateTime   = vc.EndDateTime,
            Subject       = vc.Name,
            OwnerId       = vc.OwnerId
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
        try {
            evt.OwnerId= vc.OwnerId;
            update evt; 
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to update Event after insert for VC ' + vc.Id + ': ' + e.getMessage());
        }

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

        // ✅ NEW: query RelatedRecordId
        VideoCall vc = [
            SELECT Name, EndDateTime, StartDateTime, Description, IntelligenceScore, RelatedRecordId,
                   (SELECT RelatedPersonId, RelatedPerson.Name, RelatedPerson.Email
                    FROM VideoCalls
                    WHERE RelatedPersonId IN (SELECT Id FROM Contact))
            FROM VideoCall
            WHERE Id = :videoCallId
            LIMIT 1
        ];

        Map<String, Object> flowOut = runPromptsFlow(vc);
        String summaryText   = (String) flowOut.get(FLOW_OUT_SUMMARY);
        String interestsJson = (String) flowOut.get(FLOW_OUT_INTERESTS);

        Meeting_Note__c meetingNote = new Meeting_Note__c();
        meetingNote.put(FN_NOTE_NAME, vc.Name);
        meetingNote.SalesPresentation__c = true;

        // ✅ NEW: set Company__c from VideoCall.RelatedRecordId (with safety checks)
        setCompanyFromVideoCall(meetingNote, vc);

        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_DATE) && vc.EndDateTime != null) {
            meetingNote.put(FN_NOTE_DATE, vc.EndDateTime.date());
        }
        if (fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_SUMMARY) && !String.isBlank(summaryText)) {
            meetingNote.put(FN_NOTE_SUMMARY, summaryText);
        }
        insert meetingNote;

        Event evt = new Event(
            StartDateTime = vc.StartDateTime,
            EndDateTime   = vc.EndDateTime,
            Subject       = vc.Name
        );
        if (fieldExists('Event', FN_EVENT_MEETING_NOTE)) {
            evt.put(FN_EVENT_MEETING_NOTE, meetingNote.get('Id'));
        }

        Id firstContactId = getFirstContactId(vc);
        if (firstContactId != null) {
            evt.WhoId = firstContactId;
        }
        insert evt;

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
            insert evtRelations;
        }

        List<ClientInterest__c> cis = parseClientInterestsJSON(interestsJson, (Id) meetingNote.get('Id'));
        if (!cis.isEmpty()) {
            insert cis;
        }

        return (Id) meetingNote.get('Id');
    }

    // ✅ NEW helper: sets Company__c from VideoCall.RelatedRecordId safely
    private static void setCompanyFromVideoCall(Meeting_Note__c note, VideoCall vc) {
        if (note == null || vc == null) return;
        if (!fieldExists(MEETING_NOTE_SOBJ, FN_NOTE_COMPANY)) return;

        Id rrId = vc.RelatedRecordId;
        if (rrId == null) return;

        // If Company__c is a lookup to Account, keep only Account ids (001...)
        if (String.valueOf(rrId).startsWith('001')) {
            note.put(FN_NOTE_COMPANY, rrId);
        } else {
            // Keep a debug to understand why it didn't populate
            System.debug(LoggingLevel.WARN,
                'VideoCall.RelatedRecordId is not an Account (001...). Value=' + rrId
            );
        }
    }

    private static Id getFirstContactId(VideoCall vc) {
        for (SObject child : vc.VideoCalls) {
            Id relId = (Id) child.get('RelatedPersonId');
            if (relId != null && String.valueOf(relId).startsWith('003')) {
                return relId;
            }
        }
        return null;
    }

    private static List<ClientInterest__c> parseClientInterestsJSON(String jsonString, Id meetingNoteId) {
        List<ClientInterest__c> rows = new List<ClientInterest__c>();
        if (String.isBlank(jsonString)) return rows;

        try {
            List<ProductFeedback> arr = parseFeedback(jsonString);
            for (ProductFeedback m : arr) {
                ClientInterest__c ci = new ClientInterest__c();
                ci.put(FN_CI_MEETING_NOTE, meetingNoteId);

                // Your wrapper uses lowerCamelCase (productId/rating)
                ci.put(FN_CI_STRATEGY, m.productId);
                ci.put(FN_CI_INTEREST, m.rating);

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
            List<ProductFeedback> feedbackList =
                (List<ProductFeedback>) JSON.deserialize(jsonString, List<ProductFeedback>.class);
            System.debug('feedbackListc=>' + feedbackList);
            return feedbackList;
        } catch (Exception e) {
            System.debug('Error parsing JSON: ' + e.getMessage());
            return new List<ProductFeedback>();
        }
    }

    public class ProductFeedback {
        public String  productId   { get; set; }
        public String  productName { get; set; }
        public Integer rating      { get; set; }
        public String  why         { get; set; }
    }
}