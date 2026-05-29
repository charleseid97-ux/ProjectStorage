public without sharing class MicrosoftGraphMeetingService {
    private static final String DEFAULT_NAMED_CREDENTIAL = 'MicrosoftGraphSF';
    private static final String DEFAULT_TIME_ZONE = 'Europe/Paris';
    private static final String CONTENT_TYPE_JSON = 'application/json';
    private static final String DEFAULT_BODY_HTML = '<p>Réunion générée depuis Salesforce.</p>';
    private static final Integer TIMEOUT_MS = 120000;

    public class Participant {
        public String email;
        public String name;
        public Boolean optional;

        public Participant(String email, String name, Boolean optional) {
            this.email = email;
            this.name = name;
            this.optional = optional == null ? false : optional;
        }
    }

    public class MeetingRequest {
        public String namedCredentialName;
        public String subject;
        public String bodyHtml;
        public String message;
        public Id templateId;
        public Id relatedRecordId;
        public Date startDate;
        public String startTime;
        public Date endDate;
        public String endTime;
        public String timeZone;
        public List<Participant> participants;
        public Boolean generateTeamsLink;
    }

    public class MeetingResponse {
        public Boolean success;
        public Integer statusCode;
        public String status;
        public String responseBody;
        public String eventId;
        public String joinUrl;
        public String errorMessage;
    }

    public static MeetingResponse createTeamsMeeting(MeetingRequest meetingRequest) {
        validateRequest(meetingRequest);

        HttpRequest request = new HttpRequest();
        request.setEndpoint(buildEndpoint(meetingRequest.namedCredentialName, '/me/events'));
        request.setMethod('POST');
        request.setHeader('Content-Type', CONTENT_TYPE_JSON);
        request.setHeader('Accept', CONTENT_TYPE_JSON);
        request.setHeader('Prefer', 'outlook.timezone="' + getTimeZone(meetingRequest) + '"');
        request.setTimeout(TIMEOUT_MS);
        request.setBody(JSON.serialize(buildPayload(meetingRequest)));

        HttpResponse response = new Http().send(request);
        return parseResponse(response);
    }

    private static void validateRequest(MeetingRequest meetingRequest) {
        if (meetingRequest == null) {
            throw new IllegalArgumentException('Meeting request is required.');
        }

        if (String.isBlank(meetingRequest.subject)) {
            throw new IllegalArgumentException('Subject is required.');
        }

        if (meetingRequest.startDate == null || String.isBlank(meetingRequest.startTime)) {
            throw new IllegalArgumentException('Start date and time are required.');
        }

        if (meetingRequest.endDate == null || String.isBlank(meetingRequest.endTime)) {
            throw new IllegalArgumentException('End date and time are required.');
        }

        if (meetingRequest.participants == null || meetingRequest.participants.isEmpty()) {
            throw new IllegalArgumentException('At least one participant is required.');
        }

        for (Participant participant : meetingRequest.participants) {
            if (participant == null || String.isBlank(participant.email)) {
                throw new IllegalArgumentException('Each participant must have an email.');
            }
        }
    }

    private static Map<String, Object> buildPayload(MeetingRequest meetingRequest) {
        String timeZone = getTimeZone(meetingRequest);

        Map<String, Object> payload = new Map<String, Object>{
            'subject' => meetingRequest.subject,
            'body' => new Map<String, Object>{
                'contentType' => 'HTML',
                'content' => buildHtmlBody(meetingRequest)
            },
            'start' => buildDateTimeMap(meetingRequest.startDate, meetingRequest.startTime, timeZone),
            'end' => buildDateTimeMap(meetingRequest.endDate, meetingRequest.endTime, timeZone),
            'attendees' => buildAttendees(meetingRequest.participants)
        };

        if (meetingRequest.generateTeamsLink == true) {
            payload.put('isOnlineMeeting', true);
            payload.put('onlineMeetingProvider', 'teamsForBusiness');
        }

        return payload;
    }

    private static String buildHtmlBody(MeetingRequest meetingRequest) {
        if (!String.isBlank(meetingRequest.bodyHtml)) {
            return meetingRequest.bodyHtml;
        }

        if (meetingRequest.templateId != null && meetingRequest.relatedRecordId != null) {
            return renderTemplateBody(
                meetingRequest.templateId,
                meetingRequest.relatedRecordId,
                meetingRequest.subject,
                meetingRequest.message
            );
        }

        return DEFAULT_BODY_HTML;
    }

    private static String renderTemplateBody(
        Id templateId,
        Id relatedRecordId,
        String subject,
        String message
    ) {
        Messaging.SingleEmailMessage renderedEmail =
            Messaging.renderStoredEmailTemplate(
                templateId,
                UserInfo.getUserId(),
                relatedRecordId
            );

        String htmlBody = renderedEmail.getHtmlBody();

        if (String.isBlank(htmlBody)) {
            return DEFAULT_BODY_HTML;
        }

        htmlBody = htmlBody.replace('[!subject]', subject);
        htmlBody = htmlBody.replace('[!message]', safeString(message));

        return htmlBody;
    }

    private static Map<String, Object> buildDateTimeMap(
        Date dateValue,
        String timeValue,
        String timeZone
    ) {
        return new Map<String, Object>{
            'dateTime' => String.valueOf(dateValue) + 'T' + normalizeTime(timeValue),
            'timeZone' => timeZone
        };
    }

    private static String normalizeTime(String timeValue) {
        if (String.isBlank(timeValue)) {
            throw new IllegalArgumentException('Time value is required.');
        }

        List<String> parts = timeValue.trim().split(':');

        if (parts.size() < 2) {
            throw new IllegalArgumentException('Invalid time format: ' + timeValue);
        }

        String hour = parts[0].leftPad(2, '0');
        String minute = parts[1].leftPad(2, '0');
        String second = parts.size() > 2 ? parts[2].leftPad(2, '0') : '00';

        return hour + ':' + minute + ':' + second;
    }

    private static List<Object> buildAttendees(List<Participant> participants) {
        List<Object> attendees = new List<Object>();

        for (Participant participant : participants) {
            String displayName = String.isBlank(participant.name)
                ? participant.email
                : participant.name;

            attendees.add(new Map<String, Object>{
                'emailAddress' => new Map<String, Object>{
                    'address' => participant.email,
                    'name' => displayName
                },
                'type' => participant.optional == true ? 'optional' : 'required'
            });
        }

        return attendees;
    }

    private static MeetingResponse parseResponse(HttpResponse httpResponse) {
        MeetingResponse result = new MeetingResponse();
        result.statusCode = httpResponse.getStatusCode();
        result.status = httpResponse.getStatus();
        result.responseBody = httpResponse.getBody();
        result.success = result.statusCode >= 200 && result.statusCode < 300;

        if (!result.success) {
            result.errorMessage = result.responseBody;
            return result;
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(result.responseBody);

        result.eventId = (String) responseMap.get('id');

        Map<String, Object> onlineMeeting =
            (Map<String, Object>) responseMap.get('onlineMeeting');

        if (onlineMeeting != null) {
            result.joinUrl = (String) onlineMeeting.get('joinUrl');
        }

        return result;
    }

    private static String buildEndpoint(String namedCredentialName, String path) {
        String credentialName = String.isBlank(namedCredentialName)
            ? DEFAULT_NAMED_CREDENTIAL
            : namedCredentialName.trim();

        return 'callout:' + credentialName + path;
    }

    private static String getTimeZone(MeetingRequest meetingRequest) {
        return String.isBlank(meetingRequest.timeZone)
            ? DEFAULT_TIME_ZONE
            : meetingRequest.timeZone.trim();
    }

    private static String safeString(String value) {
        return String.isBlank(value) ? '' : value;
    }
}