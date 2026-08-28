/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 16-08-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_SendConfirmationLyyti extends RestCallout {

    public Long timestamp;
    public String lyytiId;
    public String publicKey;
    public String privateKey;
    public String uid;

    public WS_SendConfirmationLyyti(String lyytiId) {
        this.lyytiId = lyytiId;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
    }

    public WS_SendConfirmationLyyti() { }

    public override String getMethod() {
        return 'POST';
    }

    public HttpRequest setHeaderAndEndpoint() {
        String callString = 'participant/' + this.lyytiId +'/send_confirmation_message';

        HttpRequest req = new HttpRequest();

        req.setHeader('Accept', 'application/json; charset=utf-8');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', LyytiSignatureUtil.buildAuthorizationHeader(this.publicKey, this.privateKey, this.timestamp, callString));

        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/participant/' + this.lyytiId +'/send_confirmation_message');
        return req;
    }

    public override String setJsonBody() {
        return '';
    }

    public override void processResponse(HttpResponse response){
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' + response.getStatusCode() + ' ' + response.getStatus());   
        }
        else {
            // Get Json Body Result
            String jsonReceived = response.getBody(); 
            Map<String, Object> parsedJson = (Map<String, Object>)JSON.deserializeUntyped(jsonReceived);
            System.debug('jsonReceived : ' + jsonReceived); 
            System.debug('parsedJson : ' + parsedJson);    
        }
    }

    public void sendInDataToExternalService() {
        try {
            callEndPoint(setHeaderAndEndpoint());
        }
        catch(Exception e) {
            //********************** add account id
            System.debug('***call API' + e.getMessage());
            System.debug('*** ' + e.getCause());
            System.debug('**** ' + e.getTypeName());
        } 
    }
}