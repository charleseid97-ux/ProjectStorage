@IsTest
private class CTL_MeetingNotes_UpdateFromRawTextTest {

    @TestSetup
    static void setupData() {
        Meeting_Note__c mn = buildRequiredSObject(new Meeting_Note__c());
        insert mn;
    }

    // ------------------------------------------------------------
    // INVOCABLE basic coverage: null/empty + records null/id null
    // ------------------------------------------------------------
    @IsTest
    static void test_invocable_guard_clauses() {
        Meeting_Note__c mn = [SELECT Id FROM Meeting_Note__c LIMIT 1];

        Test.startTest();
        CTL_MeetingNotes_UpdateFromRawText.updateMeetingNoteFromFlow(null);
        CTL_MeetingNotes_UpdateFromRawText.updateMeetingNoteFromFlow(new List<Meeting_Note__c>());
        CTL_MeetingNotes_UpdateFromRawText.updateMeetingNoteFromFlow(new List<Meeting_Note__c>{
            null,
            new Meeting_Note__c(),              // Id null -> continue
            new Meeting_Note__c(Id = mn.Id)     // Id OK -> tente flow (catch si besoin)
        });
        Test.stopTest();

        System.assert(true, 'Aucune exception ne doit remonter.');
    }

    // ------------------------------------------------------------
    // JSON PARSING coverage (via @TestVisible)
    // ------------------------------------------------------------
    @IsTest
    static void test_parse_blank_and_invalid() {
        Id mnId = [SELECT Id FROM Meeting_Note__c LIMIT 1].Id;

        // blank
        List<ClientInterest__c> rowsBlank =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON('', mnId);
        System.assertEquals(0, rowsBlank.size(), 'Blank JSON => 0 rows');

        // invalid JSON (doit catch et retourner 0)
        List<ClientInterest__c> rowsInvalid =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON('NOT_JSON', mnId);
        System.assertEquals(0, rowsInvalid.size(), 'Invalid JSON => 0 rows');
    }

    @IsTest
    static void test_parse_root_object_single_product() {
        Id mnId = [SELECT Id FROM Meeting_Note__c LIMIT 1].Id;

        String json = '{"productId":"STRAT_1","rating":5}';
        List<ClientInterest__c> rows =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(json, mnId);

        System.assertEquals(1, rows.size(), 'Root object => 1 row');
        System.assertEquals(mnId, rows[0].MeetingNote__c);
        System.assertEquals('STRAT_1', (String)rows[0].Strategy__c);
        System.assertEquals(5, (Integer)rows[0].Interest__c);
    }

    @IsTest
    static void test_parse_root_array() {
        Id mnId = [SELECT Id FROM Meeting_Note__c LIMIT 1].Id;

        String json = '[{"productId":"A","rating":1},{"ProductId":"B","Rating":"3"}]';
        List<ClientInterest__c> rows =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(json, mnId);

        System.assertEquals(2, rows.size(), 'Root array => 2 rows');
        System.assertEquals('A', (String)rows[0].Strategy__c);
        System.assertEquals(1, (Integer)rows[0].Interest__c);
        System.assertEquals('B', (String)rows[1].Strategy__c);
        System.assertEquals(3, (Integer)rows[1].Interest__c);
    }

    @IsTest
    static void test_parse_envelope_result_list() {
        Id mnId = [SELECT Id FROM Meeting_Note__c LIMIT 1].Id;

        String json = '{"Result":[{"productId":"X","rating":2},{"productId":"Y","rating":4}]}';
        List<ClientInterest__c> rows =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(json, mnId);

        System.assertEquals(2, rows.size(), 'Envelope Result list => 2 rows');
    }

    @IsTest
    static void test_parse_envelope_single_object() {
        Id mnId = [SELECT Id FROM Meeting_Note__c LIMIT 1].Id;

        String json = '{"products":{"ProductId":"ONE","Rating":5}}';
        List<ClientInterest__c> rows =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(json, mnId);

        System.assertEquals(1, rows.size(), 'Envelope single object => 1 row');
        System.assertEquals('ONE', (String)rows[0].Strategy__c);
        System.assertEquals(5, (Integer)rows[0].Interest__c);
    }

