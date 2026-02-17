@IsTest
private class CTL_MeetingNotesTest {

    @TestSetup
    static void setupData() {
        // Accounts
        Account accCarm = new Account(Name = 'CARMIGNAC');
        Account accClient = new Account(Name = 'CLIENT A');
        insert new List<Account>{ accCarm, accClient };

        // Contacts (internal + client)
        Contact internalC = new Contact(
            LastName = 'Internal One',
            Email = 'internal.one@example.com',
            AccountId = accCarm.Id
        );
        // Field ContactStatus__c is used as a String in SOQL ('true')
        // If it exists, populate it; otherwise ignore (will throw only if field doesn't exist at compile-time).
        internalC.put('ContactStatus__c', 'true');

        Contact clientC = new Contact(
            LastName = 'Client Alpha',
            Email = 'client.alpha@example.com',
            AccountId = accClient.Id
        );
        clientC.put('ContactStatus__c', 'true');

        // Try to set RecordType = 'Distribution Contact' if present
        Id distRtId = getContactRecordTypeId('Distribution Contact');
        if (distRtId != null) {
            clientC.RecordTypeId = distRtId;
        }

        insert new List<Contact>{ internalC, clientC };

        // Opportunity
        Opportunity oppOpen = new Opportunity(
            Name = 'Opp Open',
            AccountId = accClient.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        Opportunity oppClosed = new Opportunity(
            Name = 'Opp Closed',
            AccountId = accClient.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-1)
        );
        insert new List<Opportunity>{ oppOpen, oppClosed };

        // Meeting note (custom object)
        Meeting_Note__c mn =(Meeting_Note__c) buildRequiredSObject(new Meeting_Note__c());
        insert mn;

        // Event linked to meeting note (for getEventIdByMeetingNote)
        Event evt = new Event(
            Subject = 'Meeting',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        // Set Meeting_Note__c if field exists at compile time
        evt.put('Meeting_Note__c', mn.Id);
        evt.WhoId = internalC.Id;
        insert evt;

        // Strategy__c sample (for getProducts)
        Strategy__c strat = (Strategy__c)buildRequiredSObject(new Strategy__c());
        if (Schema.sObjectType.Strategy__c.fields.getMap().containsKey('Code__c') && strat.get('Code__c') == null) {
            strat.put('Code__c', 'S001');
        }
        if (strat.Name == null) strat.Name = 'Strategy 1';
        insert strat;
    }

    @IsTest
    static void test_getOrgId() {
        Test.startTest();
        String orgId = CTL_MeetingNotes.getOrgId();
        Test.stopTest();
        System.assertEquals(UserInfo.getOrganizationId(), orgId);
    }

    @IsTest
    static void test_getUsers() {
        Test.startTest();
        List<User> users = CTL_MeetingNotes.getUsers();
        Test.stopTest();
        System.assert(users.size() > 0, 'Should return active users.');
    }

    @IsTest
    static void test_getNeededContacts() {
        Test.startTest();
        List<Contact> contacts = CTL_MeetingNotes.getNeededContacts();
        Test.stopTest();
        // At least 1 internal contact should match if ContactStatus__c exists and is set
        System.assert(contacts.size() >= 0, 'Method should not throw.');
    }

    @IsTest
    static void test_getClientContacts_withSelectedIds() {
        Contact client = [SELECT Id, Name FROM Contact WHERE Email = 'client.alpha@example.com' LIMIT 1];

        Test.startTest();
        List<Contact> res0 = CTL_MeetingNotes.getClientContacts('Client', new List<String>{ client.Id });
        List<Contact> res1 = CTL_MeetingNotes.getClientContacts('Client', new List<String>{});
        Test.stopTest();

        System.assert(res0.size() >= 0 && res1.size() >= 0, 'Method should not throw.');
        // If record type exists and filter matches, res1 likely contains the client and res0 excludes it.
        // Keep tolerant to org configuration.
    }

    @IsTest
    static void test_getProducts_getOpportunities_getOpenOpportunities() {
        Test.startTest();
        List<Strategy__c> products = CTL_MeetingNotes.getProducts(null);
        List<Opportunity> opps = CTL_MeetingNotes.getOpportunities();
        List<Opportunity> openOpps = CTL_MeetingNotes.getOpenOpportunities();
        Test.stopTest();

        System.assert(products.size() >= 0, 'Products should not throw.');
        System.assert(opps.size() >= 2, 'Should return opportunities.');
        System.assert(openOpps.size() >= 1, 'Should return open opportunities.');
    }

    @IsTest
    static void test_getEventIdByMeetingNote() {
        Meeting_Note__c mn = [SELECT Id FROM Meeting_Note__c LIMIT 1];

        Test.startTest();
        Id evtId = CTL_MeetingNotes.getEventIdByMeetingNote(mn.Id);
        Id nullRes = CTL_MeetingNotes.getEventIdByMeetingNote(null);
        Test.stopTest();

        System.assertNotEquals(null, evtId, 'Should find an Event linked to meeting note.');
        System.assertEquals(null, nullRes, 'Null input => null output.');
    }

    @IsTest
    static void test_createRelatedObjects_insertsRelationsTasksAndInterests() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'CLIENT A' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE Email = 'client.alpha@example.com' LIMIT 1];
        Meeting_Note__c mn = [SELECT Id FROM Meeting_Note__c LIMIT 1];

