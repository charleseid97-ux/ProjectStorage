@isTest
public class Test_ProjectDocumentController {
    @testSetup
    static void setupData() {
        // Créer un projet parent
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
 
        // Créer un document Projet
        ProjectDocuments__c doc = new ProjectDocuments__c(
            Name = 'TestDoc',
Project_product__c = proj.Id,
            RecordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectDocuments__c', 'Core_Document'),
            Type__c = 'Prospectus',
OneDriveLink__c = 'https://example.com',
Date__c = Date.today()
        );
        insert doc;
 
        // Créer un ContentDocument et ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'MyFile',
            PathOnClient = 'MyFile.txt',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;
        // Récupérer l'ID du ContentDocument généré
cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        // Créer un Lien entre le document et le fichier
        ContentDocumentLink cdl = new ContentDocumentLink(
LinkedEntityId = doc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }
 
    @isTest
    static void testGetDocumentsLinkAndRetrieveFiles() {
        // Récupérer le projet et le doc créés
        ProjectDocuments__c doc = [SELECT Id, Project_product__c, RecordTypeId FROM ProjectDocuments__c LIMIT 1];
        Id projId = doc.Project_product__c;
 
        Test.startTest();
        // tester getDocuments
        List<ProjectDocuments__c> docs = ProjectDocumentController.getDocuments(projId, doc.RecordTypeId);
        // tester getFilesForRecord
List<ContentDocument> filesBefore = ProjectDocumentController.getFilesForRecord(doc.Id);
 
        // tester linkFilesToRecord
        // créer un nouveau ContentVersion
        ContentVersion newCv = new ContentVersion(
            Title = 'NewFile',
            PathOnClient = 'NewFile.txt',
            VersionData = Blob.valueOf('Other')
        );
        insert newCv;
newCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :newCv.Id];
 
        // attacher ce nouveau fichier
ProjectDocumentController.linkFilesToRecord(doc.Id, new List<String>{newCv.ContentDocumentId});
        // récupérer les fichiers à nouveau
List<ContentDocument> filesAfter = ProjectDocumentController.getFilesForRecord(doc.Id);
        Test.stopTest();

    }
}