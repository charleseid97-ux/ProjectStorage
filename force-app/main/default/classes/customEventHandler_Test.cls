@IsTest(SeeAllData=false)
private class customEventHandler_Test {

    private static final String PREFIX = 'TST-EventName-';

    // --- FLS helpers (scanner-friendly) ---
    private static void assertCreateable(Schema.SObjectField f, String apiName) {
        System.assert(f.getDescribe().isCreateable(), 'Missing CREATE FLS on ' + apiName);
    }
    private static void assertUpdateable(Schema.SObjectField f, String apiName) {
        System.assert(f.getDescribe().isUpdateable(), 'Missing UPDATE FLS on ' + apiName);
    }
    private static void assertReadable(Schema.SObjectField f, String apiName) {
        System.assert(f.getDescribe().isAccessible(), 'Missing READ FLS on ' + apiName);
    }

    private static void assertEventCreateFls() {
        assertCreateable(Event__c.Title__c,     'Event__c.Title__c');
        assertCreateable(Event__c.SalesTeam__c, 'Event__c.SalesTeam__c');
        assertCreateable(Event__c.startTime__c, 'Event__c.startTime__c');
        assertCreateable(Event__c.Format__c,    'Event__c.Format__c');
    }

    private static void assertEventUpdateFls() {
        assertUpdateable(Event__c.Title__c,     'Event__c.Title__c');
        // Add others if you update them in tests later
    }

    private static void assertEventReadFls() {
        assertReadable(Event__c.Name,          'Event__c.Name');
        assertReadable(Event__c.Title__c,      'Event__c.Title__c');
        assertReadable(Event__c.SalesTeam__c,  'Event__c.SalesTeam__c');
        assertReadable(Event__c.startTime__c,  'Event__c.startTime__c');
        assertReadable(Event__c.Format__c,     'Event__c.Format__c');
    }

    @testSetup
    static void setupData() {
        assertEventCreateFls();

        Event__c e = new Event__c(
            Title__c = PREFIX + 'Initial',
            SalesTeam__c = 'France',
            startTime__c = '13:05',
            Format__c = 'Digital'
        );
        insert e;
    }

    @IsTest
    static void testBeforeInsert_BuildsName_FromTimeCountryTitleFormat() {
        assertEventCreateFls();
        assertEventReadFls();

        Event__c e = new Event__c(
            Title__c = PREFIX + 'Insert',
            SalesTeam__c = 'France',
            startTime__c = '13:05',
            Format__c = 'Digital'
        );

        insert e;

        // Use WITH SECURITY_ENFORCED to satisfy the scanner for READ access.
        e = [
            SELECT Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        String expected = '1:05 PM – FR – ' + (PREFIX + 'Insert') + ' – D';
        System.assertEquals(expected, e.Name);
    }

    @IsTest
    static void testBeforeUpdate_RebuildsName_WhenRelevantFieldChanges() {
        assertEventReadFls();
        assertEventUpdateFls();

        Event__c e = [
            SELECT Id, Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Title__c = :(PREFIX + 'Initial')
            LIMIT 1
            WITH SECURITY_ENFORCED
        ];

        e.Title__c = PREFIX + 'Updated';
        update e;

        e = [
            SELECT Name
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        String expected = '1:05 PM – FR – ' + (PREFIX + 'Updated') + ' – D';
        System.assertEquals(expected, e.Name);
    }

    @IsTest
    static void testBeforeUpdate_DoesNotChangeName_WhenNothingRelevantChanged() {
        assertEventReadFls();
        assertEventUpdateFls();

        Event__c e = [
            SELECT Id, Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Title__c = :(PREFIX + 'Initial')
            LIMIT 1
            WITH SECURITY_ENFORCED
        ];
        String nameBefore = e.Name;

        // No-op update (still requires UPDATE FLS checks to satisfy scanner)
        e.Title__c = e.Title__c;
        update e;

        e = [
            SELECT Name
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];
        System.assertEquals(nameBefore, e.Name);
    }

    @IsTest
    static void testInsert_HandlesInvalidTime_Gracefully() {
        assertEventCreateFls();
        assertEventReadFls();

        Event__c e = new Event__c(
            Title__c = PREFIX + 'BadTime',
            SalesTeam__c = 'France',
            startTime__c = '99:99',
            Format__c = 'Physical'
        );

        insert e;

        e = [
            SELECT Name
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        String expected = 'FR – ' + (PREFIX + 'BadTime') + ' – P';
        System.assertEquals(expected, e.Name);
    }
}