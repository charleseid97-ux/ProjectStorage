/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 06-18-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
private class AttachmentControllerTest {
    
    @TestSetup
    static void makeData() {
        // Create a Case record
        Case parentCase = new Case(
            Subject = 'Parent Case',target_languages__c='Italian;English',Translation_Request_Type__c = 'Translation Only',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId()
        );
        insert parentCase;
        
        // Create a child Case record
        // Case childCase = new Case(
        //     Subject = 'Child Case',
        //     ParentId = parentCase.Id,
        //     RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId(),
        //     Source_Language__c = 'English',
        //     Sub_Target_language__c = 'French'
        // );
        // insert childCase;
        
        // Create a ContentVersion and ContentDocument for the parent Case
        ContentVersion parentContentVersion = new ContentVersion(
            Title = 'Source_Parent File',
            PathOnClient = 'parent.txt',
            VersionData = Blob.valueOf('Parent file content'),
            IsMajorVersion = true,
            isSource__c = true,
            Publication_File__c = false,
            File_translation_type__c = true
        );
        insert parentContentVersion;
        
        ContentDocument parentContentDocument = [
            SELECT Id, LatestPublishedVersionId
            FROM ContentDocument
            WHERE LatestPublishedVersionId = :parentContentVersion.Id
        ];
        
        // Create a ContentDocumentLink for the parent Case
        ContentDocumentLink parentLink = new ContentDocumentLink(
            LinkedEntityId = parentCase.Id,
            ContentDocumentId = parentContentDocument.Id,
            ShareType = 'V'
        );
        insert parentLink;
    }
    
    @IsTest
    static void testDeleteFile_success() {
        Id docId = [
            SELECT Id
            FROM ContentDocument
        ].Id;

        System.assertNotEquals(null, docId, 'Le ContentDocumentId ne doit pas être nul');

        System.assertEquals(1, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId]);

        Test.startTest();
        AttachmentController.deleteFile(docId);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM ContentDocument WHERE Id = :docId];
        System.assertEquals(0, remaining, 'Le fichier aurait dû être supprimé');
    }
    
    @isTest
    static void testGetFilteredAttachments() {
        // Get the parent and child Case records
        Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Parent Case' LIMIT 1];
        
        Test.startTest();
        
        // Test getFilteredAttachments for the parent Case (isSource = true)
        List<AttachmentController.FileWrapper> parentFiles = AttachmentController.getFilteredAttachments(parentCase.Id, false, true);
        System.assertEquals(1, parentFiles.size(), 'Expected one source file for the parent Case');
        
        // Test getFilteredAttachments for the child Case (isSource = false)
        // List<AttachmentController.FileWrapper> childFiles = AttachmentController.getFilteredAttachments(childCase.Id, false, false);
        // System.assertEquals(0, childFiles.size(), 'Expected no target files for the child Case initially');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetFilteredAttachmentsForPublicationRequest() {
        // Get the parent and child Case records
        Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Parent Case' LIMIT 1];
        Case childCase = [SELECT Id FROM Case WHERE ParentId = :parentCase.Id LIMIT 1];
        
        // Update the child Case record type to Sub Publication Request
        childCase.RecordTypeId =  Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Publication Request').getRecordTypeId();
        
        update childCase;
        
        Test.startTest();
        
        // Test getFilteredAttachments for the child Case (isPublication = true)
        List<AttachmentController.FileWrapper> publicationFiles = AttachmentController.getFilteredAttachments(childCase.Id, true, false);
        System.assertEquals(0, publicationFiles.size(), 'Expected no publication files for the child Case initially');
        
        Test.stopTest();
    }
}