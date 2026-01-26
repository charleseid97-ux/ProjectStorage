public with sharing class EventAttendee_InsertFromIds {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id eventId;            // Event__c Id

        @InvocableVariable
        public String contactIdsJson; // e.g. ["003..","003.."]

        @InvocableVariable
        public String contactIdsCsv;  // e.g. 003..,003..
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

        List<ResultWrapper> results = new List<ResultWrapper>();

        // ===== DEBUG INPUTS =====
        System.debug('=== [EventAttendee_InsertFromIds] START ===');

        if (inputs == null) {
            System.debug('Inputs = null');
            return results;
        }

        System.debug('Inputs size = ' + String.valueOf(inputs.size()));

        for (Integer i = 0; i < inputs.size(); i++) {
            InputWrapper inw = inputs[i];
            System.debug('--- Input #' + i + ' ---');
            System.debug('eventId = ' + String.valueOf(inw == null ? null : inw.eventId));
            System.debug('contactIdsJson = ' + String.valueOf(inw == null ? null : inw.contactIdsJson));
            System.debug('contactIdsCsv = ' + String.valueOf(inw == null ? null : inw.contactIdsCsv));
        }

        // ===== MAIN LOGIC =====
        for (InputWrapper input : inputs) {

            ResultWrapper res = new ResultWrapper();
            List<EventAttendee__c> toInsert = new List<EventAttendee__c>();

            try {
                if (input == null || input.eventId == null) {
                    res.insertedCount = 0;
                    res.errorMessage = 'Missing eventId';
                    results.add(res);
                    continue;
                }

                // Parse Contact Ids
                List<Id> contactIds = parseIds(input.contactIdsJson, input.contactIdsCsv);

                System.debug('Parsed contactIds = ' + contactIds);

                for (Id cid : contactIds) {
                    EventAttendee__c ea = new EventAttendee__c();
                    ea.Event__c = input.eventId;
                    ea.Contact__c = cid;
                    toInsert.add(ea);
                }

                System.debug('Records to insert = ' + toInsert.size());

                if (!toInsert.isEmpty()) {
                    insert toInsert;
                }

                res.insertedCount = toInsert.size();
                res.errorMessage = null;

            } catch (Exception e) {
                System.debug('ERROR: ' + e.getMessage());
                res.insertedCount = 0;
                res.errorMessage = e.getMessage();
            }

            results.add(res);
        }

        System.debug('=== [EventAttendee_InsertFromIds] END ===');
        return results;
    }

    // ============================================================
    // Helper : parse JSON array or CSV into List<Id>
    // ============================================================
    private static List<Id> parseIds(String json, String csv) {

        List<Id> out = new List<Id>();

        // Prefer JSON
        if (!String.isBlank(json)) {
            Object parsed = System.JSON.deserializeUntyped(json);
            if (parsed instanceof List<Object>) {
                for (Object o : (List<Object>)parsed) {
                    if (o == null) continue;
                    String s = String.valueOf(o).trim();
                    if (String.isBlank(s)) continue;
                    out.add((Id)s);
                }
                return out;
            }
        }

        // Fallback CSV
        if (!String.isBlank(csv)) {
            for (String part : csv.split(',')) {
                if (String.isBlank(part)) continue;
                out.add((Id)part.trim());
            }
        }

        return out;
    }
}