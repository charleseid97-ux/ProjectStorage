/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 12-03-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_SendCampaignMembers extends RestCallout{

    public Long timestamp;
    public CampaignMember recordToTreat;
    public String status;
    public Integer participant_type;
    public String campaignLyytiId; 
    public String publicKey;
    public String privateKey;
    public String uid;

    public WS_SendCampaignMembers(CampaignMember recordToTreat, String status, Integer participant_type, String campaignLyytiId) {
        this.recordToTreat = recordToTreat;
        this.status = status;
        this.participant_type = participant_type;
        this.campaignLyytiId = this.campaignLyytiId!=null? this.campaignLyytiId : recordToTreat.Campaign.LyytiId__c;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
        //this.timestamp = 1719409271;
    }

    public WS_SendCampaignMembers() {
        
    }


    public override String getMethod(){
        return 'POST';
    }

    public String getSignature(){
        String callString = 'participants/' + this.campaignLyytiId;// +'?check_unique=true';

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
        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/participants/'+this.campaignLyytiId);
        req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody(){
        return new WS_SendCampaignMembersBuild().buildBody(recordToTreat, status, participant_type);
        
    }

    public override void processResponse(HttpResponse response){
        
        
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' +
                    response.getStatusCode() + ' ' + response.getStatus());   
        }else{
            // Get Json Body Result
            String jsonReceived = response.getBody(); 
            Map<String, Object> parsedJson = (Map<String, Object>)JSON.deserializeUntyped(jsonReceived);

            // Accéder à la liste 'results'
            List<Object> results = (List<Object>)parsedJson.get('results');

            // Accéder au premier (et seul) élément de 'results'
            Map<String, Object> firstResult = (Map<String, Object>)results[0];

            // Accéder à 'participants'
            Map<String, Object> participants = (Map<String, Object>)firstResult.get('participants');

            // Obtenir la première (et seule) clé de 'participants'
            String participantKey = '';
            for(String key : participants.keySet()) {
                participantKey = key;
                break;  // Nous n'avons besoin que de la première clé
            }
            this.uid = participantKey;
            System.debug('La clé du participant est : ' + participantKey);     
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