@isTest
private class UtilitiesAccountTest {
    @isTest
    static void testAccount() {
        system.assertNotEquals(null, UtilitiesAccount.InactiveContactsAccount);
    }
    
    @isTest
    static void testRecordTypeIdDevName() {
        system.assertNotEquals(null, UtilitiesAccount.RecordTypeIdsByDevName);
    }
    
    @isTest
    static void testRecordTypeInfosDevName() {
        system.assertNotEquals(null, UtilitiesAccount.RecordTypeInfosByDevName);
    }
}