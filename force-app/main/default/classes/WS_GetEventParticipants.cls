/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_GetEventParticipants extends RestCallout{

    public Long timestamp;
    public Campaign recordToTreat;
    public String publicKey;
    public Map<String, String> idEmailMap;
    public String privateKey;
    public Set<String> targetEmails;
    public Integer limitSize;
    public Integer offsetSize;
    public Set<String> remainingEmails;
    public Integer pageItemCount; // combien d'items dans "results" sur la page

    public WS_GetEventParticipants(Campaign recordToTreat, Set<String> targetEmails, Integer limitSize, Integer offsetSize) {
        this.recordToTreat = recordToTreat;
        this.timestamp = System.now().getTime() / 1000;
        this.idEmailMap = new Map<String, String>();
        this.publicKey = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
        this.targetEmails = (targetEmails == null) ? new Set<String>() : targetEmails;

        this.limitSize = (limitSize == null || limitSize <= 0) ? 200 : limitSize;  // <-- 200 (ou 500)
        this.offsetSize = (offsetSize == null || offsetSize < 0) ? 0 : offsetSize;

        this.remainingEmails = new Set<String>();
        this.remainingEmails.addAll(this.targetEmails);
        this.pageItemCount = 0;
    }

    public override String getMethod(){
        return 'GET';
    }

    public String getSignature(){
        String callString = 'events/'+recordToTreat.LyytiId__c+'/participants' ;

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
        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/events/'+recordToTreat.LyytiId__c+'/participants'+ '?limit=' + String.valueOf(this.limitSize) + '&offset=' + String.valueOf(this.offsetSize) );
        //req.setBody(setJsonBody());
        return req;
    }

    public override String setJsonBody(){
        return '';       
    }

    public override void processResponse(HttpResponse response) {
        this.pageItemCount = 0;

        if (response.getStatusCode() != 200) {
            System.debug('Unexpected status: ' + response.getStatusCode() + ' ' + response.getStatus());
            return;
        }
        if (this.remainingEmails == null || this.remainingEmails.isEmpty()) {
            return;
        }

        JSONParser p = JSON.createParser(response.getBody());

        String currentField;
        Boolean inResultsObject = false;
        Boolean inParticipantObj = false;

        String email;
        String uid;

        while (p.nextToken() != null) {
            JSONToken t = p.getCurrentToken();

            // capter les noms de champs
            if (t == JSONToken.FIELD_NAME) {
                currentField = p.getText();
                continue;
            }

            // 1) Entrer dans "results": { ... }
            if (!inResultsObject) {
                if (currentField == 'results' && t == JSONToken.START_OBJECT) {
                    inResultsObject = true;
                }
                continue;
            }

            // 2) Dans results, chaque entrée est:  "123": { participant... }
            // Le FIELD_NAME "123" est lu plus haut, ici on attend START_OBJECT = participant object
            if (t == JSONToken.START_OBJECT && !inParticipantObj) {
                inParticipantObj = true;
                email = null;
                uid = null;
                continue;
            }

            // 3) Fin d'un participant
            if (t == JSONToken.END_OBJECT && inParticipantObj) {
                this.pageItemCount++;

                if (email != null && uid != null && this.remainingEmails.contains(email)) {
                    this.idEmailMap.put(email, uid);
                    this.remainingEmails.remove(email);

                    if (this.remainingEmails.isEmpty()) {
                        break; // trouvé tout ce qu'on cherche
                    }
                }

                inParticipantObj = false;
                continue;
            }

            // 4) Fin de l'objet results (quand on n'est pas dans un participant)
            if (t == JSONToken.END_OBJECT && inResultsObject && !inParticipantObj) {
                break;
            }

            // 5) Lire les champs du participant
            if (inParticipantObj) {
                if (currentField == 'email') {
                    if (t == JSONToken.VALUE_STRING) {
                        email = p.getText();
                        if (email != null) email = email.trim().toLowerCase();
                    } else if (t == JSONToken.VALUE_NULL) {
                        email = null; // explicite
                    }
                } else if (currentField == 'uid' && t == JSONToken.VALUE_STRING) {
                    uid = p.getText();
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