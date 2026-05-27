public class WS_GetEventParticipants extends RestCallout {

    public Long timestamp;
    public Campaign recordToTreat;
    public String publicKey;
    public String privateKey;

    public Map<String, String> idEmailMap;
    public Map<String, String> sourceEmailMap;
    public Map<String, String> participantTypeNameById;

    public Set<String> targetEmails;
    public Integer limitSize;
    public Integer offsetSize;

    public Set<String> remainingEmails;
    public Integer pageItemCount;

    // --- parsing state ---
    private String currentField;
    private Boolean inResultsObject;
    private Boolean inParticipantObj;
    private String currentEmail;
    private String currentUid;
    private String currentParticipantTypeId;

    public WS_GetEventParticipants(
        Campaign recordToTreat,
        Set<String> targetEmails,
        Integer limitSize,
        Integer offsetSize,
        Map<String, String> participantTypeNameById
    ) {
        this.recordToTreat = recordToTreat;
        this.timestamp = System.now().getTime() / 1000;

        this.idEmailMap = new Map<String, String>();
        this.sourceEmailMap = new Map<String, String>();

        this.publicKey  = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;

        this.participantTypeNameById = participantTypeNameById == null
            ? new Map<String, String>()
            : participantTypeNameById;

        this.targetEmails = normalizeEmails(targetEmails);

        this.limitSize  = (limitSize == null || limitSize <= 0) ? 200 : limitSize;
        this.offsetSize = (offsetSize == null || offsetSize < 0) ? 0 : offsetSize;

        this.remainingEmails = new Set<String>();
        this.remainingEmails.addAll(this.targetEmails);

        this.pageItemCount = 0;

        resetParseState();
    }

    // Backward-compatible constructor
    public WS_GetEventParticipants(
        Campaign recordToTreat,
        Set<String> targetEmails,
        Integer limitSize,
        Integer offsetSize
    ) {
        this(
            recordToTreat,
            targetEmails,
            limitSize,
            offsetSize,
            new Map<String, String>()
        );
    }

    public override String getMethod() {
        return 'GET';
    }

    public String getSignature() {
        String callString =
            'events/' + recordToTreat.LyytiId__c + '/participants' +
            '?limit=' + String.valueOf(this.limitSize) +
            '&offset=' + String.valueOf(this.offsetSize);

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
            '/events/' + recordToTreat.LyytiId__c + '/participants' +
            '?limit=' + String.valueOf(this.limitSize) +
            '&offset=' + String.valueOf(this.offsetSize)
        );

        return req;
    }

    public override String setJsonBody() {
        return '';
    }

    public override void processResponse(HttpResponse response) {
        this.pageItemCount = 0;
        resetParseState();

        if (!shouldParse(response)) {
            return;
        }

        JSONParser p = JSON.createParser(response.getBody());

        while (p.nextToken() != null) {
            JSONToken t = p.getCurrentToken();

            if (handleFieldNameToken(p, t)) continue;
            if (handleEnterResults(t)) continue;
            if (handleParticipantStart(t)) continue;

            if (handleEndTokens(t)) break;

            handleParticipantFields(p, t);
        }
    }

    // -----------------
    // Helpers
    // -----------------

    private static Set<String> normalizeEmails(Set<String> emails) {
        Set<String> normalized = new Set<String>();

        if (emails == null) {
            return normalized;
        }

        for (String e : emails) {
            if (String.isBlank(e)) {
                continue;
            }

            normalized.add(e.trim().toLowerCase());
        }

        return normalized;
    }

    private void resetParseState() {
        this.currentField = null;
        this.inResultsObject = false;
        this.inParticipantObj = false;
        this.currentEmail = null;
        this.currentUid = null;
        this.currentParticipantTypeId = null;
    }

    private Boolean shouldParse(HttpResponse response) {
        if (response.getStatusCode() != 200) {
            System.debug(
                'WS_GetEventParticipants: Unexpected status: ' +
                response.getStatusCode() + ' ' + response.getStatus()
            );
            return false;
        }

        return this.remainingEmails != null && !this.remainingEmails.isEmpty();
    }

    private Boolean handleFieldNameToken(JSONParser p, JSONToken t) {
        if (t != JSONToken.FIELD_NAME) {
            return false;
        }

        this.currentField = p.getText();
        return true;
    }

    private Boolean handleEnterResults(JSONToken t) {
        if (this.inResultsObject) {
            return false;
        }

        if (this.currentField == 'results' && t == JSONToken.START_OBJECT) {
            this.inResultsObject = true;
        }

        return true;
    }

    private Boolean handleParticipantStart(JSONToken t) {
        if (!this.inResultsObject || this.inParticipantObj) {
            return false;
        }

        if (t == JSONToken.START_OBJECT) {
            this.inParticipantObj = true;
            this.currentEmail = null;
            this.currentUid = null;
            this.currentParticipantTypeId = null;
            return true;
        }

        return false;
    }

    private Boolean handleEndTokens(JSONToken t) {
        if (this.inParticipantObj && t == JSONToken.END_OBJECT) {
            this.pageItemCount++;
            tryStoreMatch();
            this.inParticipantObj = false;

            if (this.remainingEmails.isEmpty()) {
                return true;
            }

            return false;
        }

        if (this.inResultsObject && !this.inParticipantObj && t == JSONToken.END_OBJECT) {
            return true;
        }

        return false;
    }

    private void handleParticipantFields(JSONParser p, JSONToken t) {
        if (!this.inParticipantObj) {
            return;
        }

        if (this.currentField == 'email') {
            this.currentEmail = readStringValue(p, t);
            if (this.currentEmail != null) {
                this.currentEmail = this.currentEmail.trim().toLowerCase();
            }
            return;
        }

        if (this.currentField == 'uid') {
            this.currentUid = readStringValue(p, t);
            return;
        }

        if (this.currentField == 'participant_type_id') {
            this.currentParticipantTypeId = readStringValue(p, t);
            return;
        }
    }

    private String readStringValue(JSONParser p, JSONToken t) {
        if (t == JSONToken.VALUE_STRING) {
            return p.getText();
        }

        if (t == JSONToken.VALUE_NUMBER_INT) {
            return String.valueOf(p.getLongValue());
        }

        if (t == JSONToken.VALUE_NUMBER_FLOAT) {
            return String.valueOf(p.getDoubleValue());
        }

        if (t == JSONToken.VALUE_NULL) {
            return null;
        }

        return null;
    }

    private void tryStoreMatch() {
        if (this.currentEmail == null || this.currentUid == null) {
            return;
        }

        if (!this.remainingEmails.contains(this.currentEmail)) {
            return;
        }

        this.idEmailMap.put(this.currentEmail, this.currentUid);

        if (
            String.isNotBlank(this.currentParticipantTypeId) &&
            this.participantTypeNameById.containsKey(this.currentParticipantTypeId)
        ) {
            this.sourceEmailMap.put(
                this.currentEmail,
                this.participantTypeNameById.get(this.currentParticipantTypeId)
            );
        }

        this.remainingEmails.remove(this.currentEmail);
    }

    public void sendInDataToExternalService() {
        try {
            callEndPoint(setHeaderAndEndpoint());
        } catch (Exception e) {
            System.debug('WS_GetEventParticipants: callout error: ' + e.getMessage());
        }
    }
}