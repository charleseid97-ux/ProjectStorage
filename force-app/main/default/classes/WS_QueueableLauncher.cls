public class WS_QueueableLauncher {
    
    public class MessageInput {
        @InvocableVariable(required=true)
        public String email;
        
        @InvocableVariable(required=false)
        public String templateId;
        
        @InvocableVariable(required=false)
        public String message;
        
        @InvocableVariable(required=false)
        public Id recordId;
        
        @InvocableVariable(required=false)
        public String namedCredentialName; 
    }

    @InvocableMethod(label='Send Teams Message via Queueable (auto-batched)')
    public static void launch(List<MessageInput> requests) {

        List<WS_GetUserGraphApi_Queueable.MessageData> allMessages =
            new List<WS_GetUserGraphApi_Queueable.MessageData>();

        if (requests == null || requests.isEmpty()) {
            return;
        }

        // Collect Meeting Note Ids for bulk Event query
        Set<Id> meetingNoteIds = new Set<Id>();
        for (MessageInput input : requests) {
            if (input != null && input.recordId != null) {
                meetingNoteIds.add(input.recordId);
            }
        }

        // Map MeetingNoteId -> Latest Event Id (by CreatedDate DESC)
        Map<Id, Id> meetingNoteToLatestEventId = new Map<Id, Id>();
        if (!meetingNoteIds.isEmpty()) {
            for (Event e : [
                SELECT Id, Meeting_Note__c, CreatedDate
                FROM Event
                WHERE Meeting_Note__c IN :meetingNoteIds
                ORDER BY CreatedDate DESC
            ]) {
                if (e.Meeting_Note__c != null &&
                    !meetingNoteToLatestEventId.containsKey(e.Meeting_Note__c)) {
                    meetingNoteToLatestEventId.put(e.Meeting_Note__c, e.Id);
                }
            }
        }

        for (MessageInput input : requests) {

            if (input == null || String.isBlank(input.email)) {
                continue;
            }

            List<String> emails = input.email.split(';');

            for (String rawEmail : emails) {

                if (String.isBlank(rawEmail)) {
                    continue;
                }

                WS_GetUserGraphApi_Queueable.MessageData md =
                    new WS_GetUserGraphApi_Queueable.MessageData();

                md.email = rawEmail.trim();
                md.templateId = input.templateId;
                md.message = input.message;
                md.recordId = input.recordId;
                md.namedCredentialName = input.namedCredentialName;

                // Safely replace pseudo URL (record://{Id}) with Lightning URL
                try {
                    md.message = safeReplaceRecordUrl(
                        md.message,
                        md.recordId,
                        meetingNoteToLatestEventId
                    );
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR,
                        'WS_QueueableLauncher -> URL replacement error: ' + ex.getMessage()
                    );
                }

                allMessages.add(md);
            }
        }

        if (!allMessages.isEmpty()) {
            System.enqueueJob(new WS_GetUserGraphApi_Queueable(allMessages));
        }
    }

    /**
     * Builds Lightning URL and replaces record://{Id} placeholder.
     * Returns original message if any error occurs.
     */
    private static String safeReplaceRecordUrl(
        String originalMessage,
        Id recordId,
        Map<Id, Id> meetingNoteToLatestEventId
    ) {

        if (String.isBlank(originalMessage) || recordId == null) {
            return originalMessage;
        }

        try {
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();

            Id latestEventId = meetingNoteToLatestEventId.get(recordId);

            String targetUrl;

            if (latestEventId != null) {
                targetUrl = baseUrl + '/lightning/r/Event/' + latestEventId + '/view';
            } else {
                targetUrl = baseUrl + '/lightning/r/Meeting_Note__c/' + recordId + '/view';
            }

            return originalMessage.replace('record://' + recordId, targetUrl);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'WS_QueueableLauncher.safeReplaceRecordUrl ERROR: ' + e.getMessage()
            );
            return originalMessage;
        }
    }
}