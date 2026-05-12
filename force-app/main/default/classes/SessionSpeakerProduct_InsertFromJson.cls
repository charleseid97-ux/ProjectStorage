public without sharing class SessionSpeakerProduct_InsertFromJson {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public String json;

        @InvocableVariable(required=true)
        public Id sessionId;
    }

    public class ResultWrapper {
        @InvocableVariable
        public Integer insertedCount;

        @InvocableVariable
        public String errorMessage;
    }

    @InvocableMethod(
        label='Insert SessionSpeakerProduct from JSON'
        description='Insère des sessionSpeakerProduct__c à partir d’un JSON et force le champ Session__c.'
    )
    public static List<ResultWrapper> execute(List<InputWrapper> inputs) {
        List<ResultWrapper> results = new List<ResultWrapper>();
        system.debug(LoggingLevel.INFO, 'Received ' + ((inputs == null) ? 0 : inputs.size()) + ' inputs for SessionSpeakerProduct_InsertFromJson');

        for (InputWrapper input : safeInputs(inputs)) {
            results.add(processInput(input));
        }

        return results;
    }

    private static List<InputWrapper> safeInputs(List<InputWrapper> inputs) {
        return (inputs == null) ? new List<InputWrapper>() : inputs;
    }

    private static List<ResultWrapper> buildNoAccessResults(List<InputWrapper> inputs) {
        Integer n = (inputs == null) ? 0 : inputs.size();
        List<ResultWrapper> results = new List<ResultWrapper>();

        for (Integer i = 0; i < n; i++) {
            ResultWrapper r = new ResultWrapper();
            r.insertedCount = 0;
            r.errorMessage = 'Insufficient access to create sessionSpeakerProduct__c';
            results.add(r);
        }
        return results;
    }

    private static ResultWrapper processInput(InputWrapper input) {
        ResultWrapper res = new ResultWrapper();
        res.insertedCount = 0;
        res.errorMessage = null;

        if (!isValidInput(input)) {
            return res;
        }

        try {
            List<sessionSpeakerProduct__c> toInsert = buildRecordsFromJson(input.json, input.sessionId);
            if (toInsert.isEmpty()) {
                updateEventToTriggerApproval(input.sessionId);
                return res;
            }

            List<SObject> safeRecords = stripCreatable(toInsert);
            InsertOutcome outcome = insertPartial(safeRecords);

            res.insertedCount = outcome.successCount;
            res.errorMessage = outcome.firstError;
            return res;

        } catch (System.JSONException je) {
            res.errorMessage = je.getMessage();
            return res;
        } catch (Exception e) {
            res.errorMessage = e.getMessage();
            return res;
        }
    }

    private static Boolean isValidInput(InputWrapper input) {
        return input != null && input.sessionId != null && !String.isBlank(input.json);
    }

    /**
     * Builds records from the JSON payload. Each item is expected to be a map of field API names.
     */
    private static List<sessionSpeakerProduct__c> buildRecordsFromJson(String json, Id sessionId) {
        List<sessionSpeakerProduct__c> toInsert = new List<sessionSpeakerProduct__c>();

        Object parsed = System.JSON.deserializeUntyped(json);
        if (!(parsed instanceof List<Object>)) {
            return toInsert;
        }

        for (Object o : (List<Object>) parsed) {
            Map<String, Object> m = (o instanceof Map<String, Object>) ? (Map<String, Object>) o : null;
            if (m == null) continue;

            sessionSpeakerProduct__c rec = mapToRecord(m, sessionId);
            if (isEmptyLine(rec)) continue;

            toInsert.add(rec);
        }

        return toInsert;
    }

    /**
     * Maps a JSON item to a record and applies the sessionId.
     * Supports backward compatibility if the payload still sends Speaker__c.
     */
    private static sessionSpeakerProduct__c mapToRecord(Map<String, Object> m, Id sessionId) {
        sessionSpeakerProduct__c rec = new sessionSpeakerProduct__c();
        rec.Session__c = sessionId;

        rec.speakerContact__c = pickId(m, 'speakerContact__c', 'Speaker__c');
        rec.strategy__c = asId(m.get('strategy__c'));
        rec.Language__c = asString(m.get('Language__c'));
        rec.speakerLanguage__c = asString(m.get('speakerLanguage__c'));
        rec.startTime__c = parseTimeValue(asString(m.get('startTime__c')));
        rec.endTime__c = parseTimeValue(asString(m.get('endTime__c')));
        return rec;
    }

    private static Boolean isEmptyLine(sessionSpeakerProduct__c rec) {
        return rec.speakerContact__c == null && rec.strategy__c == null;
    }

    private static List<SObject> stripCreatable(List<sessionSpeakerProduct__c> records) {
        SObjectAccessDecision accessDecision = Security.stripInaccessible(
            AccessType.CREATABLE,
            records
        );
        return accessDecision.getRecords();
    }

    private class InsertOutcome {
        Integer successCount;
        String firstError;
        InsertOutcome(Integer ok, String err) {
            successCount = ok;
            firstError = err;
        }
    }

    /**
     * Inserts with partial success and returns the number of successes + the first error message.
     */
    private static InsertOutcome insertPartial(List<SObject> records) {
        Database.SaveResult[] saveResults = Database.insert(records, false);

        Integer ok = 0;
        String firstError;

        for (Database.SaveResult sr : saveResults) {
            if (sr.isSuccess()) {
                ok++;
                continue;
            }

            if (firstError == null && sr.getErrors() != null && !sr.getErrors().isEmpty()) {
                firstError = sr.getErrors()[0].getMessage() 
                    + ' | FIELDS: ' + sr.getErrors()[0].getFields();
                    system.debug('firstError =============='+firstError);
            }
        }

        return new InsertOutcome(ok, firstError);
    }

    private static Id pickId(Map<String, Object> m, String primaryKey, String fallbackKey) {
        Id v = asId(m.get(primaryKey));
        return (v != null) ? v : asId(m.get(fallbackKey));
    }

    private static Id asId(Object v) {
        return (v == null) ? null : (Id) v;
    }

    private static String asString(Object v) {
        return (v == null) ? null : String.valueOf(v);
    }

    private static Time parseTimeValue(String value) {
        if (String.isBlank(value)) return null;

        if (value.contains('.')) {
            value = value.substringBefore('.');
        }

        List<String> parts = value.split(':');
        Integer hh = Integer.valueOf(parts[0]);
        Integer mm = Integer.valueOf(parts[1]);
        Integer ss = (parts.size() > 2) ? Integer.valueOf(parts[2]) : 0;

        return Time.newInstance(hh, mm, ss, 0);
    }

    /**
     * Updates the Event to trigger the approval logic when no SSP is inserted.
     * (when SSP are inserted they update Event Name and this starts the event approvals)
     */
    private static void updateEventToTriggerApproval(Id sessionId) {
        if (sessionId == null) return;

        // Minimal update used only to fire Event__c update triggers
        update new Event__c(
            Id = sessionId
        );
    }

}