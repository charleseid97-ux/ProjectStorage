@isTest
private class CityWireCalloutServiceTest {

    private class CityWireMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        Boolean throwCalloutException = false;

        CityWireMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        CityWireMock throwing() {
            this.throwCalloutException = true;
            return this;
        }

        public HttpResponse respond(HttpRequest request) {
            if (throwCalloutException) {
                throw new CalloutException('Read timed out');
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @isTest
    static void testSuccessSingleManager() {
        String body = '{"ISIN":"FR0000000001","SummaryDisclaimer":"disclaimer","RatingDate":"2026-03-01","PublishDate":"2026-02-15","Managers":[' +
            '{"ID":12345,"FirstName":"John","LastName":"Doe",' +
            '"Rating":{"RatingValue":3,"Description":"desc","ImageSrc":"https://citywire.com/john.png","Disclaimer":"disc"}}' +
        ']}';
        Test.setMock(HttpCalloutMock.class, new CityWireMock(200, body));

        Test.startTest();
        CityWireCalloutService.CityWireFundResponseWrapper result = CityWireCalloutService.getFund('FR0000000001');
        Test.stopTest();

        System.assertEquals('2026-03-01', result.RatingDate, 'RatingDate is at the fund level, not per-manager');
        System.assertEquals(1, result.Managers.size());
        System.assertEquals(12345, result.Managers[0].ID);
        System.assertEquals(3, result.Managers[0].Rating.RatingValue);
        System.assertEquals('https://citywire.com/john.png', result.Managers[0].Rating.ImageSrc, 'ImageSrc is nested under Rating, not on the manager directly');
    }

    @isTest
    static void testSuccessMultipleManagers() {
        String body = '{"ISIN":"FR0000000002","SummaryDisclaimer":"disclaimer","RatingDate":"2026-01-01","PublishDate":"2026-01-01","Managers":[' +
            '{"ID":111,"FirstName":"A","LastName":"B","Rating":{"RatingValue":1,"ImageSrc":"https://citywire.com/a.png"}},' +
            '{"ID":222,"FirstName":"C","LastName":"D","Rating":{"RatingValue":2,"ImageSrc":"https://citywire.com/c.png"}}' +
        ']}';
        Test.setMock(HttpCalloutMock.class, new CityWireMock(200, body));

        Test.startTest();
        CityWireCalloutService.CityWireFundResponseWrapper result = CityWireCalloutService.getFund('FR0000000002');
        Test.stopTest();

        System.assertEquals(2, result.Managers.size());
    }

    @isTest
    static void testEmptyManagersArray() {
        String body = '{"SummaryDisclaimer":"disclaimer","Managers":[]}';
        Test.setMock(HttpCalloutMock.class, new CityWireMock(200, body));

        Test.startTest();
        CityWireCalloutService.CityWireFundResponseWrapper result = CityWireCalloutService.getFund('FR0000000003');
        Test.stopTest();

        System.assertEquals(0, result.Managers.size());
    }

    @isTest
    static void testNon200Status() {
        Test.setMock(HttpCalloutMock.class, new CityWireMock(404, '{"error":"not found"}'));

        Test.startTest();
        Boolean threw = false;
        try {
            CityWireCalloutService.getFund('FR0000000004');
        } catch (CityWireCalloutService.CityWireCalloutException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A non-200 response should throw a CityWireCalloutException');
    }

    @isTest
    static void testTimeout() {
        Test.setMock(HttpCalloutMock.class, new CityWireMock(200, '').throwing());

        Test.startTest();
        Boolean threw = false;
        try {
            CityWireCalloutService.getFund('FR0000000005');
        } catch (CityWireCalloutService.CityWireCalloutException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A callout exception (timeout) should be wrapped in a CityWireCalloutException');
    }

    @isTest
    static void testMalformedJson() {
        Test.setMock(HttpCalloutMock.class, new CityWireMock(200, 'not json'));

        Test.startTest();
        Boolean threw = false;
        try {
            CityWireCalloutService.getFund('FR0000000006');
        } catch (CityWireCalloutService.CityWireCalloutException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Malformed JSON should throw a CityWireCalloutException');
    }
}
