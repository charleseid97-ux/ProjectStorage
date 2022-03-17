/**
 * Created by Saad LOZZI on 07/09/2021.
 */

@IsTest
private class KYD_FileServiceTest
{
    @TestSetup
    static void setup()
    {
        Elysee_Oauth_Parameters__c setting = new Elysee_Oauth_Parameters__c();
        setting.Endpoint__c = 'OAuth';
        setting.JWT_Encryption_Algorithm__c = 'RSA-SHA256';
        setting.JWT_Header__c = 'Test==';
        setting.JWT_Certificate_Name__c = 'elyseeprod';
        setting.Client_Id__c = 'Test';
        insert setting;

        Elysee_Filesystem__c setting2 = new Elysee_Filesystem__c();
        setting2.Download_Endpoint__c = 'Download';
        setting2.Upload_Endpoint__c = 'Upload';
        setting2.Upload_MetaData_Endpoint__c = 'Metadata';
        setting2.Legal_Entity_Endpoint__c = 'LegalEntity';
        insert setting2;

        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('callout:LEI_INFO/api/v1/lei-records?filter[lei]=5067007V6269EHSP3295&page[size]=50&page[number]=1', 'GLEIF_Response');
        mock.setStaticResource('callout:UME_API/api/v2/network/distributors/', 'UME_Response');
        Test.setMock(HttpCalloutMock.class, mock);

        Legal_Entity__c legalEntity = new Legal_Entity__c(Name = 'Test', LEI__c = '5067007V6269EHSP3295', TECH_brid__c = '5063007V6269EHOP329522');
        insert legalEntity;

        KYD_Due_Diligence_Oversight__c kydDD = new KYD_Due_Diligence_Oversight__c(Name = 'Test',
                KYD_Responsible__c = 'CGL', Active__c = true, LegalEntity__c = legalEntity.Id);
        insert kydDD;

        KYD_Document__c kydDoc = new KYD_Document__c(Name = 'RLE02', Mandatory__c = false, LegalEntity__c = legalEntity.Id,
                Status__c = 'Pending', KYD_Due_Diligence_Oversight__c = kydDD.Id, ExternalId__c = kydDD.Id + '_' + 'RLE02');
        insert kydDoc;

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = 'ABC';
        contentVersion.PathOnClient = 'test';
        contentVersion.VersionData = EncodingUtil.base64Decode('Unit Test Attachment Body');
        insert contentVersion;

        ContentVersion contentVers = [SELECT Id, Title, ContentDocumentId
                                        FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];

        ContentDocumentLink contentLink = new ContentDocumentLink();
        contentLink.LinkedEntityId = kydDoc.Id;
        contentLink.ContentDocumentId = contentVers.ContentDocumentId;
        contentLink.ShareType = 'V';
        insert contentLink;
    }
    @IsTest
    static void testOauthSuccess()
    {
        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('OAuth', 'OAuth_Response');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String response = new KYD_FileService().OAuth();
        Test.stopTest();

        System.assertEquals('Test', response);
    }

    @IsTest
    static void testOauthFail()
    {
        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('OAuth', 'OAuth_Response');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        try{
            new KYD_FileService().OAuth();
        }
        catch(Exception e)
        {
            System.debug('Exception test');
        }

        Test.stopTest();
    }

    @IsTest
    static void testUploadFile()
    {
        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('OAuth', 'OAuth_Response');
        mock.setStaticResource('Upload', 'FileInsert_Response');
        mock.setStaticResource('Metadata', 'Metadata_Response');
        mock.setStaticResource('LegalEntity', 'Metadata_Response');
        Test.setMock(HttpCalloutMock.class, mock);

        Id contentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1].Id;
        Id kydDocId = [SELECT Id FROM KYD_Document__c LIMIT 1].Id;

        Test.startTest();
        new KYD_FileService().uploadFile(contentDocumentId, kydDocId);
        Test.stopTest();
    }

    @IsTest
    static void testUpdateFile()
    {
        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('OAuth', 'OAuth_Response');
        mock.setStaticResource('Upload', 'FileInsert_Response');
        mock.setStaticResource('Metadata', 'Metadata_Response');
        mock.setStaticResource('LegalEntity', 'Metadata_Response');
        Test.setMock(HttpCalloutMock.class, mock);


        Id contentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1].Id;
        KYD_Document__c kydDoc = [SELECT Id FROM KYD_Document__c LIMIT 1];
        kydDoc.GED_Document_Id__c = 'DOC_0001';
        update kydDoc;

        Test.startTest();
        new KYD_FileService().uploadFile(contentDocumentId, kydDoc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testUpload()
    {
        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('OAuth', 'OAuth_Response');
        mock.setStaticResource('Upload', 'FileInsert_Response');
        mock.setStaticResource('Metadata', 'Metadata_Response');
        mock.setStaticResource('LegalEntity', 'Metadata_Response');
        Test.setMock(HttpCalloutMock.class, mock);


        Id contentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1].Id;
        KYD_Document__c kydDoc = [SELECT Id FROM KYD_Document__c LIMIT 1];
        kydDoc.GED_Document_Id__c = 'DOC_0001';
        update kydDoc;

        Test.startTest();
        KYD_UploadController.uploadFileContent(contentDocumentId, kydDoc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testDownload()
    {
        MultiStaticResourceCalloutMock mock = new MultiStaticResourceCalloutMock();
        mock.setHeader('Content-Type', 'application/json');
        mock.setHeader('access_token', 'Test');
        mock.setStatus('Success');
        mock.setStatusCode(200);
        mock.setStaticResource('OAuth', 'OAuth_Response');
        mock.setStaticResource('Download?Path=Test', 'FileInsert_Response');
        Test.setMock(HttpCalloutMock.class, mock);

        KYD_Document__c kydDoc = [SELECT Id FROM KYD_Document__c LIMIT 1];
        kydDoc.External_Repository_Id__c = 'Test';
        update kydDoc;

        ApexPages.StandardController stdController = new ApexPages.StandardController(kydDoc);


        Test.startTest();
        KYD_Download download = new KYD_Download(stdController);
        download.getPdf();
        Test.stopTest();
    }
}