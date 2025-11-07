@isTest
public class UTIL_LegalEntityTest {
    
    @isTest
    static void toUppercaseName() {
        Legal_Entity__c le = TestDataFactory.getLegalEntity();
        insert le;
        List<Legal_Entity__c> listLE = [SELECT id, name FROM Legal_Entity__c];

        UTIL_LegalEntity.toUppercaseName(listLE);
        System.debug(listLE[0].name);
        System.assert(listLE[0].name.isAllUpperCase());
    }

    @isTest
    static void testGetString() {
        for (Integer i = 0; i < 6; i++) {
            UTIL_LegalEntity.getString(i);
        }
    }

    @isTest
    static void testGetRequestStatus() {
        List<String> lettersList = new List<String>{ 'A', 'B', 'C', 'D', 'R', 'P', 'Z' };
        for (String letter : lettersList) {
            UTIL_LegalEntity.getRequestStatus(letter);
        }
    }
}