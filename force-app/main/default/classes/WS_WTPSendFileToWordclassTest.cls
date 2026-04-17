@IsTest
private class WS_WTPSendFileToWordclassTest {
    // ===== Mock des callouts Phrase (login, create project from template, upload jobs) =====
    private class PhraseHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            // Par défaut
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            if (endpoint != null && endpoint.contains('/web/api2/v3/auth/login')) {
                // --- LOGIN ---
                res.setStatusCode(200);
                res.setBody('{"token":"TOK_TEST","expires":"2025-12-31T00:00:00Z"}');
                return res;
            }

            if (endpoint != null && endpoint.contains('/web/api2/v2/projects/applyTemplate/')) {
                // --- CREATE PROJECT FROM TEMPLATE ---
                // Retourne un uid de projet
                res.setStatusCode(201);
                res.setBody('{"uid":"PROJ123"}');
                return res;
            }

            if (endpoint != null && endpoint.contains('/web/api2/v1/projects/') && endpoint.endsWith('/jobs')) {
                // --- UPLOAD JOBS ---
                // Simule 2 jobs pour la même langue "en" avec des niveaux 1 et 2
                res.setStatusCode(201);
                res.setBody('{"jobs":[' +
                    '{"uid":"JOB_LEVEL_1","status":"NEW","workflowLevel":1,"targetLang":"en"},' +
                    '{"uid":"JOB_LEVEL_2","status":"NEW","workflowLevel":2,"targetLang":"en"}' +
                ']}');
                return res;
            }

            // Par sécurité
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @IsTest
    static void test_sendForCases_createsProject_and_InsertsHighestLevelJob() {
        // ===== Préparation des Record Types =====
        Id rtTranslation;
        Id rtSubTranslation;

        Map<String, Schema.RecordTypeInfo> rtiByName = Schema.SObjectType.Case.getRecordTypeInfosByName();
        rtTranslation   = rtiByName.get('Translation Request').getRecordTypeId();
        rtSubTranslation = rtiByName.get('Sub Translation Request').getRecordTypeId();

        // ===== Données : Parent Case (FR) + Child Case (EN) =====
        Case parent = new Case(
            Subject                       = 'TEST Parent',
            Origin                        = 'Phone',
            Status                        = 'New',
            RecordTypeId                  = rtTranslation,
            Translation_Request_Type__c   = 'Translation Only',   
            Translation_mode__c           = 'Full humain',         
            Source_Language__c            = 'French',
            Document_Type__c              = 'Article (web / media)',
            target_languages__c        = 'English'
        );
        insert parent;

        Case child = [SELECT ID FROM Case WHERE parentId =:parent.Id LIMIT 1];
        
        system.debug(child.Id);

        // ===== Mock des callouts =====
        Test.setMock(HttpCalloutMock.class, new PhraseHttpMock());
        
        // ===== Fichier source (ContentVersion) lié au parent ; Titre requis "Source_*" =====
        ContentVersion cv = new ContentVersion();
        cv.Title                 = 'Source_test.docx';   // correspond au filtre LIKE 'Source_%'
        cv.PathOnClient          = '/Source_test.docx';
        cv.VersionData           = Blob.valueOf('dummy');
        cv.FirstPublishLocationId = parent.Id;          // lie automatiquement au Case parent
        Test.startTest();
        insert cv;
        Test.stopTest();

        // ===== Vérifications =====
        // 1) Le parent doit avoir reçu le Project UID
        parent = [
            SELECT Id, WorldclassProjectId__c
            FROM Case
            WHERE Id = :parent.Id
        ];
        System.assertEquals('PROJ123', parent.WorldclassProjectId__c,
            'Le Case parent doit être mis à jour avec le Project UID');

        // 2) Un seul WorldclassJob__c doit être créé (pour la langue EN), et ce doit être le job du plus haut workflowLevel
        List<WorldclassJob__c> jobs = [
            SELECT Id, WorkTogetherProcess__c, ProjectUid__c, JobUid__c, Status__c, SourceFileName__c, Name
            FROM WorldclassJob__c
            WHERE ProjectUid__c = 'PROJ123'
        ];
        System.assertEquals(1, jobs.size(),
            'Un seul job doit être inséré (celui correspondant à la dernière étape).');

        WorldclassJob__c job = jobs[0];
        System.assertEquals(child.Id, job.WorkTogetherProcess__c,
            'Le job doit être relié au Case enfant (langue EN).');
        System.assertEquals('PROJ123', job.ProjectUid__c,
            'Le job doit référencer le bon projet.');

        // Notre mock a renvoyé 2 jobs : workflowLevel 1 et 2. On doit avoir gardé le "2" (JOB_LEVEL_2).
        System.assertEquals('JOB_LEVEL_2', job.JobUid__c,
            'On doit conserver le job au workflowLevel le plus élevé.');

        // Vérifier que le nom source stocké correspond bien au Title sans double extension
        System.assertEquals('Source_test.docx', job.SourceFileName__c,
            'Le nom du fichier source doit être cohérent (pas de double extension).');
    }
}