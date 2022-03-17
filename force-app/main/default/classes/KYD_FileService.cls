/**
 * @author  Saad LOZZI
 * @date    11/08/2021
 * @details ...
 *
 * -- History
 * -- Date        Name                       Version  Remarks
 * -- ----------- -------------------------  -------  ---------------------------------------
 * -- 11/08/2021  Saad LOZZI                  1.0      Create
 */

/**
 * Service class for KYD documents/files.
 */
public class KYD_FileService
{
    private class KYDException extends Exception {}

    private static final Elysee_Oauth_Parameters__c ELYSEE_OAUTH_PARAMS = Elysee_Oauth_Parameters__c.getInstance();
    private static final Elysee_Filesystem__c ELYSEE_FILESYSTEM_PARAMS = Elysee_Filesystem__c.getInstance();

    private static final String ACCESS_TOKEN_KEY = 'access_token';

    public void uploadFile(String localDocumentId, String kydDocumentId)
    {
        KYD_Document__c              kydDocument                 = fetchKydDocument(kydDocumentId);
        Legal_Entity__c              legalEntity                 = fetchLegalEntity(kydDocument.LegalEntity__c);
        String                       response                    = synchronizeLegalEntity(legalEntity);
        ContentVersion               localDocument               = fetchLocalFile(localDocumentId);
        String                       fileName                    = getFileName(localDocument);
        Blob                         filePayload                 = buildFilePayload(fileName, localDocument.VersionData);
        Integer                      fileSize                    = filePayload.size();


        KYD_FileInsertResponse     fileInsertResponse     = pushFile(filePayload, fileName);
        KYD_MetadataInsertResponse metadataInsertResponse = pushFileMetadata(kydDocument, fileName, fileSize, fileInsertResponse.path);


        updateKydDocument(kydDocumentId, fileInsertResponse.path, metadataInsertResponse.documentId);
    }

    /**
     * @description Performs an authentication to the external file system using the OAuth 2 Protocol.
     *
     * @return The OAuth authorization token.
     */
    public String OAuth()
    {
        HttpRequest request = new HttpRequest();

        request.setEndpoint(ELYSEE_OAUTH_PARAMS.Endpoint__c);
        request.setMethod('POST');
        request.setBody(
                String.join(
                        new List<String> {
                                'grant_type=' + 'client_credentials',
                                'scope=' + ELYSEE_OAUTH_PARAMS.Scope__c,
                                'client_id=' + ELYSEE_OAUTH_PARAMS.Client_Id__c,
                                'client_assertion=' + buildSignedJWTString(),
                                'client_assertion_type=' + ELYSEE_OAUTH_PARAMS.JWT_Client_Assertion_Type__c
                        },
                        '&'
                )
        );

        HttpResponse response = new Http().send(request);

        validateHttpResponse(response, 'Authentication to the file system failed.');

        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());

        if (!payload.containsKey(ACCESS_TOKEN_KEY))
        {
            throw new KYDException('File system\' Access Token not received.');
        }

