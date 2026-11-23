@IsTest
private class DecisionMakerPDFControllerTest {

    /**
     * Creates an Account and Contact used by the controller tests.
     */
    @TestSetup
    static void setupData() {
        Account account = new Account(
            Name = 'Decision Maker Test Account'
        );
        insert account;

        Map<String, String> influenceMap =
            DecisionMakerPDFController.returnSelectOptionsMap(
                new Contact(),
                'Level_of_Influence__c'
            );
        Map<String, String> supportMap =
            DecisionMakerPDFController.returnSelectOptionsMap(
                new Contact(),
                'Level_of_Support__c'
            );

        insert new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = account.Id,
            Level_of_Influence__c = influenceMap.values()[0],
            Level_of_Support__c = supportMap.values()[0]
        );
    }

    /**
     * Verifies controller initialization for the standard Account view.
     */
    @IsTest
    static void testController() {
        Account account = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Decision Maker Test Account'
            LIMIT 1
        ];

        Test.setCurrentPage(new PageReference('/apex/DecisionMakerPDF'));
        ApexPages.currentPage().getParameters().put('id', account.Id);
        ApexPages.currentPage().getParameters().put('viewFull', 'false');

        Test.startTest();

        DecisionMakerPDFController controller =
            new DecisionMakerPDFController();

        Test.stopTest();

        System.assertEquals(account.Name, controller.getAccountName());
        System.assertEquals('false', controller.getViewFull());
        System.assertNotEquals(null, controller.getMyDomainName());
        System.assertNotEquals(null, controller.getMatrixTable());
    }

    /**
     * Verifies Account-specific Contact retrieval.
     */
    @IsTest
    static void testReturnContacts() {
        Account account = [
            SELECT Id
            FROM Account
            WHERE Name = 'Decision Maker Test Account'
            LIMIT 1
        ];

        Test.startTest();

        List<Contact> contacts =
            DecisionMakerPDFController.returnContacts(account.Id);

        Test.stopTest();

        System.assertEquals(1, contacts.size());
        System.assertEquals('John', contacts[0].FirstName);
        System.assertEquals('Doe', contacts[0].LastName);
    }

    /**
     * Verifies Contact retrieval across a supplied Account hierarchy.
     */
    @IsTest
    static void testReturnAllContacts() {
        Account account = [
            SELECT Id
            FROM Account
            WHERE Name = 'Decision Maker Test Account'
            LIMIT 1
        ];

        Test.startTest();

        List<Contact> contacts =
            DecisionMakerPDFController.returnAllContacts(
                new List<Account>{ account }
            );

        Test.stopTest();

        System.assertEquals(1, contacts.size());
    }

    /**
     * Verifies Contact matrix construction and picklist mapping.
     */
    @IsTest
    static void testContactTableMap() {
        Contact contact = [
            SELECT Id, FirstName, LastName,
                   Level_of_Influence__c, Level_of_Support__c
            FROM Contact
            WHERE LastName = 'Doe'
            LIMIT 1
        ];

        Map<String, String> influenceMap =
            DecisionMakerPDFController.returnSelectOptionsMap(
                new Contact(),
                'Level_of_Influence__c'
            );
        Map<String, String> supportMap =
            DecisionMakerPDFController.returnSelectOptionsMap(
                new Contact(),
                'Level_of_Support__c'
            );

        Test.startTest();

        Map<String, String> contactTableMap =
            DecisionMakerPDFController.returnContactTableMap(
                influenceMap,
                supportMap,
                new List<Contact>{ contact }
            );

        Test.stopTest();

        String influenceKey =
            DecisionMakerPDFController.getKeyFromValue(
                influenceMap,
                contact.Level_of_Influence__c
            );
        String supportKey =
            DecisionMakerPDFController.getKeyFromValue(
                supportMap,
                contact.Level_of_Support__c
            );

        String contactKey = 'ct' + supportKey + influenceKey;

        System.assert(contactTableMap.containsKey(contactKey));
        System.assert(contactTableMap.get(contactKey).contains('John Doe'));
    }

    /**
     * Verifies the Account name returned for the generated PDF filename.
     */
    @IsTest
    static void testDecisionMakerFileName() {
        Account account = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Decision Maker Test Account'
            LIMIT 1
        ];

        Test.startTest();

        String fileName =
            DecisionMakerPDFController.decisionMakerFileName(account.Id);

        Test.stopTest();

        System.assertEquals(account.Name, fileName);
    }

    /**
     * Verifies lookup of a matrix key from its picklist value.
     */
    @IsTest
    static void testGetKeyFromValue() {
        Map<String, String> values = new Map<String, String>{
            '1' => 'Low',
            '2' => 'High'
        };

        System.assertEquals(
            '2',
            DecisionMakerPDFController.getKeyFromValue(values, 'High')
        );
        System.assertEquals(
            null,
            DecisionMakerPDFController.getKeyFromValue(values, 'Unknown')
        );
    }
}