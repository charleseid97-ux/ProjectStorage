/** ──────────────────────────────────────
 * @description Tests of ProjectDocumentController: documents of a project by record type, files of a document, and a new file linked
 *                  to the document.
 * @covers ProjectDocumentController   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ProjectDocumentController {

    @isTest
    static void test_documentsAndFiles() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        ProjectDocuments__c doc = new ProjectDocuments__c(Name = 'TestDoc', Project_product__c = proj.Id, RecordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectDocuments__c', 'Core_Document'), Type__c = 'Prospectus', OneDriveLink__c = 'https://example.com', Date__c = Date.today());
        insert doc;

        // A file already linked to the document, and a new file to link
        ContentVersion linkedFile = new ContentVersion(Title = 'MyFile', PathOnClient = 'MyFile.txt', VersionData = Blob.valueOf('Test content'));
        ContentVersion newFile = new ContentVersion(Title = 'NewFile', PathOnClient = 'NewFile.txt', VersionData = Blob.valueOf('Other'));
        insert new List<ContentVersion>{ linkedFile, newFile };
        List<ContentVersion> versions = [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :new List<Id>{ linkedFile.Id, newFile.Id }];
        Map<Id, ContentVersion> versionById = new Map<Id, ContentVersion>(versions);
        insert new ContentDocumentLink(LinkedEntityId = doc.Id, ContentDocumentId = versionById.get(linkedFile.Id).ContentDocumentId, ShareType = 'V', Visibility = 'AllUsers');

        Test.startTest();

        List<ProjectDocuments__c> docs = ProjectDocumentController.getDocuments(proj.Id, doc.RecordTypeId);
        List<ContentDocument> filesBefore = ProjectDocumentController.getFilesForRecord(doc.Id);
        ProjectDocumentController.linkFilesToRecord(doc.Id, new List<String>{ versionById.get(newFile.Id).ContentDocumentId });
        List<ContentDocument> filesAfter = ProjectDocumentController.getFilesForRecord(doc.Id);

        Test.stopTest();

        System.assertEquals(1, docs.size(), 'Document of the project');
        System.assertEquals(1, filesBefore.size(), 'File already linked');
        System.assertEquals(2, filesAfter.size(), 'New file linked to the document');
    }
}