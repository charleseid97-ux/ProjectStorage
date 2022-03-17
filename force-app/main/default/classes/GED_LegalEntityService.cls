/**
 * Created by Saad LOZZI on 22/10/2021.
 */

public with sharing class GED_LegalEntityService
{
    private class GEDException extends Exception {}

    private static final Elysee_Filesystem__c ELYSEE_FILESYSTEM_PARAMS = Elysee_Filesystem__c.getInstance();

    private Object buildLegalEntityRequestDto(
            Legal_Entity__c legalEntity
    )
    {
        LegalEntityRequest request = new LegalEntityRequest();
        request.salesforceId = legalEntity.Id;
        request.lei = legalEntity.LEI__c;
        request.entityStatus = legalEntity.LEI_Status__c;
        request.entityName = legalEntity.Name;
        request.legalName = legalEntity.Full_Legal_Entity_Name__c;
        request.locationStreet1 = legalEntity.Legal_Entity_Address__c;
        request.locationCity = legalEntity.Legal_Entity_City__c;
        request.addressCountry = legalEntity.Country__c;
        request.locationPostalCode = legalEntity.Business_Zip_Post_Code__c;
        request.countryOfIncorporation = legalEntity.Country_of_Incorporation__c;
        return request;
    }

    public String pushLegalEntity(
            Legal_Entity__c legalEntity
    )
    {
        HttpResponse httpResponse = new Http().send(
                buildLegalEntityRequest(
                        buildLegalEntityRequestDto(
                                legalEntity
                        )
                )
        );

        validateHttpResponse(httpResponse);

        if (String.isEmpty(httpResponse.getBody()))
        {
            throw new GEDException('The remote server did not respond.');
        }

        return httpResponse.getBody();
    }

    private HttpRequest buildLegalEntityRequest(Object requestDto)
    {
        HttpRequest httpRequest = new HttpRequest();

        httpRequest.setMethod('POST');
        httpRequest.setEndpoint(ELYSEE_FILESYSTEM_PARAMS.Legal_Entity_Endpoint__c);
        httpRequest.setHeader('content-type', 'application/json');
        httpRequest.setHeader('Authorization', 'Bearer ' + new KYD_FileService().OAuth());

        String payload = JSON.serialize(new List<Object> {requestDto});

        httpRequest.setBody(payload);

        return httpRequest;
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
            throw new GEDException(
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
}