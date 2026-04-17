/**
 * Created by Saad on 28/02/2022.
 */

public with sharing class BATCH_KYDSendDocs implements Database.Batchable<SObject>,   Database.AllowsCallouts
{
    String query = 'SELECT Id, External_Repository_Id__c ' +
            '        FROM KYD_Document__c ' +
            '        WHERE LastModifiedDate = TODAY ' +
            '        AND External_Repository_Id__c != NULL ' +
            '        AND (NOT External_Repository_Id__c LIKE \'raw/salesforce%\') ';

    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<KYD_Document__c> documents)
    {
        List<ContentVersion> cvList = [
                SELECT
                        VersionData,
                        Title,
                        FileExtension,
                        ContentDocumentId
                FROM
                        ContentVersion
                WHERE
                        CreatedDate = TODAY
        ];

        if(cvList.size() > 0)
        {
            Map<String, ContentVersion> titleToFile = new Map<String, ContentVersion>();

            for(ContentVersion cv : cvList)
            {
                titleToFile.put(cv.Title, cv);
            }

            Set<Id> fileIds = new Set<Id>();

            KYD_FileService service = new KYD_FileService();

            for(KYD_Document__c document : documents)
            {
                Id fileId = titleToFile.get(document.External_Repository_Id__c)?.ContentDocumentId;
                if(fileId != null)
                {
                    if(!Test.isRunningTest()) service.uploadFile(fileId, document.Id);
                    fileIds.add(fileId);
                }
            }
            delete [SELECT Id FROM ContentDocument WHERE Id IN :fileIds];
        }
    }

    public void finish(Database.BatchableContext BC)
    {

    }
}