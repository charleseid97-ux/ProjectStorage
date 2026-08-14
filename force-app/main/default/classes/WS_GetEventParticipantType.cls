/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public  class WS_GetEventParticipantType extends RestCallout{

    public Long timestamp;
    public Campaign recordToTreat;
    public Integer participant_type; 
    public String publicKey;
    public String privateKey;

    public WS_GetEventParticipantType(Campaign recordToTreat) {
        this.recordToTreat = recordToTreat;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
    }

    public override String getMethod(){
        return 'GET';
    }

    public HttpRequest setHeaderAndEndpoint(){
        String callString = 'participant_types/' + recordToTreat.LyytiId__c;

        HttpRequest req = new HttpRequest();

        req.setHeader( 'Accept', 'application/json; charset=utf-8' );
        req.setHeader( 'Content-Type', 'application/json' );
        req.setHeader( 'Authorization', LyytiSignatureUtil.buildAuthorizationHeader(this.publicKey, this.privateKey, this.timestamp, callString) );
        req.setEndpoint(LyytiCredentials__mdt.getInstance('Authentication').URL__c+'/participant_types/' + recordToTreat.LyytiId__c);
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

            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonReceived);
            Map<String, Object> results = (Map<String, Object>) responseMap.get('results');

            for (String key : results.keySet()) {
                Map<String, Object> item = (Map<String, Object>) results.get(key);
                Map<String, Object> description = (Map<String, Object>) item.get('description');
                
                if (description != null) {
                    for (String langCode : description.keySet()) {
                        String langDescription = (String) description.get(langCode);
                        if (langDescription == 'Invited') {
                            this.participant_type = Integer.valueOf(item.get('id'));
                            system.debug('id : '+this.participant_type);
                            break;
                        }
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