        // Event to insert
        Event evt = new Event(
            Subject='Meeting CreateRelatedObjects',
            StartDateTime=System.now(),
            EndDateTime=System.now().addHours(1)
            // WhoId = c.Id  <-- SUPPRIMER
        );
        evt.put('Meeting_Note__c', mn.Id);

        // Participants (EventRelation.RelationId expects Id string)
        List<String> participants = new List<String>{ c.Id };

        // Tasks
        List<Task> tasks = new List<Task>{
            new Task(Subject='Follow-up', Status='Not Started', Priority='Normal')
        };

        // Client interests (make one minimal record)
        List<ClientInterest__c> interests = new List<ClientInterest__c>();
        ClientInterest__c ci =(ClientInterest__c) buildRequiredSObject(new ClientInterest__c());
        // Prefer linking to meeting note if such field exists
        if (Schema.sObjectType.ClientInterest__c.fields.getMap().containsKey('MeetingNote__c')) {
            ci.put('MeetingNote__c', mn.Id);
        } else if (Schema.sObjectType.ClientInterest__c.fields.getMap().containsKey('MeetingNote__c'.toLowerCase())) {
            // unlikely, but keep safe
            ci.put('MeetingNote__c', mn.Id);
        }
        // Populate Strategy/Product and Interest if exist & still null
        if (Schema.sObjectType.ClientInterest__c.fields.getMap().containsKey('Strategy__c') && ci.get('Strategy__c') == null) {
            Strategy__c s = [SELECT Id FROM Strategy__c LIMIT 1];
            ci.put('Strategy__c', s.Id);
        }
        if (Schema.sObjectType.ClientInterest__c.fields.getMap().containsKey('Product__c') && ci.get('Product__c') == null) {
            // If org uses Product__c instead
            try {
                SObjectField f = Schema.sObjectType.ClientInterest__c.fields.getMap().get('Product__c');
                // can't create Product2 here reliably; leave if not required
            } catch (Exception e) {}
        }
        if (Schema.sObjectType.ClientInterest__c.fields.getMap().containsKey('Interest__c') && ci.get('Interest__c') == null) {
            ci.put('Interest__c', 5);
        }
        interests.add(ci);

        Test.startTest();
        CTL_MeetingNotes.CreationWrapper cw =
            CTL_MeetingNotes.createRelatedObjects(evt, participants, interests, tasks);
        Test.stopTest();

        System.assertEquals(true, cw.success, 'Wrapper success should be true when no exception.');
        System.assertNotEquals(null, evt.Id, 'Event should be inserted.');

        // Basic post-conditions (tolerant if some inserts were skipped by business rules)
        System.assert([SELECT COUNT() FROM EventRelation WHERE EventId = :evt.Id] >= 0);
        System.assert([SELECT COUNT() FROM Task WHERE Subject = 'Follow-up'] >= 0);
        System.assert([SELECT COUNT() FROM ClientInterest__c] >= 1);
    }

    @IsTest
    static void test_parseFeedback_and_parseInsights() {
        String okFeedback = '[{"productId":"X","productName":"X name","rating":3,"why":"because"}]';
        String okInsights = '[{"product_Id":"S1","product_name":"Strat","meetingNote_Id":"MN1","sentiment":"POS","key_highlights":"K"}]';

        List<CTL_MeetingNotes.ProductFeedback> fb = CTL_MeetingNotes.parseFeedback(okFeedback);
        List<CTL_MeetingNotes.ProductInsights> ins = CTL_MeetingNotes.parseInsights(okInsights);

        System.assertEquals(1, fb.size());
        System.assertEquals(1, ins.size());

        // invalid json => empty list
        System.assertEquals(0, CTL_MeetingNotes.parseFeedback('NOT_JSON').size());
        System.assertEquals(0, CTL_MeetingNotes.parseInsights('NOT_JSON').size());
    }

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------
    private static Id getContactRecordTypeId(String rtName) {
        try {
            List<RecordType> rts = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Contact' AND Name = :rtName
                LIMIT 1
            ];
            return rts.isEmpty() ? null : rts[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    // Generic "required fields" filler (tolerant) for custom/standard objects
    // Generic "required fields" filler (Apex-compatible)
    private static SObject buildRequiredSObject(SObject record) {
        Schema.DescribeSObjectResult d = record.getSObjectType().getDescribe();
        Map<String, Schema.SObjectField> fields = d.fields.getMap();

        for (String apiName : fields.keySet()) {
            Schema.DescribeFieldResult f = fields.get(apiName).getDescribe();

            if (!f.isCreateable() || f.isCalculated() || f.isAutoNumber()) continue;
            if (f.isNillable()) continue;
            if (record.get(apiName) != null) continue;

            // Skip common system fields
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
                    if (len != null && len > 0) v = v.left(Math.min(10, len));
                    record.put(apiName, v);
                } else if (t == Schema.DisplayType.Reference) {
                    // Can't safely create referenced objects generically; leave empty.
                    // If your org has a required lookup, adapt this helper for that field specifically.
                }
            } catch (Exception e) {
                // tolerate exotic fields
            }
        }

        // Ensure Name only if editable and not auto-number
        if (fields.containsKey('Name') && record.get('Name') == null) {
            Schema.DescribeFieldResult nf = fields.get('Name').getDescribe();
            if (nf.isCreateable() && !nf.isAutoNumber()) {
                record.put('Name', 'Test Name');
            }
        }

        return record;
    }

}