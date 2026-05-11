public class WS_LyytiGetParticipantTypes extends RestCallout {

    public Long timestamp;
    public Campaign recordToTreat;
    public String publicKey;
    public String privateKey;

    public Map<String, String> participantTypeNameById = new Map<String, String>();

    private String currentField;
    private Boolean inResultsObject = false;
    private Boolean inTypeObj = false;
    private String currentTypeId;
    private String currentTypeName;

    public WS_GetParticipantTypes(Campaign recordToTreat) {
        this.recordToTreat = recordToTreat;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey  = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
    }

    public override String getMethod() {
        return 'GET';
    }

    public String getSignature() {
        String callString = 'participant_types/' + recordToTreat.LyytiId__c;

        String msg = String.join(new List<String>{
            this.publicKey,
            String.valueOf(this.timestamp),
            callString
        }, ',');

        String msgBase64 = EncodingUtil.base64Encode(Blob.valueOf(msg));
        Blob hmac = Crypto.generateMac(
            'hmacSHA256',
            Blob.valueOf(msgBase64),
            Blob.valueOf(this.privateKey)
        );

        return EncodingUtil.convertToHex(hmac);
    }

    public HttpRequest setHeaderAndEndpoint() {
        this.timestamp = System.now().getTime() / 1000;

        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', 'application/json; charset=utf-8');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader(
            'Authorization',
            'LYYTI-API-V2 public_key=' + this.publicKey +
            ', timestamp=' + this.timestamp +
            ', signature=' + getSignature()
        );

        req.setEndpoint(
            LyytiCredentials__mdt.getInstance('Authentication').URL__c +
            '/participant_types/' + recordToTreat.LyytiId__c
        );

        return req;
    }

    public override String setJsonBody() {
        return '';
    }

    public override void processResponse(HttpResponse response) {
        participantTypeNameById.clear();

        if (response.getStatusCode() != 200) {
            System.debug('WS_GetParticipantTypes status: ' + response.getStatusCode() + ' ' + response.getStatus());
            return;
        }

        JSONParser p = JSON.createParser(response.getBody());

        while (p.nextToken() != null) {
            JSONToken t = p.getCurrentToken();

            if (t == JSONToken.FIELD_NAME) {
                currentField = p.getText();
                continue;
            }

            if (!inResultsObject && currentField == 'results' && t == JSONToken.START_OBJECT) {
                inResultsObject = true;
                continue;
            }

            if (inResultsObject && !inTypeObj && t == JSONToken.START_OBJECT) {
                inTypeObj = true;
                currentTypeId = null;
                currentTypeName = null;
                continue;
            }

            if (inTypeObj && currentField == 'id' && t == JSONToken.VALUE_STRING) {
                currentTypeId = p.getText();
                continue;
            }

            if (inTypeObj && currentField == 'name' && t == JSONToken.VALUE_STRING) {
                currentTypeName = p.getText();
                continue;
            }

            if (inTypeObj && t == JSONToken.END_OBJECT) {
                if (String.isNotBlank(currentTypeId) && String.isNotBlank(currentTypeName)) {
                    participantTypeNameById.put(currentTypeId, currentTypeName);
                }
                inTypeObj = false;
                continue;
            }

            if (inResultsObject && !inTypeObj && t == JSONToken.END_OBJECT) {
                break;
            }
        }
    }

    public void sendInDataToExternalService() {
        try {
            callEndPoint(setHeaderAndEndpoint());
        } catch (Exception e) {
            System.debug('WS_GetParticipantTypes callout error: ' + e.getMessage());
        }
    }
}