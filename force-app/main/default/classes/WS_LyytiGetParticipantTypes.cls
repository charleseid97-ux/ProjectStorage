public class WS_LyytiGetParticipantTypes extends RestCallout {

    public Long timestamp;
    public Campaign recordToTreat;
    public String publicKey;
    public String privateKey;

    public Map<String, String> participantTypeNameById = new Map<String, String>();
    public Boolean success = false;

    public WS_LyytiGetParticipantTypes(Campaign recordToTreat) {
        this.recordToTreat = recordToTreat;
        this.timestamp = System.now().getTime() / 1000;
        this.publicKey  = LyytiCredentials__mdt.getInstance('Authentication').PublicKey__c;
        this.privateKey = LyytiCredentials__mdt.getInstance('Authentication').PrivateKey__c;
    }

    public override String getMethod() {
        return 'GET';
    }

    public HttpRequest setHeaderAndEndpoint() {
        this.timestamp = System.now().getTime() / 1000;

        String callString = 'participant_types/' + recordToTreat.LyytiId__c;

        HttpRequest req = new HttpRequest();

        req.setHeader('Accept', 'application/json; charset=utf-8');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader(
            'Authorization',
            LyytiSignatureUtil.buildAuthorizationHeader(this.publicKey, this.privateKey, this.timestamp, callString)
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
        this.success = response.getStatusCode() == 200;

        if (!this.success) {
            System.debug(
                'WS_LyytiGetParticipantTypes status: ' +
                response.getStatusCode() + ' ' + response.getStatus()
            );
            return;
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        if (body == null || !body.containsKey('results')) {
            return;
        }

        Map<String, Object> results =
            (Map<String, Object>) body.get('results');

        for (String resultKey : results.keySet()) {
            Map<String, Object> typeData =
                (Map<String, Object>) results.get(resultKey);

            String typeId = String.valueOf(typeData.get('id'));
            String typeLabel = getDescriptionLabel(typeData);

            if (String.isNotBlank(typeId) && String.isNotBlank(typeLabel)) {
                participantTypeNameById.put(typeId, typeLabel);
            }
        }

        System.debug('participantTypeNameById = ' + participantTypeNameById);
    }

    private static String getDescriptionLabel(Map<String, Object> typeData) {
        if (typeData == null || !typeData.containsKey('description')) {
            return null;
        }

        Map<String, Object> description =
            (Map<String, Object>) typeData.get('description');

        if (description == null) {
            return null;
        }

        if (description.containsKey('fr') && description.get('fr') != null) {
            return String.valueOf(description.get('fr'));
        }

        if (description.containsKey('en') && description.get('en') != null) {
            return String.valueOf(description.get('en'));
        }

        for (String lang : description.keySet()) {
            if (description.get(lang) != null) {
                return String.valueOf(description.get(lang));
            }
        }

        return null;
    }

    public void sendInDataToExternalService() {
        try {
            callEndPoint(setHeaderAndEndpoint());
        } catch (Exception e) {
            System.debug('WS_LyytiGetParticipantTypes callout error: ' + e.getMessage());
        }
    }
}