@IsTest(SeeAllData=false)
private class customEventHandler_Test {

    private static final String PREFIX = 'TST-EventName-';

    // ---- Centralized FLS error messages (fix duplication smell) ----
    private static final String ERR_UPDATE_TITLE =
        'Missing UPDATE FLS on Event__c.Title__c';
    private static final String ERR_READ_NAME =
        'Missing READ FLS on Event__c.Name';

    // ---- CREATE FLS ----
    private static void assertCreateFls() {
        System.assert(
            Schema.sObjectType.Event__c.fields.Title__c.isCreateable(),
            'Missing CREATE FLS on Event__c.Title__c'
        );
        System.assert(
            Schema.sObjectType.Event__c.fields.SalesTeam__c.isCreateable(),
            'Missing CREATE FLS on Event__c.SalesTeam__c'
        );
        System.assert(
            Schema.sObjectType.Event__c.fields.startTime__c.isCreateable(),
            'Missing CREATE FLS on Event__c.startTime__c'
        );
        System.assert(
            Schema.sObjectType.Event__c.fields.Format__c.isCreateable(),
            'Missing CREATE FLS on Event__c.Format__c'
        );
    }

    // ---- UPDATE FLS ----
    private static void assertUpdateTitleFls() {
        System.assert(
            Schema.sObjectType.Event__c.fields.Title__c.isUpdateable(),
            ERR_UPDATE_TITLE
        );
    }

    // ---- READ FLS ----
    private static void assertReadNameFls() {
        System.assert(
            Schema.sObjectType.Event__c.fields.Name.isAccessible(),
            ERR_READ_NAME
        );
    }

    private static void assertReadAllFls() {
        assertReadNameFls();

        System.assert(
            Schema.sObjectType.Event__c.fields.Title__c.isAccessible(),
            'Missing READ FLS on Event__c.Title__c'
        );
        System.assert(
            Schema.sObjectType.Event__c.fields.SalesTeam__c.isAccessible(),
            'Missing READ FLS on Event__c.SalesTeam__c'
        );
        System.assert(
            Schema.sObjectType.Event__c.fields.startTime__c.isAccessible(),
            'Missing READ FLS on Event__c.startTime__c'
        );
        System.assert(
            Schema.sObjectType.Event__c.fields.Format__c.isAccessible(),
            'Missing READ FLS on Event__c.Format__c'
        );
    }

    @testSetup
    static void setupData() {

        assertCreateFls();

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

        assertCreateFls();

        Event__c e = new Event__c(
            Title__c = PREFIX + 'Insert',
            SalesTeam__c = 'France',
            startTime__c = '13:05',
            Format__c = 'Digital'
        );

        insert e;

        assertReadAllFls();

        e = [
            SELECT Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        // ---- FLS check immediately before field access (fix blocker line 44) ----
        assertReadNameFls();

        String expected = '1:05 PM – FR – ' + (PREFIX + 'Insert') + ' – D';
        System.assertEquals(expected, e.Name);
    }

    @IsTest
    static void testBeforeUpdate_RebuildsName_WhenRelevantFieldChanges() {

        assertReadAllFls();

        Event__c e = [
            SELECT Id, Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Title__c = :(PREFIX + 'Initial')
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        assertUpdateTitleFls();
        e.Title__c = PREFIX + 'Updated';
        update e;

        assertReadNameFls();

        e = [
            SELECT Name
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        assertReadNameFls();

        String expected = '1:05 PM – FR – ' + (PREFIX + 'Updated') + ' – D';
        System.assertEquals(expected, e.Name);
    }

    @IsTest
    static void testBeforeUpdate_DoesNotChangeName_WhenNothingRelevantChanged() {

        assertReadAllFls();

        Event__c e = [
            SELECT Id, Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Title__c = :(PREFIX + 'Initial')
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        assertReadNameFls();
        String nameBefore = e.Name;

        assertUpdateTitleFls();
        e.Title__c = e.Title__c;
        update e;

        assertReadNameFls();

        e = [
            SELECT Name
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        assertReadNameFls();
        System.assertEquals(nameBefore, e.Name);
    }

    @IsTest
    static void testInsert_HandlesInvalidTime_Gracefully() {

        assertCreateFls();

        Event__c e = new Event__c(
            Title__c = PREFIX + 'BadTime',
            SalesTeam__c = 'France',
            startTime__c = '99:99',
            Format__c = 'Physical'
        );

        insert e;

        assertReadNameFls();

        e = [
            SELECT Name
            FROM Event__c
            WHERE Id = :e.Id
            WITH SECURITY_ENFORCED
        ];

        assertReadNameFls();

        String expected = 'FR – ' + (PREFIX + 'BadTime') + ' – P';
        System.assertEquals(expected, e.Name);
    }
}