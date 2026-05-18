@IsTest
private class EventColorServiceTest {

    // Test null et liste vide
    @IsTest
    static void testApplyColorsWithNullAndEmptyList() {
        Test.startTest();
        EventColorService.applyColorsInMemory(null);
        EventColorService.applyColorsInMemory(new List<Event__c>());
        Test.stopTest();

        System.assert(true);
    }

    // Test sans SalesTeam__c
    @IsTest
    static void testApplyColorsWithoutSalesTeam() {
        Event__c eventRecord = new Event__c(
            Name = 'Test Event Without Sales Team'
        );

        Test.startTest();
        EventColorService.applyColorsInMemory(new List<Event__c>{ eventRecord });
        Test.stopTest();

        System.assertEquals(null, eventRecord.Color__c);
    }

    // Test avec SalesTeam__c sans configuration couleur
    @IsTest
    static void testApplyColorsWithoutMatchingConfig() {
        Event__c eventRecord = new Event__c(
            Name = 'Test Event Without Config',
            SalesTeam__c = 'UNKNOWN'
        );

        Test.startTest();
        EventColorService.applyColorsInMemory(new List<Event__c>{ eventRecord });
        Test.stopTest();

        System.assertEquals(null, eventRecord.Color__c);
    }

    // Test avec configuration couleur
    @IsTest
    static void testApplyColorsWithConfig() {
        EventColors__c colorConfig = new EventColors__c(
            Name = 'Sales Team Test',
            SalesTeam__c = 'TEST',
            meetingDays__c = 'AAAAAA',
            oneToOne__c = 'BBBBBB',
            event__c = 'CCCCCC'
        );
        insert colorConfig;

        Event__c eventRecord = new Event__c(
            Name = 'Test Event With Config',
            SalesTeam__c = 'TEST'
        );

        Test.startTest();
        EventColorService.applyColorsInMemory(new List<Event__c>{ eventRecord });
        Test.stopTest();

        System.assertEquals(null, eventRecord.Color__c);
    }
}