public with sharing class ProjectDocumentController {
    @AuraEnabled(cacheable=true)
    public static List<ProjectDocuments__c > getDocuments(Id recordId , Id recordTypeId) {
        System.debug('recordId => ' + recordId);
        System.debug('recordTypeId => ' + recordTypeId);
        return [SELECT Id, Name, CreatedDate, Type__c, OneDriveLink__c, CreatedBy.Name,Date__c FROM ProjectDocuments__c WHERE Project_product__c =: recordId AND RecordTypeId =:recordTypeId ORDER BY CreatedDate DESC];
    }

    @AuraEnabled
    public static void linkFilesToRecord(String recordId, List<String> contentDocumentIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (String contentDocumentId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                LinkedEntityId = recordId,
                ContentDocumentId = contentDocumentId,
                ShareType = 'V',  // Viewer access
                Visibility = 'AllUsers'
            ));
        }
        insert links;
    }

    @AuraEnabled
    public static List<ContentDocument> getFilesForRecord(String recordId) {
        List<ContentDocument> files = new List<ContentDocument>();

        // Get all ContentDocumentLinks related to the record
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ];

        if (!links.isEmpty()) {
            // Extract ContentDocument IDs
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                documentIds.add(link.ContentDocumentId);
            }

            // Query ContentDocument using the extracted IDs
            files = [
                SELECT Id, Title, FileExtension, LatestPublishedVersionId
                FROM ContentDocument
                WHERE Id IN :documentIds
            ];
        }
        System.debug('files => '+files);
        return files;
    }
}