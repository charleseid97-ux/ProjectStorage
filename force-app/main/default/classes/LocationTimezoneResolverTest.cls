@IsTest
private class LocationTimezoneResolverTest {

    // Test résolution par pays uniquement
    @IsTest
    static void testResolveByCountryOnly() {
        Test.startTest();
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve('France', null);
        Test.stopTest();

        System.assertEquals('Europe/Paris', result.timezoneId);
        System.assertEquals('country', result.matchedBy);
        System.assertNotEquals(null, result.gmtOffsetNow);
    }

    // Test résolution par ville uniquement
    @IsTest
    static void testResolveByCityOnly() {
        Test.startTest();
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve(null, 'London');
        Test.stopTest();

        System.assertEquals('Europe/London', result.timezoneId);
        System.assertEquals('city', result.matchedBy);
    }

    // Test résolution ville + pays
    @IsTest
    static void testResolveByCountryAndCity() {
        Test.startTest();
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve('Spain', 'Las Palmas');
        Test.stopTest();

        System.assertEquals('Atlantic/Canary', result.timezoneId);
        System.assertEquals('city', result.matchedBy);
    }

    // Test fallback pays si ville non matchée
    @IsTest
    static void testResolveFallbackToCountry() {
        Test.startTest();
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve('Germany', 'Unknown City');
        Test.stopTest();

        System.assertEquals('Europe/Berlin', result.timezoneId);
        System.assertEquals('country', result.matchedBy);
    }

    // Test pays/ville inconnus
    @IsTest
    static void testResolveUnknown() {
        Test.startTest();
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve('Unknown Country', 'Unknown City');
        Test.stopTest();

        System.assertEquals(null, result.timezoneId);
        System.assertEquals(null, result.matchedBy);
    }

    // Test normalisation accents
    @IsTest
    static void testResolveWithAccents() {
        Test.startTest();
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve('France', 'Val d’Isère');
        Test.stopTest();

        System.assertEquals('Europe/Paris', result.timezoneId);
        System.assertEquals('city', result.matchedBy);
    }

    // Test toString
    @IsTest
    static void testResultToString() {
        LocationTimezoneResolver.Result result =
            LocationTimezoneResolver.resolve('Italy', 'Rome');

        System.assert(result.toString().contains('Europe/Rome'));
    }
}