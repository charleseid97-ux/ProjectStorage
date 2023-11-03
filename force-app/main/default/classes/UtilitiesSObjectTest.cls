@isTest
public class UtilitiesSObjectTest {
    @isTest
    static void testBehavior() {
        Map<String, SobjectType> res = UtilitiesSObject.GlobalDescribeResult;
        String firstKey = new List<String> (res.keySet()).get(0);
        SObjectType firstValue = res.get(firstKey);
        UtilitiesSObject.getRecordTypeIdsByDeveloperName(firstKey);
        UtilitiesSObject.getRecordTypeNamesByDeveloperName(firstKey);
        UtilitiesSObject.getRecordTypeInfosByDeveloperName(firstKey);
        UtilitiesSobject.getRecordTypeIdByDeveloperName(Contact.sObjectType, 'Contact_DistributionContact');
    }

    @isTest
    static void testInitPreferenceCenterEmpty() {
        List<SObject> sobjectList = new List<SObject>();
        Contact firstContact = TestDataFactory.getContact();
        List<String> categories = MetadataUtils.getPreferenceCenterCategory('Communication Type');
        for (String category : categories) {
            firstContact.put(category, false);
        }
        firstContact.put('HasOptedOutOfEmail', false);
        sobjectList.add((SObject) firstContact);
        UtilitiesSObject.initPreferenceCenter(sObjectList);
        for (String category : categories) {
            System.assert(firstContact.get(category) == true);
        }
    }

    @isTest
    static void testInitPreferenceCenterNotEmpty() {
        List<SObject> sobjectList = new List<SObject>();
        Contact firstContact = TestDataFactory.getContact();
        List<String> prefCat = MetadataUtils.getPreferenceCenterCategory('Communication Type');
        for (String category : prefCat) {
            firstContact.put(category, false);
        }
        firstContact.put('HasOptedOutOfEmail', false);
        //firstContact.put(prefCat[0], true);
        sObjectList.add((SObject) firstContact);
        //System.assertEquals(firstContact.get(prefCat[0]), true);
        //System.assertEquals(firstContact.get(prefCat[1]), false);
    }

    @isTest
    static void testInitPreferenceCenterOptOut() {
        List<SObject> sobjectList = new List<SObject>();
        Contact firstContact = TestDataFactory.getContact();
        List<String> prefCat = MetadataUtils.getPreferenceCenterCategory('Communication Type');
        firstContact.put('HasOptedOutOfEmail', true);
        for (String category : prefCat) {
            firstContact.put(category, false);
        }
        sObjectList.add((SObject) firstContact);
        //System.assertEquals(firstContact.get(prefCat[0]), false);
    }

    @isTest
    static void testCheckPreferenceCenterFields() {
        List<SObject> sobjectList = new List<SObject>();
        Contact firstContact = TestDataFactory.getContact();
        Contact secondContact = TestDataFactory.getContact();
        Integer counter = 0;
        for (String field : MetadataUtils.getPreferenceCenterCategory('')) {
            firstContact.put(field, true);
            secondContact.put(field, Math.mod(counter++, 2) == 0);
        }
        firstContact.HasOptedOutOfEmail = true;
        secondContact.HasOptedOutOfEmail = false;
        sObjectList.add((SObject) firstContact);
        sObjectList.add((SObject) secondContact);
        Map<Id, SObject> sobjectMap = new Map<Id, SObject>{firstContact.Id => (SObject) secondContact};
        UtilitiesSObject.checkPreferenceCenterFields(sObjectList, sobjectMap);
        for (String field : MetadataUtils.getPreferenceCenterCategory('Communication Type')) {
            //System.assertEquals(firstContact.get(field), false);
        }
    }
}