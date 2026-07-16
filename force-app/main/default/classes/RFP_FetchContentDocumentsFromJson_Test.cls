@IsTest
private class RFP_FetchContentDocumentsFromJson_Test {

    @IsTest
    static void testFetch_NullRequests() {
        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(null);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_EmptyRequests() {
        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>()
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_BlankJson() {
        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json = '';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_InvalidJson() {
        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json = '{"documents":[';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_NoDocumentsNode() {
        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json = '{"foo":"bar"}';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_EmptyDocumentsArray() {
        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json = '{"documents":[]}';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_InvalidIdsOnly() {
        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json = '{"documents":[{"id":"abc"},{"id":"12345"},{"id":""}]}';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(0, results[0].documents.size());
    }

    @IsTest
    static void testFetch_ReturnsContentDocuments() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Dummy file content'),
            FirstPublishLocationId = acc.Id
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json =
            '{"documents":[{"id":"' + String.valueOf(acc.Id) + '","title":"Account 1","rank":1}]}';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(1, results[0].documents.size());

        ContentDocument doc = results[0].documents[0];
        System.assertEquals(cv.ContentDocumentId, doc.Id);
        System.assertEquals('Test File', doc.Title);
    }

    @IsTest
    static void testFetch_MultipleIds_OnlyLinkedDocumentsReturned() {
        Account acc1 = new Account(Name = 'Account 1');
        Account acc2 = new Account(Name = 'Account 2');
        insert new List<Account>{ acc1, acc2 };

        ContentVersion cv1 = new ContentVersion(
            Title = 'File 1',
            PathOnClient = 'File1.pdf',
            VersionData = Blob.valueOf('File content 1'),
            FirstPublishLocationId = acc1.Id
        );
        insert cv1;

        cv1 = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv1.Id
            LIMIT 1
        ];

        RFP_FetchContentDocumentsFromJson.Request req =
            new RFP_FetchContentDocumentsFromJson.Request();
        req.json =
            '{"documents":[' +
                '{"id":"' + String.valueOf(acc1.Id) + '","title":"A1","rank":1},' +
                '{"id":"' + String.valueOf(acc2.Id) + '","title":"A2","rank":2}' +
            ']}';

        Test.startTest();
        List<RFP_FetchContentDocumentsFromJson.Response> results =
            RFP_FetchContentDocumentsFromJson.fetch(
                new List<RFP_FetchContentDocumentsFromJson.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].documents);
        System.assertEquals(1, results[0].documents.size());
        System.assertEquals(cv1.ContentDocumentId, results[0].documents[0].Id);
        System.assertEquals('File 1', results[0].documents[0].Title);
    }
}