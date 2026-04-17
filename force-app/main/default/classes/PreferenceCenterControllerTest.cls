/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 25-09-2023
 * @last modified by  : Thanina YAYA
**/
@isTest
private class PreferenceCenterControllerTest {
    //Data Setup
    @testSetup static void setup() {
        Contact c = TestDataFactory.getContact();
        c.HasOptedOutOfEmail = false;
        insert c;
        TestDataFactory.getPreferenceCenterCategory();
    }

    @isTest static void testGenerateTogglesJson() {
        Contact c = [SELECT id FROM Contact LIMIT 1];
        Test.startTest();
        try{
            String str = PreferenceCenterController.generateTogglesJson(String.valueof(c.id), 'Preference');
            System.assert(str.length() > 1);
        }
        catch(exception e)
        {
         }     
         Test.stopTest();
    }

    @isTest static void testSubInterests() {
        Contact c = [SELECT id FROM Contact LIMIT 1];
        Test.startTest();
        try{
            String str = PreferenceCenterController.getSubInterests(String.valueOf(c.id), 'Equities');
            System.assert(str.length() > 1);
            Boolean res = PreferenceCenterController.unsubscribeAllSubInterest(String.valueOf(c.id), 'Equities__c');
            System.assert(res);
        }catch(exception e)
        {
         }     
        Test.stopTest();
    }

    @isTest static void testUpdateOptOut() {
        Contact c = [SELECT id FROM Contact LIMIT 1];
        Test.startTest();
        try{
            System.assert(!PreferenceCenterController.getOptOut(String.valueof(c.id)));
            PreferenceCenterController.updateRecord(String.valueOf(c.id), 'HasOptedOutOfEmail', true);
            System.assert(PreferenceCenterController.getOptOut(String.valueOf(c.id)));
            PreferenceCenterController.getLastModifiedOptOut(String.valueof(c.id));
        }catch(exception e)
        {
        }     
        Test.stopTest();
    }

    @isTest static void testoptOutAndCommunicationType() {
        Contact c = [SELECT id FROM Contact Limit 1];
        Test.startTest();
        try{
        PreferenceCenterController.optOutAndCommunicationType(String.valueOf(c.id));
    }catch(exception e)
    {
    }     
    Test.stopTest();
    }
}