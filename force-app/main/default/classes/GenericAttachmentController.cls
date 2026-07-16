public with sharing class GenericAttachmentController {

    @AuraEnabled
    public static void deleteFile(Id contentDocumentId) {
        new FileDeleter().deleteAsSystem(contentDocumentId);
    }

    private without sharing class FileDeleter {
        public void deleteAsSystem(Id contentDocumentId) {
            try {
                delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
            } catch (Exception e) {
                throw new AuraHandledException('Erreur suppression fichier : ' + e.getMessage());
            }
        }
    }

    public class FileWrapper {
        @AuraEnabled public String contentDocumentId { get; private set; }
        @AuraEnabled public String title { get; private set; }
        @AuraEnabled public String fileType { get; private set; }
        @AuraEnabled public Datetime createdDate { get; private set; }

        public FileWrapper(String contentDocumentId, String title, String fileType, Datetime createdDate) {
            this.contentDocumentId = contentDocumentId;
            this.title = title;
            this.fileType = fileType;
            this.createdDate = createdDate;
        }
    }

    // ✅ ajout filePrefix
    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getAttachments(String parentId, String filePrefix) {
        if (String.isBlank(parentId)) return new List<FileWrapper>();

        String prefix = String.isBlank(filePrefix) ? null : filePrefix.trim();

        List<ContentDocumentLink> links;
        if (prefix == null) {
            links = [
                SELECT ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :parentId
                ORDER BY ContentDocument.CreatedDate DESC
            ];
        } else {
            String likePattern = prefix + '%'; // ✅ simple

            links = [
                SELECT ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :parentId
                AND ContentDocument.Title LIKE :likePattern
                ORDER BY ContentDocument.CreatedDate DESC
            ];
        }

        List<FileWrapper> outList = new List<FileWrapper>();
        for (ContentDocumentLink l : links) {
            outList.add(new FileWrapper(
                String.valueOf(l.ContentDocumentId),
                l.ContentDocument.Title,
                l.ContentDocument.FileType,
                l.ContentDocument.CreatedDate
            ));
        }
        return outList;
    }
}