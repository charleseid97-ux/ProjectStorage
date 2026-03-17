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
        if (!Schema.sObjectType.sessionSpeakerProduct__c.isCreateable()) {
            return buildNoAccessResults(inputs);
        }

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
                firstError = sr.getErrors()[0].getMessage();
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
}