    @IsTest
    static void test_parse_error_envelope_and_missing_fields() {
        Id mnId = [SELECT Id FROM Meeting_Note__c LIMIT 1].Id;

        // error envelope => 0
        String errorJson = '{"error":"something bad happened"}';
        List<ClientInterest__c> rowsErr =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(errorJson, mnId);
        System.assertEquals(0, rowsErr.size(), 'Error envelope => 0 rows');

        // missing rating => skipped
        String missingRating = '[{"productId":"A"}]';
        List<ClientInterest__c> rowsMissingRating =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(missingRating, mnId);
        System.assertEquals(0, rowsMissingRating.size(), 'Missing rating => 0 rows');

        // rating non numérique => skipped (rating devient null)
        String badRating = '[{"productId":"A","rating":"notANumber"}]';
        List<ClientInterest__c> rowsBadRating =
            CTL_MeetingNotes_UpdateFromRawText.parseClientInterestsJSON(badRating, mnId);
        System.assertEquals(0, rowsBadRating.size(), 'Bad rating => 0 rows');
    }

    // ------------------------------------------------------------
    // Helper : remplit automatiquement les champs requis pour insert
    // (identique à ta version corrigée)
    // ------------------------------------------------------------
    private static Meeting_Note__c buildRequiredSObject(Meeting_Note__c record) {
        Schema.DescribeSObjectResult d = Meeting_Note__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fields = d.fields.getMap();

        for (String apiName : fields.keySet()) {
            Schema.DescribeFieldResult f = fields.get(apiName).getDescribe();

            if (!f.isCreateable() || f.isCalculated() || f.isAutoNumber()) continue;
            if (f.isNillable()) continue;
            if (record.get(apiName) != null) continue;

            if (apiName == 'OwnerId' || apiName == 'CreatedById' || apiName == 'LastModifiedById') continue;

            Schema.DisplayType t = f.getType();

            try {
                if (t == Schema.DisplayType.Boolean) {
                    record.put(apiName, true);
                } else if (t == Schema.DisplayType.Date) {
                    record.put(apiName, Date.today());
                } else if (t == Schema.DisplayType.DateTime) {
                    record.put(apiName, System.now());
                } else if (t == Schema.DisplayType.Double || t == Schema.DisplayType.Currency || t == Schema.DisplayType.Percent) {
                    record.put(apiName, 1.0);
                } else if (t == Schema.DisplayType.Integer) {
                    record.put(apiName, 1);
                } else if (t == Schema.DisplayType.Long) {
                    record.put(apiName, 1L);
                } else if (t == Schema.DisplayType.Email) {
                    record.put(apiName, 'test@example.com');
                } else if (t == Schema.DisplayType.Phone) {
                    record.put(apiName, '+33102030405');
                } else if (t == Schema.DisplayType.Url) {
                    record.put(apiName, 'https://example.com');
                } else if (t == Schema.DisplayType.Picklist) {
                    List<Schema.PicklistEntry> pe = f.getPicklistValues();
                    if (!pe.isEmpty()) record.put(apiName, pe[0].getValue());
                } else if (t == Schema.DisplayType.Multipicklist) {
                    List<Schema.PicklistEntry> pe = f.getPicklistValues();
                    if (!pe.isEmpty()) record.put(apiName, pe[0].getValue());
                } else if (t == Schema.DisplayType.TextArea) {
                    record.put(apiName, 'Test');
                } else if (t == Schema.DisplayType.String || t == Schema.DisplayType.Id) {
                    Integer len = f.getLength();
                    String v = 'Test';
                    if (len != null && len > 0) v = v.left(Math.min(4, len));
                    record.put(apiName, v);
                } else if (t == Schema.DisplayType.Reference) {
                    // Si lookup requis, à compléter selon ton modèle de données
                }
            } catch (Exception e) {
                // Tolérant
            }
        }

        if (fields.containsKey('Name') && record.get('Name') == null) {
            record.put('Name', 'Test Meeting Note');
        }

        return record;
    }
}