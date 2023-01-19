/**
 * Created by noorg on 13/07/2021.
 */

@SuppressWarnings('ApexUnusedDeclaration')
global with sharing class KYD_UploadController
{
    @AuraEnabled(Cacheable=false)
    public static void uploadFileContent(String fileId, String recordId)
    {
        try
        {
            KYD_FileService fileService = new KYD_FileService();

            fileService.uploadFile(fileId, recordId);
        } finally
        {
            Database.delete(fileId);
        }
    }

    @AuraEnabled(Cacheable=false)
    public static void uploadFileContents(List<String> fileIds, String recordId)
    {
        try
        {
            Map<Id, KYD_Document__c> documentsToUpdate = new Map<Id, KYD_Document__c>();
            List<KYD_Document_Item__c> documentItemsToInsert = new List<KYD_Document_Item__c>();
            
            for(String localDocumentId : fileIds)
            {
                KYD_FileService.ResponseInfo response = callUploadService(localDocumentId, recordId);
                KYD_Document__c documentToUpdate = updateKydDocument(response.kydId, response.path, response.documentId);
                KYD_Document_Item__c documentToInsert = insertKydDocumentItem(response.kydId, response.path, response.documentId);
                documentsToUpdate.put(documentToUpdate.Id, documentToUpdate);
                documentItemsToInsert.add(documentToInsert);
            }
            update documentsToUpdate.values();
            insert documentItemsToInsert;
        } finally
        {
            Database.delete(fileIds);
        }
    }
    
    private static KYD_Document__c updateKydDocument(Id kydDocumentId, String remoteFilePath, String remoteDocumentId)
    {
        return new KYD_Document__c(
                Id = kydDocumentId,
                Status__c = 'Uploaded',
                GED_Document_Id__c = remoteDocumentId
        );
    }

    private static KYD_Document_Item__c insertKydDocumentItem(Id kydDocumentId, String remoteFilePath, String remoteDocumentId)
    {
        return new KYD_Document_Item__c(
                KYD_Document__c = kydDocumentId,
                GED_Document_Id__c = remoteDocumentId,
                Status__c = 'Uploaded',
                External_Repository_Id__c = remoteFilePath,
            	Name = remoteFilePath.substring((Integer) remoteFilePath.lastIndexOf('/') + 1) 
        );
    }
    
    //@future(callout=true)
    public static KYD_FileService.ResponseInfo callUploadService(String fileId, String recordId)
    {
        KYD_FileService fileService = new KYD_FileService();
        
        return fileService.uploadFile(fileId, recordId);
    }
}