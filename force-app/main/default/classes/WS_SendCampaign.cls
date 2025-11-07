/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_SendCampaign extends RestCallout{

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

    public override String getMethod(){
        return 'POST';
    }

    public String getSignature(){
        String callString = 'events';

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
        req.setHeader( 'Content-Type', 'application/json' );
        req.setHeader( 'Authorization', 'LYYTI-API-V2 public_key='+this.publicKey+', timestamp='+this.timestamp+', signature='+getSignature() );
        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/events');
        req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody(){
        return new WS_SendCampaignBuild().getJsonString(recordToTreat);
        
    }

    public override void processResponse(HttpResponse response){
        
        
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' +
                    response.getStatusCode() + ' ' + response.getStatus());   
        }else{
            // Get Json Body Result
            String jsonReceived = response.getBody(); 
            Map<String, Object> parsedJson = (Map<String, Object>)JSON.deserializeUntyped(jsonReceived);

            Map<String, Object> results = (Map<String, Object>)parsedJson.get('results');

            // Extract "eid" and "participant_types"
            this.eid = (Integer)results.get('eid');
            /*Map<String, Object> participant_types = (Map<String, Object>) results.get('participant_types');
            // Obget first id
            String participantType = '';
            for(String key : participant_types.keySet()) {
                participantType = key;
                break;  
            }
            this.participant_type = Integer.valueOf(participantType);
            System.debug('Type : ' + participantType); */

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