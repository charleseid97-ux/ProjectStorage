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
}