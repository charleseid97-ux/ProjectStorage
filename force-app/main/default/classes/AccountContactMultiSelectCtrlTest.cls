@IsTest
private class AccountContactMultiSelectCtrlTest {

    // Test getAccountAddress avec accountId null
    @IsTest
    static void testGetAccountAddressWithNullId() {
        Test.startTest();
        Account result = AccountContactMultiSelectCtrl.getAccountAddress(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    // Test getAccountAddress avec un Account
    @IsTest
    static void testGetAccountAddress() {
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '1 Test Street',
            BillingCity = 'Paris',
            BillingPostalCode = '75001',
            BillingCountry = 'France'
        );
        insert acc;

        Test.startTest();
        Account result = AccountContactMultiSelectCtrl.getAccountAddress(acc.Id);
        Test.stopTest();

        System.assertEquals('Test Account', result.Name);
        System.assertEquals('Paris', result.BillingCity);
    }

    // Test getContactsByAccount avec accountId null
    @IsTest
    static void testGetContactsByAccountWithNullId() {
        Test.startTest();
        List<AccountContactMultiSelectCtrl.OptionItem> results =
            AccountContactMultiSelectCtrl.getContactsByAccount(null, 10);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    // Test getContactsByAccount avec contacts
    @IsTest
    static void testGetContactsByAccount() {
        Account acc = new Account(Name = 'Test Account Contacts');
        insert acc;

        insert new List<Contact>{
            new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id),
            new Contact(FirstName = 'Jane', LastName = 'Doe', AccountId = acc.Id)
        };

        Test.startTest();
        List<AccountContactMultiSelectCtrl.OptionItem> results =
            AccountContactMultiSelectCtrl.getContactsByAccount(acc.Id, null);
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertNotEquals(null, results[0].label);
        System.assertNotEquals(null, results[0].value);
    }

    // Test getContactsByAccount avec limite invalide
    @IsTest
    static void testGetContactsByAccountWithInvalidLimit() {
        Account acc = new Account(Name = 'Test Account Limit');
        insert acc;

        Contact con = new Contact(LastName = 'Limit Test', AccountId = acc.Id);
        insert con;

        Test.startTest();
        List<AccountContactMultiSelectCtrl.OptionItem> results =
            AccountContactMultiSelectCtrl.getContactsByAccount(acc.Id, -1);
        Test.stopTest();

        System.assertEquals(1, results.size());
    }
}