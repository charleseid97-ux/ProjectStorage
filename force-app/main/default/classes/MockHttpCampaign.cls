/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 15-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
global  class MockHttpCampaign implements HttpCalloutMock { 
    
    private Integer statusCode; 
    private String responseBody; 

    global MockHttpCampaign() { 
        this.statusCode = 200; 
        this.responseBody = '{"results": {"eid": 1704919, "participant_types": {"62929867": {"participant_type_id": 62929867, "name": {"fr": "Invited", "en": "Invited"}}, "62929873": {"participant_type_id": 62929873, "name": {"fr": "Social Media", "en": "Social Media"}}}}}'; 
    }

    global MockHttpCampaign(Integer statusCode, String responseBody) { 
        this.statusCode = statusCode; 
        this.responseBody = responseBody; 
    }

    global  HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setBody(this.responseBody); 
        res.setStatusCode(this.statusCode);
        return res;
    } 
}