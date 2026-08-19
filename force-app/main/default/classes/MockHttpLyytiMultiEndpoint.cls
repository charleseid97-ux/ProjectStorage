@isTest
global class MockHttpLyytiMultiEndpoint implements HttpCalloutMock {

    private Integer statusCode;
    private String participantTypesBody;
    private String participantsBody;

    global MockHttpLyytiMultiEndpoint(String participantTypesBody, String participantsBody) {
        this.statusCode = 200;
        this.participantTypesBody = participantTypesBody;
        this.participantsBody = participantsBody;
    }

    global MockHttpLyytiMultiEndpoint(Integer statusCode, String participantTypesBody, String participantsBody) {
        this.statusCode = statusCode;
        this.participantTypesBody = participantTypesBody;
        this.participantsBody = participantsBody;
    }

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);

        if (req.getEndpoint().contains('participant_types')) {
            res.setBody(this.participantTypesBody);
        } 
        else {
            res.setBody(this.participantsBody);
        }
        return res;
    }
}