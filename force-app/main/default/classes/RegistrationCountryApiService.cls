public without sharing class RegistrationCountryApiService {
    // Définit les chemins relatifs communs à tous les environnements.
    private static final String AUTHENTICATION_PATH = '/rest/authentication/';
    private static final String REGISTRATION_PATH = '/rest/CARMIGNAC_CATALOG';

    // Définit le délai maximal de chaque appel Sequantis.
    private static final Integer CALLOUT_TIMEOUT = 60000;

    // Représente les données internes nécessaires à l'appel Sequantis.
    public class Request {
        public Id shareClassId;
        public String shareClassName;
        public String isin;
        public Map<String, List<String>> countriesByType;
        public String comment;
    }

    // Représente le résultat exploité par le contrôleur.
    public class Response {
        public Boolean configured;
        public Integer statusCode;
        public String externalId;
        public String requestPayload;
    }

    // Représente exactement le body attendu par Sequantis.
    private class SequantisRequest {
        public String isin;
        public String type;
        public String countryRegNeededSemPro;
        public String countryRegNeededInstit;
        public String countryRegNeededRetail;
    }

    // Authentifie l'utilisateur technique puis envoie la demande d'enregistrement.
    public static Response sendRequest(Request request) {
        String token = fetchAccessToken();

        // Convertit les valeurs Salesforce comme GB en libellés complets.
        Map<String, String> countryLabelsByValue = getCountryLabelsByValue();
        SequantisRequest payload = new SequantisRequest();
        payload.isin = request.isin;
        payload.type = 'Registration';
        payload.countryRegNeededSemPro = getCountries(
            request,
            'Semi-Pro',
            countryLabelsByValue
        );
        payload.countryRegNeededInstit = getCountries(
            request,
            'Institutional',
            countryLabelsByValue
        );
        payload.countryRegNeededRetail = getCountries(
            request,
            'Retail',
            countryLabelsByValue
        );

        HttpRequest httpRequest = new HttpRequest();

        // Utilise l'URL configurée dans le Named Credential de l'environnement.
        httpRequest.setEndpoint('callout:Sequantis' + REGISTRATION_PATH);
        httpRequest.setMethod('POST');
        httpRequest.setTimeout(CALLOUT_TIMEOUT);

        // Transmet le token selon le mécanisme utilisé par VFC16.
        httpRequest.setHeader('Authorization', 'Bearer ' + token);
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setBody(JSON.serialize(payload));

        HttpResponse httpResponse = new Http().send(httpRequest);
        Response response = new Response();
        response.configured = true;
        response.statusCode = httpResponse.getStatusCode();

        // Conserve le payload réellement envoyé pour OperationLog.
        response.requestPayload = httpRequest.getBody();
        response.externalId = extractExternalId(httpResponse.getBody());
        return response;
    }

    // Récupère le token avec la même authentification que VFC16.
    private static String fetchAccessToken() {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint('callout:Sequantis' + AUTHENTICATION_PATH);
        httpRequest.setMethod('POST');
        httpRequest.setTimeout(CALLOUT_TIMEOUT);
        httpRequest.setHeader('Content-Type', 'application/json');

        // Les labels existants contiennent les identifiants Sequantis.
        Map<String, String> authenticationPayload = new Map<String, String>{
            'userName' => Label.seqlgn,
            'password' => Label.seqpwd
        };
        httpRequest.setBody(JSON.serialize(authenticationPayload));

        HttpResponse httpResponse = new Http().send(httpRequest);
        Integer statusCode = httpResponse.getStatusCode();

        // Interrompt l'appel métier lorsque l'authentification échoue.
        if (statusCode < 200 || statusCode >= 300) {
            throw new CalloutException(
                'Sequantis authentication failed: HTTP ' + statusCode
            );
        }

        return httpResponse.getBody().trim();
    }

    // Construit la correspondance entre les codes Salesforce et les noms complets.
    private static Map<String, String> getCountryLabelsByValue() {
        Map<String, String> countryLabelsByValue = new Map<String, String>();
        // Récupère directement la description du champ Country__c.
        Schema.DescribeFieldResult fieldDescribe =Schema.SObjectType.Country__c.fields.Country__c;

        // Utilise le libellé métier attendu par Sequantis.
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                countryLabelsByValue.put(entry.getValue(), entry.getLabel());
            }
        }

        return countryLabelsByValue;
    }

    // Retourne les noms complets des pays sous forme de chaîne.
    private static String getCountries(
        Request request,
        String registrationType,
        Map<String, String> countryLabelsByValue
    ) {
        List<String> countryValues =
            request.countriesByType == null
                ? null
                : request.countriesByType.get(registrationType);
        List<String> countryLabels = new List<String>();

        // Retourne une chaîne vide lorsque le type ne contient aucun pays.
        if (countryValues == null || countryValues.isEmpty()) {
            return '';
        }

        for (String countryValue : countryValues) {
            String countryLabel = countryLabelsByValue.get(countryValue);

            // Utilise le libellé complet attendu par Sequantis.
            countryLabels.add(
                String.isBlank(countryLabel)
                    ? countryValue
                    : countryLabel
            );
        }

        return String.join(countryLabels, ', ');
    }

    // Extrait une éventuelle référence sans rendre son format obligatoire.
    private static String extractExternalId(String responseBody) {
        if (String.isBlank(responseBody)) {
            return null;
        }

        try {
            // Recherche les noms de référence généralement retournés par une API.
            Map<String, Object> responseValues =
                (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            Object externalId = responseValues.get('externalId');

            if (externalId == null) {
                externalId = responseValues.get('id');
            }

            return externalId == null ? null : String.valueOf(externalId);
        } catch (Exception exceptionValue) {
            return null;
        }
    }
}