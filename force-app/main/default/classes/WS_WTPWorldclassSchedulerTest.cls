@IsTest
private class WS_WTPWorldclassSchedulerTest {

    // -----------------------------
    // Flexible HTTP mock for Phrase
    // Covers:
    // - /web/api2/v3/auth/login
    // - /web/api2/v1/projects/{p}/jobs/{j}          (status)
    // - /web/api2/v1/projects/{p}/jobs/{j}/targetFile (download)
    // -----------------------------
    private class PhraseFlexibleMock implements HttpCalloutMock {
        Boolean loginOk          = true;        // 200 vs 401
        Boolean statusEndpointOk = true;        // 200 vs 500
        String  jobStatus        = 'COMPLETED'; // COMPLETED / DELIVERED / IN_PROGRESS / etc.
        Boolean downloadOk       = true;        // 200 vs 400

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint();

            // defaults
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            // LOGIN
            if (ep.contains('/web/api2/v3/auth/login')) {
                if (loginOk) {
                    res.setStatusCode(200);
                    res.setBody('{"token":"TOK_TEST","expires":"2099-12-31T00:00:00Z"}');
                } else {
                    res.setStatusCode(401);
                    res.setBody('{"error":"Unauthorized"}');
                }
                return res;
            }

            // JOB STATUS (exclude /targetFile)
            if (ep.contains('/web/api2/v1/projects/') && ep.contains('/jobs/') && !ep.endsWith('/targetFile')) {
                if (statusEndpointOk) {
                    res.setStatusCode(200);
                    res.setBody('{"uid":"JOBUID","status":"' + jobStatus + '"}');
                } else {
                    res.setStatusCode(500);
                    res.setBody('{"error":"ServerError"}');
                }
                return res;
            }

            // DOWNLOAD
            if (ep.endsWith('/targetFile')) {
                if (downloadOk) {
                    res.setStatusCode(200);
                    res.setHeader('Content-Type','application/octet-stream');
                    res.setHeader('Content-Disposition','attachment; filename="Target_doc.docx"');
                    res.setBodyAsBlob(Blob.valueOf('translated-bytes'));
                } else {
                    res.setStatusCode(400);
                    res.setBody('{"error":"Bad Request"}');
                }
                return res;
            }

            // fallback
            res.setBody('{}');
            return res;
        }
    }

    // -----------------------------
    // Test data helpers
    // -----------------------------
    private static Case mkCase() {
        Case c = new Case(Subject='WTP Child', Origin='Phone', Status='New');
        insert c;
        return c;
    }

    private static WorldclassJob__c mkJob(Id caseId, String status) {
        WorldclassJob__c j = new WorldclassJob__c(
            Name='Job',
            WorkTogetherProcess__c = caseId,
            ProjectUid__c          = 'PROJ1',
            JobUid__c              = 'JOB1',
            Status__c              = status,
            SourceFileName__c      = 'Source_doc.docx'
        );
        insert j;
        return j;
    }

    // -----------------------------
    // 1) Happy path: Scheduler → Batch
    //    status COMPLETED → download + attach CV + update job
    // -----------------------------
    @IsTest
    static void test_scheduler_runs_batch_happy_path() {
        // Data
        Case c = mkCase();
        WorldclassJob__c job = mkJob(c.Id, 'NEW');

        // Mock
        PhraseFlexibleMock mock = new PhraseFlexibleMock();
        mock.jobStatus  = 'COMPLETED';
        mock.downloadOk = true;
        Test.setMock(HttpCalloutMock.class, mock);

        // Schedule the scheduler (runs at Test.stopTest)
        Test.startTest();
        new WS_WTPWorldclassScheduler().execute(null);
        Test.stopTest();

        // Assert — job updated
        WorldclassJob__c j2 = [SELECT Status__c FROM WorldclassJob__c WHERE Id = :job.Id];
        System.assertEquals('COMPLETED', j2.Status__c, 'Job should be marked COMPLETED');

        // Assert — file attached
        Integer cvCount = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :c.Id];
        System.assertEquals(1, cvCount, 'One translated file should be attached to the Case');
    }

    // -----------------------------
    // 2) No jobs in scope (not NEW) → batch should run without doing anything
    // -----------------------------
    @IsTest
    static void test_scheduler_with_no_new_jobs() {
        // Data: insert a job not in NEW
        Case c = mkCase();
        mkJob(c.Id, 'COMPLETED');

        // Mock (still needed for login call, even if no job processed)
        Test.setMock(HttpCalloutMock.class, new PhraseFlexibleMock());

        Test.startTest();
        new WS_WTPWorldclassScheduler().execute(null);
        Test.stopTest();

        // No CV inserted
        Integer cvCount = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :c.Id];
        System.assertEquals(0, cvCount, 'No files should be attached');

        // Nothing else to assert — just verify no exceptions
        System.assert(true, 'Scheduler executed without errors');
    }

    // -----------------------------
    // 3) Login failure → batch exits early, no changes
    // -----------------------------
    @IsTest
    static void test_scheduler_login_failure() {
        // Data: one NEW job so batch would try to run
        Case c = mkCase();
        WorldclassJob__c job = mkJob(c.Id, 'NEW');

        // Mock: force login 401
        PhraseFlexibleMock mock = new PhraseFlexibleMock();
        mock.loginOk = false;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new WS_WTPWorldclassScheduler().execute(null);
        Test.stopTest();

        // Job remains NEW
        WorldclassJob__c j2 = [SELECT Status__c FROM WorldclassJob__c WHERE Id = :job.Id];
        System.assertEquals('NEW', j2.Status__c, 'Job must remain NEW if login fails');

        // No CV inserted
        Integer cvCount = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :c.Id];
        System.assertEquals(0, cvCount, 'No file should be attached on login failure');
    }

    // -----------------------------
    // 4) Status endpoint 500 (unreadable) → no CV, no update
    // -----------------------------
    @IsTest
    static void test_scheduler_status_unreadable() {
        Case c = mkCase();
        WorldclassJob__c job = mkJob(c.Id, 'NEW');

        PhraseFlexibleMock mock = new PhraseFlexibleMock();
        mock.statusEndpointOk = false; // 500 on status endpoint
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new WS_WTPWorldclassScheduler().execute(null);
        Test.stopTest();

        WorldclassJob__c j2 = [SELECT Status__c FROM WorldclassJob__c WHERE Id = :job.Id];
        System.assertEquals('NEW', j2.Status__c, 'Job remains NEW if status unreadable');
        Integer cvCount = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :c.Id];
        System.assertEquals(0, cvCount);
    }

    // -----------------------------
    // 5) Completed but download 400 → no CV, job must NOT be set COMPLETED
    // -----------------------------
    @IsTest
    static void test_scheduler_download_ko() {
        Case c = mkCase();
        WorldclassJob__c job = mkJob(c.Id, 'NEW');

        PhraseFlexibleMock mock = new PhraseFlexibleMock();
        mock.jobStatus  = 'COMPLETED';
        mock.downloadOk = false; // download fails
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new WS_WTPWorldclassScheduler().execute(null);
        Test.stopTest();

        WorldclassJob__c j2 = [SELECT Status__c FROM WorldclassJob__c WHERE Id = :job.Id];
        System.assertEquals('NEW', j2.Status__c, 'Job should not be COMPLETED if file insert didn’t happen');
        Integer cvCount = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :c.Id];
        System.assertEquals(0, cvCount);
    }
}