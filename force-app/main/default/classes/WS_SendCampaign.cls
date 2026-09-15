/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_SendCampaign extends RestCallout {

    public Long timestamp;
    public Campaign recordToTreat;
    public Integer eid;
    public Integer participant_type; 
    public String publicKey;
    public String privateKey;

    public WS_SendCampaign(Campaign recordToTreat) {
        this.recordToTreat = recordToTreat;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
    }

    public override String getMethod() {
        return 'POST';
    }

    public HttpRequest setHeaderAndEndpoint() {
        String callString = 'events';

        HttpRequest req = new HttpRequest();

        req.setHeader('Accept', 'application/json; charset=utf-8');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', LyytiSignatureUtil.buildAuthorizationHeader(this.publicKey, this.privateKey, this.timestamp, callString));

        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/events');

        req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody() {
        return new WS_SendCampaignBuild().getJsonString(recordToTreat);
    }

    public override void processResponse(HttpResponse response) {
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' + response.getStatusCode() + ' ' + response.getStatus());   
        }
        else {
            // Get Json Body Result
            String jsonReceived = response.getBody(); 
            Map<String, Object> parsedJson = (Map<String, Object>)JSON.deserializeUntyped(jsonReceived);

            Map<String, Object> results = (Map<String, Object>)parsedJson.get('results');

            this.eid = (Integer)results.get('eid'); // Extract "eid" and "participant_types"

            Map<String, Object> participantTypes = (Map<String, Object>) results.get('participant_types');
            
            for (String typeId : participantTypes.keySet()) {
                Map<String, Object> typeInfo = (Map<String, Object>) participantTypes.get(typeId);
                Map<String, Object> names = (Map<String, Object>) typeInfo.get('name');
                System.debug('typeId : ' + typeId);
                System.debug('names : ' + names);
                for (Object nameValue : names.values()) {
                    if (nameValue instanceof String && ((String)nameValue).toLowerCase() == 'invited') {
                        System.debug('Type : ' + Integer.valueOf(typeId));
                        this.participant_type = Integer.valueOf(typeId);
                        break;
                    }
                }
            }
        }
    }

    public void sendInDataToExternalService() {
        try {
            callEndPoint(setHeaderAndEndpoint());
        }
        catch(Exception e){
            //********************** add account id
            System.debug('***call API' + e.getMessage());
            System.debug('*** ' + e.getCause());
            System.debug('**** ' + e.getTypeName());
        } 
    }
}