        return (String)payload.get(ACCESS_TOKEN_KEY);
    }

    // region Queries & DML

    private Legal_Entity__c fetchLegalEntity(Id legalEntityId)
    {
        return [
                SELECT
                        Id,
                        Name,
                        LEI__c,
                        Country__c,
                        LEI_Status__c,
                        Legal_Entity_City__c,
                        Legal_Entity_Address__c,
                        Business_Zip_Post_Code__c,
                        Full_Legal_Entity_Name__c,
                        Country_of_Incorporation__c
                FROM
                        Legal_Entity__c
                WHERE
                        Id = :legalEntityId
        ];
    }

    private KYD_Document__c fetchKydDocument(Id kydDocumentId)
    {
        return [
                SELECT
                        Id,
                        LegalEntity__c,
                        GED_Document_Id__c,
                        KYD_Document_Configuration__c,
                        KYD_Due_Diligence_Oversight__c
                FROM
                        KYD_Document__c
                WHERE
                        Id = :kydDocumentId
        ];
    }


    /**
     * Retrieved the record that corresponds to the uploaded file.
     * This method is guaranteed to succeed if called through the standard salesforce file upload component, hence
     *  the absence of exception handling.
     *
     * @param fileId The ID of the file.
     *
     * @return The ContentVersion record corresponding to the uploaded file.
     */
    private ContentVersion fetchLocalFile(Id fileId)
    {
        return [
                SELECT
                        VersionData,
                        Title,
                        FileExtension
                FROM
                        ContentVersion
                WHERE
                ContentDocumentId = :fileId AND
                IsLatest = TRUE
                LIMIT 1
        ];
    }

    private void updateKydDocument(Id kydDocumentId, String remoteFilePath, String remoteDocumentId)
    {
        update new KYD_Document__c(
                Id = kydDocumentId,
                External_Repository_Id__c = remoteFilePath,
                Status__c = 'Uploaded',
                GED_Document_Id__c = remoteDocumentId
        );
    }

    // endregion

    // region WebService Calls

    private KYD_FileInsertResponse pushFile(Blob filePayload, String fileName)
    {
        Blob requestPayload = buildFilePayload(fileName, filePayload);

        HttpResponse httpResponse = new Http().send(buildFileInsertRequest(requestPayload));

        validateHttpResponse(httpResponse);

        KYD_FileInsertResponse response = (KYD_FileInsertResponse)JSON.deserialize(
                httpResponse.getBody(),
                KYD_FileInsertResponse.class
        );

        if (response.path == null)
        {
            throw new KYDException('The remote service did not provide a remote file path.');
        }

        return response;
    }

    private KYD_MetadataInsertResponse pushFileMetadata(
            KYD_Document__c kydDocument,
            String fileName,
            Integer fileSize,
            String remoteFilePath
    )
    {
        HttpResponse httpResponse = new Http().send(
                buildMetadataRequest(
                        buildMetadataRequestDto(
                                kydDocument,
                                fileName,
                                fileSize,
                                remoteFilePath
                        )
                )
        );

        validateHttpResponse(httpResponse);

        List<KYD_MetadataInsertResponse> response = (List<KYD_MetadataInsertResponse>)JSON.deserialize(
                httpResponse.getBody(),
                List<KYD_MetadataInsertResponse>.class
        );

        if (response.isEmpty())
        {
            throw new KYDException('The remote server did not respond.');
        }

        if (response[0].documentId == null)
        {
            throw new KYDException('The remote server did not provide a document ID.');
        }

        return response[0];
    }

    // endregion

    // region WebService Helpers

    private HttpRequest buildMetadataRequest(Object requestDto)
    {
        HttpRequest httpRequest = new HttpRequest();

        httpRequest.setMethod('POST');
        httpRequest.setEndpoint(ELYSEE_FILESYSTEM_PARAMS.Upload_MetaData_Endpoint__c);
        httpRequest.setHeader('content-type', 'application/json');
        httpRequest.setHeader('Authorization', 'Bearer ' + OAuth());

        String payload = JSON.serialize(new List<Object> {requestDto});

        httpRequest.setBody(payload);

        return httpRequest;
    }

    private Object buildMetadataRequestDto(
            KYD_Document__c kydDocument,
            String fileName,
            Integer fileSize,
            String remoteFilePath
    )
    {
        if (isUpdate(kydDocument))
        {
            KYD_MetadataUpdateRequest request = new KYD_MetadataUpdateRequest();
            request.documentId = kydDocument.GED_Document_Id__c;
            request.salesforceId = kydDocument.LegalEntity__c;
            request.kydIds = kydDocument.KYD_Due_Diligence_Oversight__c;
            request.salesforceDocumentTypeId = kydDocument.KYD_Document_Configuration__c;
            request.originalName = fileName;
            request.path = remoteFilePath;
            request.size = fileSize;
            return request;
        }
        else
        {
            KYD_MetadataInsertRequest request = new KYD_MetadataInsertRequest();
            request.salesforceId = kydDocument.LegalEntity__c;
            request.kydIds = kydDocument.KYD_Due_Diligence_Oversight__c;
            request.salesforceDocumentTypeId = kydDocument.KYD_Document_Configuration__c;
            request.originalName = fileName;
            request.path = remoteFilePath;
            request.size = fileSize;
            return request;
        }
    }

    private HttpRequest buildFileInsertRequest(Blob payload)
    {

        String contentLength = String.valueOf(payload.size());

        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(ELYSEE_FILESYSTEM_PARAMS.Upload_Endpoint__c);
        request.setHeader('Authorization', 'Bearer ' + OAuth());
        request.setHeader('content-type', MultiPartRequestBuilder.GetContentType());
        request.setHeader('Content-Length', contentLength);
        request.setBodyAsBlob(payload);

        return request;
    }

    private Blob buildFilePayload(String fileName, Blob attachmentBody)
    {
        String timestamp = getTimestamp();
        String params = String.join(
                new List<String>
                {
                        MultiPartRequestBuilder.append('Source', 'Salesforce'),
                        MultiPartRequestBuilder.append('Dataset', 'ProfessionalClientsDocuments'),
                        MultiPartRequestBuilder.append('Target', 'Elysee'),
                        MultiPartRequestBuilder.append('CorrelationId', timestamp),
                        MultiPartRequestBuilder.append('DateStarted', timestamp)
                },
                ''
        );

        return MultiPartRequestBuilder.makeBlobWithFile('File', attachmentBody, fileName, params);
    }

    private String buildSignedJWTString()
    {
        Auth.JWT jwt = new Auth.JWT();

        jwt.setIss(ELYSEE_OAUTH_PARAMS.Client_Id__c);
        jwt.setSub(ELYSEE_OAUTH_PARAMS.Client_Id__c);
        jwt.setAud(ELYSEE_OAUTH_PARAMS.Endpoint__c);

        String jwtPayload = EncodingUtil.base64Encode(Blob.valueOf(jwt.toJSONString()));

        String signature = EncodingUtil.urlEncode(
                EncodingUtil.base64Encode(
                        Crypto.signWithCertificate(
                                ELYSEE_OAUTH_PARAMS.JWT_Encryption_Algorithm__c,
                                Blob.valueOf(ELYSEE_OAUTH_PARAMS.JWT_Header__c + '.' + jwtPayload),
                                ELYSEE_OAUTH_PARAMS.JWT_Certificate_Name__c
                        )
                ),
                'UTF-8'
        );

        return String.join(new List<String>{ ELYSEE_OAUTH_PARAMS.JWT_Header__c, jwtPayload, signature}, '.');
    }

    private String synchronizeLegalEntity(Legal_Entity__c legalEntity)
    {
        GED_LegalEntityService service = new GED_LegalEntityService();
        return service.pushLegalEntity(legalEntity);
    }

    // endregion

    // region Helpers

    private String getFileName(ContentVersion localDocument)
    {
        return String.format('{0}.{1}', new List<String>{localDocument.Title, localDocument.FileExtension});
    }

    private String getTimestamp()
    {
        Datetime now = Datetime.now();

        String value = String.join(
                new List<String>
                {
                        String.valueOf(now.year()),
                        String.valueOf(now.month()),
                        String.valueOf(now.day()),
                        String.valueOf(now.hour()),
                        String.valueOf(now.minute())
                },
                ''
        );

        return value;
    }

    private void validateHttpResponse(HttpResponse response)
    {
        validateHttpResponse(response, 'Request Failed');
    }

    private void validateHttpResponse(HttpResponse response, String customMessage)
    {
        String errorMessage = customMessage + ' [{0}, {1}]';

        if (response.getStatusCode() != 200)
        {
            throw new KYDException(
                    String.format(
                            errorMessage,
                            new List<String>{
                                    String.valueOf(response.getStatusCode()),
                                    response.getStatus()
                            }
                    )
            );
        }
    }

    private Boolean isUpdate(KYD_Document__c kydDocument)
    {
        return !String.isBlank(kydDocument.GED_Document_Id__c);
    }

    // endregion
}