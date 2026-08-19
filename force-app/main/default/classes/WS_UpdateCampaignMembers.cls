/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 20-03-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_UpdateCampaignMembers extends RestCallout {

    public Long timestamp;
    public CampaignMember recordToTreat;
    public String status;
    public String lyytiId;
    public String publicKey;
    public String privateKey;
    public String uid;

    public WS_UpdateCampaignMembers(CampaignMember recordToTreat, String status, String lyytiId) {
        this.recordToTreat = recordToTreat;
        this.status = status;
        this.lyytiId = recordToTreat.LyytiId__c != null ? recordToTreat.LyytiId__c : lyytiId;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
    }

    public WS_UpdateCampaignMembers() { }

    public override String getMethod() {
        return 'PATCH';
    }

    public HttpRequest setHeaderAndEndpoint() {
        String callString = 'events/' + recordToTreat.Campaign.LyytiId__c + '/participants/' + this.lyytiId.split('-')[1];

        HttpRequest req = new HttpRequest();

        req.setHeader('Accept', 'application/json; charset=utf-8');
        req.setHeader('Content-Type', 'application/merge-patch+json');
        req.setHeader('Authorization', LyytiSignatureUtil.buildAuthorizationHeader(this.publicKey, this.privateKey, this.timestamp, callString));

        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/events/' + recordToTreat.Campaign.LyytiId__c + '/participants/' + this.lyytiId.split('-')[1]);
    
        req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody() {
        return buildBody(recordToTreat);
    }

    public String buildBody(CampaignMember campaignMember) {
        if(status!='cancelled'){
			System.debug('status 1:'+status);
            Map<String, Object> jsonMap = new Map<String, Object>();
            jsonMap.put('status', this.status);
			System.debug('json 1:'+JSON.serialize(jsonMap));
            return  JSON.serialize(jsonMap);
        }
        else{
			System.debug('status 2:'+status);
            Map<String, Object> jsonMap = new Map<String, Object>();
            jsonMap.put('organiser_notes', 'cancelled');
            jsonMap.put('status', 'reactedno');
			System.debug('json 2:'+JSON.serialize(jsonMap));
            return  JSON.serialize(jsonMap);
        }
    }

    public override void processResponse(HttpResponse response){
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' + response.getStatusCode() + ' ' + response.getStatus());   
        }
        else {
            // Get Json Body Result
            String jsonReceived = response.getBody(); 
            System.debug('jsonReceived : ' + jsonReceived);     
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