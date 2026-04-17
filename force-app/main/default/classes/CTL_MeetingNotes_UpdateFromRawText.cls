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

    // ===================================================================
    // INVOCABLE METHOD
    // ===================================================================
    @InvocableMethod(label='Update Meeting Note from Flow (AI Summary + Interests)')
    public static void updateMeetingNoteFromFlow(List<Meeting_Note__c> meetingNotes) {
        if (meetingNotes == null || meetingNotes.isEmpty()) return;

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

                // ---- 2️⃣ Mise à jour du résumé ----
                if (!String.isBlank(summaryText)) {
                    Meeting_Note__c mnToUpdate = new Meeting_Note__c(Id = mn.Id, Note__c = summaryText);
                    update mnToUpdate;
                }

                // ---- 3️⃣ Création des ClientInterests ----
                List<ClientInterest__c> cis = parseClientInterestsJSON(interestsJson, mn.Id);
                if (!cis.isEmpty()) {
                    System.debug(LoggingLevel.INFO, '[CTL_MN] Inserting ' + cis.size() + ' ClientInterest__c records for MeetingNote ' + mn.Id);
                    System.debug(LoggingLevel.DEBUG, '[CTL_MN] Sample ClientInterest__c to insert: ' + String.valueOf(cis[0]));
                    insert cis;
                }
            } 
            catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Error updating Meeting Note ' + mn.Id + ': ' + e.getTypeName() + ' - ' + e.getMessage()
                );
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
            // ---- Cas OBJET à la racine ----
            if (trimmed.startsWith('{')) {
                Object raw = JSON.deserializeUntyped(trimmed);

                if (!(raw instanceof Map<String, Object>)) {
                    System.debug(LoggingLevel.WARN, '[CI_PARSE] Root is "{" but not a Map<String,Object> (value=' + String.valueOf(raw) + ')');
                    return rows;
                }

                Map<String, Object> root = (Map<String, Object>) raw;
                System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Root keys=' + String.valueOf(root.keySet()));

                // Enveloppe d'erreur éventuelle
                if (root.containsKey('error')) {
                    System.debug(LoggingLevel.WARN, '[CI_PARSE] Error envelope from flow: ' + String.valueOf(root.get('error')));
                    return rows;
                }

                // Enveloppe avec liste : Result/result/Products/products
                Object listCandidate = null;
                if (root.containsKey('Result')) {
                    listCandidate = root.get('Result');
                } else if (root.containsKey('result')) {
                    listCandidate = root.get('result');
                } else if (root.containsKey('Products')) {
                    listCandidate = root.get('Products');
                } else if (root.containsKey('products')) {
                    listCandidate = root.get('products');
                } else if (root.containsKey('results')) {
                    listCandidate = root.get('results');
                } else if (root.containsKey('Results')) {
                    listCandidate = root.get('Results');
                }

                if (listCandidate != null) {
                    // Cas : liste d'objets
                    if (listCandidate instanceof List<Object>) {
                        List<Object> productsList = (List<Object>) listCandidate;
                        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Detected envelope with list, size=' + productsList.size());

                        for (Object o : productsList) {
                            if (o instanceof Map<String, Object>) {
                                ClientInterest__c ci = buildClientInterestFromMap((Map<String, Object>) o, meetingNoteId);
                                if (ci != null) rows.add(ci);
                            }
                        }

                        System.debug(LoggingLevel.INFO, '[CI_PARSE] Built ' + rows.size() + ' CI rows from envelope list');
                        return rows;
                    }

                    // Cas : un seul objet dans Result/products
                    if (listCandidate instanceof Map<String, Object>) {
                        System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Detected envelope with single object');
                        ClientInterest__c ci = buildClientInterestFromMap((Map<String, Object>) listCandidate, meetingNoteId);
                        if (ci != null) rows.add(ci);

                        System.debug(LoggingLevel.INFO, '[CI_PARSE] Built ' + rows.size() + ' CI rows from single object in envelope');
                        return rows;
                    }
                }

                // Sinon : on traite la racine comme un seul produit
                System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Treating root object as single product');
                ClientInterest__c singleCi = buildClientInterestFromMap(root, meetingNoteId);
                if (singleCi != null) rows.add(singleCi);

                System.debug(LoggingLevel.INFO, '[CI_PARSE] Built ' + rows.size() + ' CI rows from single root object');
                return rows;
            }

            // ---- Cas TABLEAU à la racine ----
            if (trimmed.startsWith('[')) {
                List<Object> arr = (List<Object>) JSON.deserializeUntyped(trimmed);
                System.debug(LoggingLevel.DEBUG, '[CI_PARSE] Root is ARRAY, size=' + arr.size());

                for (Object o : arr) {
                    if (o instanceof Map<String, Object>) {
                        ClientInterest__c ci = buildClientInterestFromMap((Map<String, Object>) o, meetingNoteId);
                        if (ci != null) rows.add(ci);
                    }
                }

                System.debug(LoggingLevel.INFO, '[CI_PARSE] Built ' + rows.size() + ' CI rows from array');
                return rows;
            }

            // ---- Format non supporté ----
            System.debug(LoggingLevel.WARN, '[CI_PARSE] JSON does not start with { or [ - unsupported format');
        } 
        catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[CI_PARSE] Exception while parsing JSON: ' + e.getTypeName() + ' - ' + e.getMessage());
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
}