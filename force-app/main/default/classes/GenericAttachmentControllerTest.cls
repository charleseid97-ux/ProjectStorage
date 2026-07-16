@isTest
private class GenericAttachmentControllerTest {

    // Helper pour créer un Case de test
    private static Case createTestCase() {
        Case c = new Case(
            Subject = 'Test Case for Attachments',
            Origin = 'Phone'
        );
        insert c;
        return c;
    }

    // Helper : crée un ContentVersion et le publie sur la record (FirstPublishLocationId)
    // retourne le ContentDocumentId créé
    private static Id createContentDocumentOnRecord(Id parentId, String title) {
        // Contenu minimal pour ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = title + '.txt';
        cv.VersionData = Blob.valueOf('Test content ' + title);
        cv.FirstPublishLocationId = parentId; // create link to the parent record
        insert cv;

        // Récupérer le ContentDocumentId
        ContentVersion inserted = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        return inserted.ContentDocumentId;
    }

    // Helper : crée un ContentVersion sans lien direct (pour tester deleteFile indépendamment)
    private static Id createStandaloneContentDocument(String title) {
        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = title + '.txt';
        cv.VersionData = Blob.valueOf('Standalone content ' + title);
        insert cv;

        ContentVersion inserted = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        return inserted.ContentDocumentId;
    }

    @isTest static void testGetAttachments_and_emptyParent() {
        // Arrange
        Case testCase = createTestCase();

        // create a content document and attach to case (via FirstPublishLocationId)
        String fileTitle = 'test-file-getAttachments';
        Id contentDocId = createContentDocumentOnRecord(testCase.Id, fileTitle);

        Test.startTest();
            // Act: call getAttachments for the case
            List<GenericAttachmentController.FileWrapper> wrappers = GenericAttachmentController.getAttachments(testCase.Id,'test');
        Test.stopTest();

        // Assert: we should have at least one wrapper and matching title/contentDocumentId
        System.assertNotEquals(null, wrappers, 'Wrappers should not be null');
        System.assert(wrappers.size() > 0, 'Should return at least one file wrapper');
        Boolean found = false;
        for (GenericAttachmentController.FileWrapper fw : wrappers) {
            if (fw.contentDocumentId == String.valueOf(contentDocId) && fw.title == fileTitle) {
                found = true;
                break;
            }
        }
        System.assert(found, 'The wrapper for the created ContentDocument must be present');       
    }

    @isTest static void testDeleteFile() {
        Case testCase = createTestCase();

        // Arrange : create a standalone ContentDocument (not necessarily linked to a record)
        String fileTitle = 'test-file-delete';
		Id contentDocId = createContentDocumentOnRecord(testCase.Id, fileTitle);
        // Verify it exists before delete
        Integer beforeCount = [SELECT count() FROM ContentDocument WHERE Id = :contentDocId];
        System.assertEquals(1, beforeCount, 'ContentDocument should exist before deletion');

        Test.startTest();
            // Act : call deleteFile (the controller deletes the ContentDocument)
            GenericAttachmentController.deleteFile(contentDocId);
        Test.stopTest();

        // Assert : ContentDocument must no longer exist (deleted)
        Integer afterCount = [SELECT count() FROM ContentDocument WHERE Id = :contentDocId];
        System.assertEquals(0, afterCount, 'ContentDocument should be deleted by deleteFile');
    }

}