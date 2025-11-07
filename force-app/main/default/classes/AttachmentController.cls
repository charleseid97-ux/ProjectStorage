/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 10-24-2024
 * @last modified by  : SILA Nicolas
**/
public with sharing class AttachmentController {
    private static final Id subPublicationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Publication Request').getRecordTypeId();

    @AuraEnabled(cacheable= true)
    public static List<FileWrapper> getFilteredAttachments(String parentId, Boolean isPublication,Boolean isSource) {
        // Query to fetch the files linked to the parent record

        String docParentId = parentId;
        if (isSource){
            Case caseParent = [SELECT ParentId,RecordTypeId FROM Case WHERE id =: parentId LIMIT 1] ;
            docParentId = String.isBlank(caseParent.parentId)? parentId : caseParent.parentId ;
            
        }
        // Query for ContentDocumentLinks directly related to the parent
        List<ContentDocumentLink> directLinks = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.CreatedDate,ContentDocument.LatestPublishedVersion.Publication_File__c
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :docParentId 
                AND ContentDocument.LatestPublishedVersion.isSource__c = :isSource AND ContentDocument.LatestPublishedVersion.Publication_File__c = :isPublication
            ORDER BY ContentDocument.CreatedDate DESC
        ];

        // Query for ContentDocumentLinks related via EmailMessages linked to the parent
        List<ContentDocumentLink> emailToCaseLinks = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType,
                    ContentDocument.CreatedDate,ContentDocument.LatestPublishedVersion.Publication_File__c
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN (SELECT Id FROM EmailMessage WHERE ParentId = :docParentId AND Incoming = true) 
                AND ContentDocument.LatestPublishedVersion.isSource__c = :isSource AND ContentDocument.LatestPublishedVersion.Publication_File__c = :isPublication
                AND (NOT ContentDocument.Title LIKE 'Source_%') AND ContentDocument.FileExtension not in ('jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'svg')
        ];
        // Combine results in Apex using Maps to avoid duplicates
        Map<Id, ContentDocumentLink> documentLinkMap = new Map<Id, ContentDocumentLink>();
        for (ContentDocumentLink link : directLinks) {
            documentLinkMap.put(link.ContentDocumentId, link);
        }
        for (ContentDocumentLink link : emailToCaseLinks) {
            // This will ensure no duplicate ContentDocumentId is added; it prefers the first query's links
            if (!documentLinkMap.containsKey(link.ContentDocumentId)) {
                documentLinkMap.put(link.ContentDocumentId, link);
            }
        }
        List<ContentDocumentLink> fileLinks = new List<ContentDocumentLink>(documentLinkMap.values());

        // Transform the data into a custom wrapper for use in LWC
        List<FileWrapper> wrappedFiles = new List<FileWrapper>();
        for (ContentDocumentLink link : fileLinks) {
            wrappedFiles.add(new FileWrapper(
                link.ContentDocumentId,
                link.ContentDocument.Title,
                link.ContentDocument.FileType,
                link.ContentDocument.CreatedDate
            ));
        }

        return wrappedFiles;
    }

    // Wrapper class to hold relevant file information
    public class FileWrapper {
        @AuraEnabled public String contentDocumentId { get; private set; }
        @AuraEnabled public String title { get; private set; }
        @AuraEnabled public String fileType { get; private set; }
        @AuraEnabled public String documentUrl { get; private set; }
        @AuraEnabled public DateTime createdDate { get; private set; }
        
        // Constructor
        public FileWrapper(String contentDocumentId, String title, String fileType, DateTime createdDate) {
            this.contentDocumentId = contentDocumentId;
            this.title = title;
            this.fileType = fileType;
            this.createdDate = createdDate;
        }
    }
}