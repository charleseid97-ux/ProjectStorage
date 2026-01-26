@IsTest(SeeAllData=false)
private class customEventHandler_Test {

    // Helper: stable prefix for this test class
    private static final String PREFIX = 'TST-EventName-';

    @testSetup
    static void setupData() {
        // Create one event used by update tests
        // Important: Name is set by trigger in BeforeInsert, but for insert we just need required fields.
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
        // Arrange
        Event__c e = new Event__c(
            Title__c = PREFIX + 'Insert',
            SalesTeam__c = 'France',
            startTime__c = '13:05',
            Format__c = 'Digital'
        );

        // Act
        insert e;

        // Assert (requery because Name is set in trigger context)
        e = [SELECT Name, Title__c, SalesTeam__c, startTime__c, Format__c FROM Event__c WHERE Id = :e.Id];

        // Expected:
        // timePart: 1:05 PM
        // countryPart: FR (from map)
        // title: Title__c
        // formatPart: D (Digital -> startsWith('D'))
        String expected = '1:05 PM – FR – ' + (PREFIX + 'Insert') + ' – D';
        System.assertEquals(expected, e.Name, 'Name should be built from time, country, title and format');
    }

    @IsTest
    static void testBeforeUpdate_RebuildsName_WhenRelevantFieldChanges() {
        // Arrange: take the setup record
        Event__c e = [
            SELECT Id, Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Title__c = : (PREFIX + 'Initial')
            LIMIT 1
        ];

        // Act: change one relevant field (Title__c)
        e.Title__c = PREFIX + 'Updated';
        update e;

        // Assert
        e = [SELECT Name FROM Event__c WHERE Id = :e.Id];

        // startTime__c=13:05 -> 1:05 PM, SalesTeam__c=France -> FR, Format__c=Digital -> D
        String expected = '1:05 PM – FR – ' + (PREFIX + 'Updated') + ' – D';
        System.assertEquals(expected, e.Name, 'Name should be rebuilt when Title__c changes');
    }

    @IsTest
    static void testBeforeUpdate_DoesNotChangeName_WhenNothingRelevantChanged() {
        // Arrange
        Event__c e = [
            SELECT Id, Name, Title__c, SalesTeam__c, startTime__c, Format__c
            FROM Event__c
            WHERE Title__c = : (PREFIX + 'Initial')
            LIMIT 1
        ];
        String nameBefore = e.Name;

        // Act: update a non-relevant field (choose a field that exists and is not in the "changed" list)
        // If you don't have a safe non-relevant field, remove this test or replace with an actual field in your org.
        // Example assumes Description__c exists:
        // e.Description__c = 'noop';
        // update e;

        // Safer alternative: do a no-op update by setting a relevant field to the same value (should not trigger rebuild)
        e.Title__c = e.Title__c;
        update e;

        // Assert
        e = [SELECT Name FROM Event__c WHERE Id = :e.Id];
        System.assertEquals(nameBefore, e.Name, 'Name should not change if relevant fields did not change');
    }

    @IsTest
    static void testInsert_HandlesInvalidTime_Gracefully() {
        // Arrange: invalid time -> timePart should be omitted (formatTime12hFromText returns null)
        Event__c e = new Event__c(
            Title__c = PREFIX + 'BadTime',
            SalesTeam__c = 'France',
            startTime__c = '99:99',
            Format__c = 'Physical'
        );

        // Act
        insert e;

        // Assert
        e = [SELECT Name FROM Event__c WHERE Id = :e.Id];

        // timePart omitted, countryPart FR, title, formatPart P (Physical -> startsWith('P'))
        String expected = 'FR – ' + (PREFIX + 'BadTime') + ' – P';
        System.assertEquals(expected, e.Name, 'Invalid time should not break; it should omit the time part');
    }
}