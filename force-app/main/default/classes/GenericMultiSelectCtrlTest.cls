@IsTest
public class GenericMultiSelectCtrlTest {

    // Couvre les paramètres obligatoires manquants.
    @IsTest
    static void testGetOptionsMissingParams() {
        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions(null, 'Name', 'Id', 10, null, null, null);
        Test.stopTest();

        System.assertEquals(0, res.size());
    }

    // Couvre objectApiName invalide.
    @IsTest
    static void testGetOptionsInvalidObject() {
        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions('Invalid__c', 'Name', 'Id', 10, null, null, null);
        Test.stopTest();

        System.assertEquals(0, res.size());
    }

    // Couvre field invalide.
    @IsTest
    static void testGetOptionsInvalidField() {
        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions('Account', 'Invalid__c', 'Id', 10, null, null, null);
        Test.stopTest();

        System.assertEquals(0, res.size());
    }

    // Couvre requête sans filtre.
    @IsTest
    static void testGetOptionsWithoutFilter() {
        Account acc = BooklyDataFactory.createAccount();

        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions('Account', 'Name', 'Id', 10, null, null, null);
        Test.stopTest();

        System.assert(res.size() > 0);
        System.assertEquals(String.valueOf(acc.Id), res[0].value);
    }

    // Couvre filtre égal.
    @IsTest
    static void testGetOptionsWithEqualFilter() {
        Account acc = BooklyDataFactory.createAccount();

        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions(
                'Account',
                'Name',
                'Id',
                10,
                'Id',
                '=',
                String.valueOf(acc.Id)
            );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(String.valueOf(acc.Id), res[0].value);
    }

    // Couvre filtre IN.
    @IsTest
    static void testGetOptionsWithInFilter() {
        Account acc = BooklyDataFactory.createAccount();

        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions(
                'Account',
                'Name',
                'Id',
                10,
                'Id',
                'IN',
                String.valueOf(acc.Id)
            );
        Test.stopTest();

        System.assertEquals(1, res.size());
    }

    // Couvre opérateur invalide.
    @IsTest
    static void testGetOptionsInvalidOperator() {
        Account acc = BooklyDataFactory.createAccount();

        Test.startTest();
        List<GenericMultiSelectCtrl.PickOpt> res =
            GenericMultiSelectCtrl.getOptions(
                'Account',
                'Name',
                'Id',
                10,
                'Id',
                'LIKE',
                String.valueOf(acc.Id)
            );
        Test.stopTest();

        System.assertEquals(0, res.size());
    }
}