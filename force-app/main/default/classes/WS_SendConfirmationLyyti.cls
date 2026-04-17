/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 16-08-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_SendConfirmationLyyti extends RestCallout{

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
        //this.timestamp = 1719409271;
    }

    public WS_SendConfirmationLyyti() {
        
    }


    public override String getMethod(){
        return 'POST';
    }

    public String getSignature(){
        String callString = 'participant/' + this.lyytiId +'/send_confirmation_message';

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
        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/participant/' + this.lyytiId +'/send_confirmation_message');
        //req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody(){
        return '';
        
    }

    public override void processResponse(HttpResponse response){
        
        
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' +
                    response.getStatusCode() + ' ' + response.getStatus());   
        }else{
            // Get Json Body Result
            String jsonReceived = response.getBody(); 
            Map<String, Object> parsedJson = (Map<String, Object>)JSON.deserializeUntyped(jsonReceived);
            System.debug('jsonReceived : ' + jsonReceived); 
            System.debug('parsedJson : ' + parsedJson); 
               
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