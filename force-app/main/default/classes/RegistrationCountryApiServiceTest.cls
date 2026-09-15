@IsTest
private class RegistrationCountryApiServiceTest {
    // Simule l'authentification puis la réponse de CARMIGNAC_CATALOG.
    private class SequantisCalloutMock implements HttpCalloutMock {
        // Retourne une réponse différente selon l'endpoint appelé.
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();

            // Retourne le token technique utilisé par l'appel métier.
            if (request.getEndpoint().contains('/rest/authentication/')) {
                response.setStatusCode(200);
                response.setBody('1618075391563505891');
                return response;
            }

            // Vérifie le payload réellement envoyé à Sequantis.
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(request.getBody());

            System.assertEquals('TEST_ISIN', payload.get('isin'));
            System.assertEquals('Registration', payload.get('type'));
            System.assertEquals('France', payload.get('countryRegNeededRetail'));
            System.assertEquals('', payload.get('countryRegNeededInstit'));
            System.assertEquals('', payload.get('countryRegNeededSemPro'));

            response.setStatusCode(202);
            response.setBody('Registration');
            return response;
        }
    }

    // Vérifie l'authentification, le payload et la réponse HTTP 202.
    @IsTest
    static void sendRegistrationRequestSuccessfully() {
        String activeCountryValue = findCountryValueByLabel('France');

        RegistrationCountryApiService.Request request =
            new RegistrationCountryApiService.Request();
        request.shareClassId = buildUnknownShareClassId();
        request.shareClassName = 'Test Share Class';
        request.isin = 'TEST_ISIN';

        // Prépare une sélection Retail uniquement.
        request.countriesByType = new Map<String, List<String>>{
            'Retail' => new List<String>{ activeCountryValue },
            'Institutional' => new List<String>(),
            'Semi-Pro' => new List<String>()
        };
        request.comment = 'Test comment';

        Test.setMock(
            HttpCalloutMock.class,
            new SequantisCalloutMock()
        );

        Test.startTest();
        RegistrationCountryApiService.Response response =
            RegistrationCountryApiService.sendRequest(request);
        Test.stopTest();

        // Vérifie le résultat retourné au contrôleur.
        System.assertEquals(true, response.configured);
        System.assertEquals(202, response.statusCode);
        System.assertNotEquals(null, response.requestPayload);
    }

    // Construit un identifiant Share Class valide sans insertion.
    private static Id buildUnknownShareClassId() {
        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get('Share_Class__c');
        String keyPrefix = objectType.getDescribe().getKeyPrefix();

        return (Id) (keyPrefix + '000000000000');
    }

    // Retrouve la valeur technique correspondant au label demandé.
    private static String findCountryValueByLabel(String countryLabel) {
        Schema.DescribeFieldResult fieldDescribe =
            Schema.SObjectType.Country__c.fields.Country__c;

        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (
                entry.isActive() &&
                entry.getLabel() == countryLabel
            ) {
                return entry.getValue();
            }
        }

        System.assert(
            false,
            'Country__c.Country__c must contain the active label ' +
            countryLabel + '.'
        );
        return null;
    }
}