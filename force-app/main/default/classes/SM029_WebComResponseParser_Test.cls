@IsTest
public class SM029_WebComResponseParser_Test {

    // Helpers de création de données liées aux FORMULES
    private static Contact makeContactWithWebsiteId(String websiteTechId) {
        Contact c = new Contact(LastName = 'Tst', TECH_WebSiteID__c = websiteTechId);
        insert c;
        return c;
    }
   
    private static Share_Class__c makeShareClassWithIsin(String isin) {
        Product__c prd = new Product__c();
            prd.RecordTypeId = Product__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            prd.Name = 'Prod123';
            prd.Product_Name__c = 'Product Test';
            prd.Validity__c = true;
            prd.DefaultLanguage__c = 'FR';
            insert prd;
        
        Share_Class__c sc = new Share_Class__c(Name = 'SC', ISIN__c = isin,Fund__c = prd.Id);
        insert sc;
        return sc;
    }

    // Fabrique un Web_Communication__c en RENSEIGNANT les LOOKUPS dont dépendent les formules
    private static Web_Communication__c makeWebComWithContactAndShareClass(
        Id contactId, Id shareClassId, String websiteId /*AlertType__c*/
    ) {
        Web_Communication__c w = new Web_Communication__c();
        if (contactId != null)    w.Contact__c    = contactId;     // => alimentera TECH_WebsiteLeadContactTechId__c via formule
        if (shareClassId != null) w.ShareClass__c = shareClassId;  // => alimentera TECH_WebISINCode__c via formule
        w.AlertType__c            = websiteId;     // NON formule → éditable
        w.Synchro_Status__c       = 'To be synced';
        return w;
    }

    @IsTest
    static void test_parse_success_and_error_numeric_with_formulas() {
        // 1) Données liées aux formules
        // Succès : ReferenceId "126802_10000_FR0012345678"
        Contact c1 = makeContactWithWebsiteId('126802');
        Share_Class__c sc1 = makeShareClassWithIsin('FR0012345678');
        Web_Communication__c toUpdateSuccess =
            makeWebComWithContactAndShareClass(c1.Id, sc1.Id, '10000');

        // Erreur : ContactId=55555, AlertType=152, ISIN=FR00ERRISIN
        Contact c2 = makeContactWithWebsiteId('55555');
        Share_Class__c sc2 = makeShareClassWithIsin('FR00ERRISIN');
        Web_Communication__c toUpdateError =
            makeWebComWithContactAndShareClass(c2.Id, sc2.Id, '152');

        insert new List<Web_Communication__c>{ toUpdateSuccess, toUpdateError };

        // 2) JSON de réponse (success + error)
        String jsonBody =
        '{' +
        '  "successRecords":[{"SalesForceId":null,"ReferenceId":"126802_10000_FR0012345678"}],' +
        '  "errorRecords":[{"message":"Already exists","data":{"ContactId":"55555","ShareIsin":"FR00ERRISIN","AlertType":"152","IsActive":true}}]' +
        '}';

        Test.startTest();
        SM029_WebCommunicationResponseParser.parse(jsonBody);
        Test.stopTest();

        // 3) Asserts
        Web_Communication__c afterSuccess = [
            SELECT Id, Synchro_Status__c, Website_Response__c, TECH_CommunicationWebsiteId__c,
                   TECH_WebsiteLeadContactTechId__c, TECH_WebISINCode__c, AlertType__c
            FROM Web_Communication__c
            WHERE Id = :toUpdateSuccess.Id
        ];
        System.assertEquals('Success', afterSuccess.Synchro_Status__c);
        System.assertEquals('126802_10000_FR0012345678', afterSuccess.TECH_CommunicationWebsiteId__c);
        System.assertEquals('126802',    afterSuccess.TECH_WebsiteLeadContactTechId__c, 'Formule contact → ok');
        System.assertEquals('FR0012345678', afterSuccess.TECH_WebISINCode__c, 'Formule ISIN → ok');
        System.assertNotEquals(null, afterSuccess.Website_Response__c);
        System.assert(afterSuccess.Website_Response__c.contains('"successRecords"'));

        Web_Communication__c afterError = [
            SELECT Id, Synchro_Status__c, Website_Response__c,
                   TECH_WebsiteLeadContactTechId__c, TECH_WebISINCode__c, AlertType__c
            FROM Web_Communication__c
            WHERE Id = :toUpdateError.Id
        ];
        System.assertEquals('Failed', afterError.Synchro_Status__c);
        System.assertEquals('Already exists', afterError.Website_Response__c);
        System.assertEquals('55555',       afterError.TECH_WebsiteLeadContactTechId__c);
        System.assertEquals('FR00ERRISIN', afterError.TECH_WebISINCode__c);
    }

    @IsTest
    static void test_parse_empty_payload_no_updates_formulas() {
        // Enregistrement qui ne doit pas bouger
        Contact c = makeContactWithWebsiteId('99999');
        Share_Class__c sc = makeShareClassWithIsin('FR00NOMATCH');
        Web_Communication__c untouched =
            makeWebComWithContactAndShareClass(c.Id, sc.Id, '777');
        insert untouched;

        String jsonBody = '{ "successRecords":[], "errorRecords":[] }';

        Test.startTest();
        SM029_WebCommunicationResponseParser.parse(jsonBody);
        Test.stopTest();

        Web_Communication__c check = [
            SELECT Synchro_Status__c, Website_Response__c, TECH_CommunicationWebsiteId__c
            FROM Web_Communication__c WHERE Id = :untouched.Id
        ];
        System.assertEquals('To be synced', check.Synchro_Status__c);
        System.assertEquals(null,      check.Website_Response__c);
        System.assertEquals(null,      check.TECH_CommunicationWebsiteId__c);
    }
}