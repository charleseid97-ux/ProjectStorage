public without sharing class CTL_MeetingNotes_UpdateFromRawText {

    // ---- FLOW CONTRACT ----
    private static final String FLOW_NAME           = 'AL_RawText_GeneratePromptsResponses';
    private static final String FLOW_VAR_IN_MEETING = 'MeetingNote'; // Variable d'entrée du flow
    private static final String FLOW_OUT_SUMMARY    = 'Output_Summary';
    private static final String FLOW_OUT_INTERESTS  = 'Output_ClientInterests';

    // ---- SCHEMA ----
    private static final String MEETING_NOTE_SOBJ   = 'Meeting_Note__c';
    private static final String FN_NOTE_SUMMARY     = 'Note__c';
    private static final String FN_CI_MEETING_NOTE  = 'MeetingNote__c';
    private static final String FN_CI_STRATEGY      = 'Strategy__c';
    private static final String FN_CI_INTEREST      = 'Interest__c';
    private static final String FN_CI_PRODUCTCODE   = 'ProductCode__c';

    // ---- LOGGING ----
    private static final String LOG_CI_BUILT        = '[CI_PARSE] Built ';

    // ===================================================================
    // INVOCABLE METHOD
    // ===================================================================
    @InvocableMethod(label='Update Meeting Note from Flow (AI Summary + Interests)')
    public static void updateMeetingNoteFromFlow(List<Meeting_Note__c> meetingNotes) {
        if (meetingNotes == null || meetingNotes.isEmpty()) return;

        List<Meeting_Note__c> notesToUpdate = new List<Meeting_Note__c>();
        List<ClientInterest__c> allClientInterests = new List<ClientInterest__c>();

        for (Meeting_Note__c mn : meetingNotes) {
            try {
                if (mn == null || mn.Id == null) continue;
                //debug all populated  fields : 
                for(Schema.SObjectField f : Schema.getGlobalDescribe().get(MEETING_NOTE_SOBJ).getDescribe().fields.getMap().values()) {
                    String fieldName = f.getDescribe().getName();
                    Object value = mn.get(fieldName);
                    System.debug(LoggingLevel.DEBUG, '[CTL_MN] Field ' + fieldName + ' = ' + String.valueOf(value));
                }
                // ---- 1️⃣ Appel du flow ----
                Flow.Interview iv = Flow.Interview.createInterview(FLOW_NAME, new Map<String, Object>{ FLOW_VAR_IN_MEETING => mn });
                iv.start();

                String summaryText   = (String) iv.getVariableValue(FLOW_OUT_SUMMARY);
                String interestsJson = (String) iv.getVariableValue(FLOW_OUT_INTERESTS);

                System.debug(LoggingLevel.DEBUG, '[CTL_MN] Summary from flow: ' + summaryText);
                System.debug(LoggingLevel.DEBUG, '[CTL_MN] Interests JSON from flow: ' + interestsJson);

                // ---- 2️⃣ Accumulate Meeting Notes to update ----
                if (!String.isBlank(summaryText)) {
                    Meeting_Note__c mnToUpdate = new Meeting_Note__c(Id = mn.Id, Note__c = summaryText);
                    notesToUpdate.add(mnToUpdate);
                }

                // ---- 3️⃣ Accumulate Client Interests ----
                List<ClientInterest__c> cis = parseClientInterestsJSON(interestsJson, mn.Id);
                if (!cis.isEmpty()) {
                    System.debug(LoggingLevel.INFO, '[CTL_MN] Preparing ' + cis.size() + ' ClientInterest__c records for MeetingNote ' + mn.Id);
                    System.debug(LoggingLevel.DEBUG, '[CTL_MN] Sample ClientInterest__c to insert: ' + String.valueOf(cis[0]));
                    allClientInterests.addAll(cis);
                }
            } 
            catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Error processing Meeting Note ' + mn.Id + ': ' + e.getTypeName() + ' - ' + e.getMessage()
                );
            }
        }

        // ---- 4️⃣ Bulk DML operations outside loop ----
        if (!notesToUpdate.isEmpty()) {
            try {
                update notesToUpdate;
                System.debug(LoggingLevel.INFO, '[CTL_MN] Successfully updated ' + notesToUpdate.size() + ' Meeting Note(s)');

                // Send Notification
                Set<String> recipients = new Set<String>{ UserInfo.getUserId() };
                sendActionDoneNotification(recipients, notesToUpdate[0].Id, 'Meeting Note Updated', 'The AI job has successfully updated the meeting note.');
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, '[CTL_MN] Error updating Meeting Notes: ' + e.getTypeName() + ' - ' + e.getMessage());
            }
        }

        if (!allClientInterests.isEmpty()) {
            try {
                insert allClientInterests;
                System.debug(LoggingLevel.INFO, '[CTL_MN] Successfully inserted ' + allClientInterests.size() + ' ClientInterest__c record(s)');
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, '[CTL_MN] Error inserting ClientInterests: ' + e.getTypeName() + ' - ' + e.getMessage());
            }
        }
    }

    // Parse le JSON retourné par le flow et construit une liste de ClientInterest__c
    @TestVisible
    private static List<ClientInterest__c> parseClientInterestsJSON(String jsonString, Id meetingNoteId) {
        List<ClientInterest__c> rows = new List<ClientInterest__c>();

        if (String.isBlank(jsonString)) {
            System.debug(LoggingLevel.WARN, '[CI_PARSE] JSON is blank/null - nothing to parse');
            return rows;
        }

        String trimmed = jsonString.trim();
        String preview = trimmed.substring(0, Math.min(260, trimmed.length()));
        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Raw JSON: ' + preview);

        try {
            if (trimmed.startsWith('{')) {
                return parseObjectJSON(trimmed, meetingNoteId);
            }

            if (trimmed.startsWith('[')) {
                return parseArrayJSON(trimmed, meetingNoteId);
            }

            System.debug(LoggingLevel.WARN, '[CI_PARSE] JSON does not start with { or [ - unsupported format');
        } 
        catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[CI_PARSE] Exception while parsing JSON: ' + e.getTypeName() + ' - ' + e.getMessage());
        }

        return rows;
    }

    // Parse un JSON qui commence par un objet
    @TestVisible
    private static List<ClientInterest__c> parseObjectJSON(String jsonString, Id meetingNoteId) {
        List<ClientInterest__c> rows = new List<ClientInterest__c>();
        Object raw = JSON.deserializeUntyped(jsonString);

        if (!(raw instanceof Map<String, Object>)) {
            System.debug(LoggingLevel.WARN, '[CI_PARSE] Root is "{" but not a Map<String,Object> (value=' + String.valueOf(raw) + ')');
            return rows;
        }

        Map<String, Object> root = (Map<String, Object>) raw;
        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Root keys=' + String.valueOf(root.keySet()));

        if (root.containsKey('error')) {
            System.debug(LoggingLevel.WARN, '[CI_PARSE] Error envelope from flow: ' + String.valueOf(root.get('error')));
            return rows;
        }

        Object listCandidate = extractListCandidate(root);
        
        if (listCandidate != null) {
            return processListCandidate(listCandidate, meetingNoteId);
        }

        // Sinon : on traite la racine comme un seul produit
        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Treating root object as single product');
        ClientInterest__c singleCi = buildClientInterestFromMap(root, meetingNoteId);
        if (singleCi != null) rows.add(singleCi);

        System.debug(LoggingLevel.INFO, LOG_CI_BUILT + rows.size() + ' CI rows from single root object');
        return rows;
    }

    // Parse un JSON qui commence par un tableau
    @TestVisible
    private static List<ClientInterest__c> parseArrayJSON(String jsonString, Id meetingNoteId) {
        List<ClientInterest__c> rows = new List<ClientInterest__c>();
        List<Object> arr = (List<Object>) JSON.deserializeUntyped(jsonString);
        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Root is ARRAY, size=' + arr.size());

        for (Object o : arr) {
            if (o instanceof Map<String, Object>) {
                ClientInterest__c ci = buildClientInterestFromMap((Map<String, Object>) o, meetingNoteId);
                if (ci != null) rows.add(ci);
            }
        }

        System.debug(LoggingLevel.INFO, LOG_CI_BUILT + rows.size() + ' CI rows from array');
        return rows;
    }

    // Extrait le candidat de liste depuis une enveloppe JSON
    @TestVisible
    private static Object extractListCandidate(Map<String, Object> root) {
        if (root.containsKey('Result')) return root.get('Result');
        if (root.containsKey('result')) return root.get('result');
        if (root.containsKey('Products')) return root.get('Products');
        if (root.containsKey('products')) return root.get('products');
        if (root.containsKey('results')) return root.get('results');
        if (root.containsKey('Results')) return root.get('Results');
        return null;
    }

    // Traite le candidat de liste (peut être une liste ou un objet unique)
    @TestVisible
    private static List<ClientInterest__c> processListCandidate(Object listCandidate, Id meetingNoteId) {
        List<ClientInterest__c> rows = new List<ClientInterest__c>();

        if (listCandidate instanceof List<Object>) {
            List<Object> productsList = (List<Object>) listCandidate;
            System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Detected envelope with list, size=' + productsList.size());

            for (Object o : productsList) {
                if (o instanceof Map<String, Object>) {
                    ClientInterest__c ci = buildClientInterestFromMap((Map<String, Object>) o, meetingNoteId);
                    if (ci != null) rows.add(ci);
                }
            }

            System.debug(LoggingLevel.INFO, LOG_CI_BUILT + rows.size() + ' CI rows from envelope list');
            return rows;
        }

        if (listCandidate instanceof Map<String, Object>) {
            System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Detected envelope with single object');
            ClientInterest__c ci = buildClientInterestFromMap((Map<String, Object>) listCandidate, meetingNoteId);
            if (ci != null) rows.add(ci);

            System.debug(LoggingLevel.INFO, LOG_CI_BUILT + rows.size() + ' CI rows from single object in envelope');
            return rows;
        }

        return rows;
    }

    // Construit 1 ClientInterest__c à partir d'un Map JSON (ou null si données incomplètes)
    @TestVisible
    private static ClientInterest__c buildClientInterestFromMap(Map<String, Object> m, Id meetingNoteId) {
        if (m == null) return null;

        // StrategyId / strategyId
        String strategyId = (String)(m.containsKey('strategyId') ? m.get('strategyId'): m.get('StrategyId'));

        // Rating / rating
        Object ratingRaw = m.containsKey('rating') ? m.get('rating') : m.get('Rating');
        Integer rating;
        try {
            rating = (ratingRaw == null) ? null : Integer.valueOf(String.valueOf(ratingRaw));
        } catch (Exception e) {
            rating = null;
        }

        // ProductName / productName
        String productCode = (String)(m.containsKey('productName')? m.get('productName') : m.containsKey('ProductName')? m.get('ProductName') : null);

        if (String.isBlank(strategyId) || rating == null) {
            System.debug(LoggingLevel.WARN, '[CI_PARSE] Skipping item: missing strategyId or rating. strategyId=' + String.valueOf(strategyId) + ', rating=' + String.valueOf(ratingRaw));
            return null;
        }

        ClientInterest__c ci = new ClientInterest__c();
        ci.put(FN_CI_MEETING_NOTE, meetingNoteId);
        ci.put(FN_CI_STRATEGY, strategyId);
        ci.put(FN_CI_INTEREST, rating);
        ci.put(FN_CI_PRODUCTCODE, productCode);
        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Built ClientInterest__c: MeetingNote=' + meetingNoteId + ', StrategyId=' + strategyId + ', Rating=' + rating);  
        return ci;
    }

    public static void sendActionDoneNotification(Set<String> recipientUserIds, Id targetRecordId, String title, String body) {
        if (recipientUserIds == null || recipientUserIds.isEmpty()) {
            return;
        }

        CustomNotificationType notifType = [SELECT Id, DeveloperName
                                            FROM CustomNotificationType
                                            WHERE DeveloperName = 'MeetingNoteAIUpdateFinish'
                                            LIMIT 1];

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(title);
        notification.setBody(body);
        notification.setNotificationTypeId(notifType.Id);
        notification.setTargetId(targetRecordId);

        try {
            notification.send(recipientUserIds);
        } catch (Exception e) {
            System.debug('Custom notification failed: ' + e.getMessage());
            throw e;
        }
    }
}