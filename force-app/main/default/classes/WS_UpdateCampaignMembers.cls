/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 20-03-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_UpdateCampaignMembers extends RestCallout{

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
        //this.timestamp = 1719409271;
    }

    public WS_UpdateCampaignMembers() {
        
    }


    public override String getMethod(){
        return 'PATCH';
    }

    public String getSignature(){
        String callString = 'events/' + recordToTreat.Campaign.LyytiId__c + '/participants/' + this.lyytiId.split('-')[1];

        String msg = String.join(new List<String>{
            this.publicKey,
            String.valueOf(this.timestamp),
            callString
        }, ',');

        // Encode the string
        String msgBase64 = EncodingUtil.base64Encode(Blob.valueOf(msg));
        
        // Generate HMAC Signature
        Blob macKey = Blob.valueOf(this.privateKey);
        Blob input = Blob.valueOf(msgBase64);
        Blob hmac = Crypto.generateMac('hmacSHA256', input, macKey);
        
        // Convert To Hex
        String signature = EncodingUtil.convertToHex(hmac);
        return signature;
    }

    public HttpRequest setHeaderAndEndpoint(){
        HttpRequest req = new HttpRequest();
        
        req.setHeader( 'Accept', 'application/json; charset=utf-8' );
        req.setHeader( 'Content-Type', 'application/merge-patch+json' );
        req.setHeader( 'Authorization', 'LYYTI-API-V2 public_key='+this.publicKey+', timestamp='+this.timestamp+', signature='+getSignature() );
        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/events/' + recordToTreat.Campaign.LyytiId__c + '/participants/' + this.lyytiId.split('-')[1]);
        req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody(){
        return buildBody(recordToTreat);
        
    }

    public String buildBody(CampaignMember campaignMember){
        if(status!='cancelled'){
			system.debug('status 1:'+status);
            Map<String, Object> jsonMap = new Map<String, Object>();
            jsonMap.put('status', this.status);
			system.debug('json 1:'+JSON.serialize(jsonMap));
            return  JSON.serialize(jsonMap);

        }else{
			system.debug('status 2:'+status);
            Map<String, Object> jsonMap = new Map<String, Object>();
            jsonMap.put('organiser_notes', 'cancelled');
            jsonMap.put('status', 'reactedno');
			system.debug('json 2:'+JSON.serialize(jsonMap));
            return  JSON.serialize(jsonMap);

        }
        
    }

    

    public override void processResponse(HttpResponse response){
        
        
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' +
                    response.getStatusCode() + ' ' + response.getStatus());   
        }else{
            // Get Json Body Result
            String jsonReceived = response.getBody(); 

            System.debug('jsonReceived : ' + jsonReceived);     
        }
    }

    

    
    public void sendInDataToExternalService() {

        try{
            callEndPoint(setHeaderAndEndpoint());
        }catch(Exception e){
            //********************** add account id
            System.debug('***call API' + e.getMessage());
            System.debug('*** ' + e.getCause());
            System.debug('**** ' + e.getTypeName());
        } 
    }
}