public without sharing class EventAttendee_InsertFromIds {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id eventId;

        @InvocableVariable
        public String contactIdsJson;

        @InvocableVariable
        public String contactIdsCsv;
    }

    public class ResultWrapper {
        @InvocableVariable public Integer insertedCount;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Insert Event Attendees'
        description='Creates EventAttendee__c records from eventId + Contact Ids (JSON or CSV).'
    )
    public static List<ResultWrapper> execute(List<InputWrapper> inputs) {

        System.debug('=== [EventAttendee_InsertFromIds] START ===');

        List<ResultWrapper> results = new List<ResultWrapper>();
        if (inputs == null) {
            System.debug('Inputs = null');
            System.debug('=== [EventAttendee_InsertFromIds] END ===');
            return results;
        }

        debugInputs(inputs);

        List<EventAttendee__c> allToInsert = new List<EventAttendee__c>();
        List<Integer> countsPerInput = new List<Integer>();

        for (InputWrapper input : inputs) {
            results.add(processInput(input, allToInsert, countsPerInput));
        }

        if (!allToInsert.isEmpty()) {
            insert allToInsert;
        }

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].errorMessage == null) {
                results[i].insertedCount = countsPerInput[i];
            }
        }

        System.debug('=== [EventAttendee_InsertFromIds] END ===');
        return results;
    }

    // ----------------------------
    // Per-input processing
    // ----------------------------
    private static ResultWrapper processInput(
        InputWrapper input,
        List<EventAttendee__c> allToInsert,
        List<Integer> countsPerInput
    ) {
        ResultWrapper res = new ResultWrapper();
        Integer localCount = 0;

        try {
            if (input == null || input.eventId == null) {
                res.insertedCount = 0;
                res.errorMessage = 'Missing eventId';
                countsPerInput.add(0);
                return res;
            }

            List<Id> contactIds = parseIds(input.contactIdsJson, input.contactIdsCsv);

            for (Id cid : contactIds) {
                allToInsert.add(new EventAttendee__c(
                    Event__c = input.eventId,
                    Contact__c = cid
                ));
                localCount++;
            }

            res.errorMessage = null;
            countsPerInput.add(localCount);
            // insertedCount will be set after the single DML

        } catch (Exception e) {
            res.insertedCount = 0;
            res.errorMessage = e.getMessage();
            countsPerInput.add(0);
        }

        return res;
    }

    // ----------------------------
    // Debug helpers
    // ----------------------------
    private static void debugInputs(List<InputWrapper> inputs) {
        System.debug('Inputs size = ' + String.valueOf(inputs.size()));
        for (Integer i = 0; i < inputs.size(); i++) {
            InputWrapper inw = inputs[i];
            System.debug('--- Input #' + i + ' ---');
            System.debug('eventId = ' + String.valueOf(inw == null ? null : inw.eventId));
            System.debug('contactIdsJson = ' + String.valueOf(inw == null ? null : inw.contactIdsJson));
            System.debug('contactIdsCsv = ' + String.valueOf(inw == null ? null : inw.contactIdsCsv));
        }
    }

    // ============================================================
    // Helper : parse JSON array or CSV into List<Id>
    // ============================================================
    private static List<Id> parseIds(String json, String csv) {

        List<Id> jsonIds = parseJsonIds(json);
        if (!jsonIds.isEmpty()) {
            return jsonIds;
        }

        return parseCsvIds(csv);
    }

    private static List<Id> parseJsonIds(String json) {
        if (String.isBlank(json)) {
            return new List<Id>();
        }

        Object parsed = System.JSON.deserializeUntyped(json);
        if (!(parsed instanceof List<Object>)) {
            return new List<Id>();
        }

        return toIdList((List<Object>) parsed);
    }

    private static List<Id> parseCsvIds(String csv) {
        if (String.isBlank(csv)) {
            return new List<Id>();
        }

        List<Id> out = new List<Id>();
        for (String part : csv.split(',')) {
            Id maybeId = toId(part);
            if (maybeId != null) {
                out.add(maybeId);
            }
        }
        return out;
    }

    private static List<Id> toIdList(List<Object> raw) {
        List<Id> out = new List<Id>();
        for (Object o : raw) {
            Id maybeId = toId(o);
            if (maybeId != null) {
                out.add(maybeId);
            }
        }
        return out;
    }

    private static Id toId(Object v) {
        if (v == null) return null;

        String s = String.valueOf(v).trim();
        if (String.isBlank(s)) return null;

        return (Id) s;
    }
}