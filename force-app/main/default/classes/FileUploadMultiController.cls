/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 09-20-2024
 * @last modified by  : SILA Nicolas
**/
public class FileUploadMultiController {
    
    @AuraEnabled
    public static String uploadNewFile(String recordId, String fileData, String filePrefix, Boolean isSource,Boolean isPublication) {

        try {
            // Deserialize input data
            if (String.isNotBlank(fileData)) {
                List<FileDataWP> files = (List<FileDataWP>) JSON.deserialize(fileData, List<FileDataWP>.class);
                List<String> filesId = new List<String>();
                List<ContentVersion> cvList = new List<ContentVersion>();

                for (FileDataWP file : files) {

                    filesId.add(file.contentVersionId);
                    String newFileName = file.fileName.replace('Source_', '');
                    newFileName = newFileName.replace('Target_', '');

                    ContentVersion conVer = new ContentVersion();
                    conVer.ContentLocation = 'S'; // S = Salesforce, E = External Files
                    conVer.Title = filePrefix + newFileName;
                    conVer.PathOnClient = filePrefix + newFileName;
                    conVer.Id = file.contentVersionId;
                    conVer.File_translation_type__c = true;
                    if(isSource == true){
                        conVer.isSource__c = true;
                    }
                    if(isPublication == true){
                        conVer.Publication_File__c = true;
                    }
                    cvList.add(conVer);
                }

                // Insert new versions
                update cvList;
                // If the fileId is blank, associate the newly created documents
                if (filesId.size() > 0) {
                    List<ContentDocumentLink> cdList = new List<ContentDocumentLink>();
                    for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN : filesId ]) {
                        ContentDocumentLink conDocLink = new ContentDocumentLink();
                        conDocLink.LinkedEntityId = recordId;
                        conDocLink.ContentDocumentId = cv.ContentDocumentId;
                        conDocLink.Visibility = 'AllUsers';
                        conDocLink.ShareType = 'I'; // V = Viewer, C = Collaborator, I = Inferred
                        cdList.add(conDocLink);
                    }
                    insert cdList;
                }

                return 'success';
            } else {
                return 'record Id or file data is blank';
            }

        } catch (Exception ex) {
            System.debug(ex.getMessage() + ' -> ' + ex.getStackTraceString());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    // Inner wrapper class for file data
    public class FileDataWP {
        public String fileName;
        public String documentId;
        public String contentVersionId;
        public String fileContent;
    }
}