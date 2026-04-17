/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 19-06-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
public class CaseTranslationProcessTest {

    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();

    @TestSetup
    static void testSetup() {
        Product__c p = TestDataFactory.getProduct(fundRecordTypeId,'Test product','Test product', true);
        insert p;
        Share_Class__c shareCls = new Share_Class__c(Name='Test ShareCls', Fund__c= p.Id, Validity__c=true);
        insert shareCls;
    }
    
    @isTest
    static void getTargetWebsiteOptions_Test() {
        List<String> languages = new List<String>{'English'};
        Test.startTest();
        List<String> websites = CaseTranslationProcess.getTargetWebsiteOptions(languages);
        Test.stopTest();
        System.assertNotEquals(0, websites.size());
    }

    @isTest
    static void getWebsiteSubTypeAndPriority_Test() {
        Test.startTest();
        List<WebsiteSubTypeAndPriority__mdt> mdts = CaseTranslationProcess.getWebsiteSubTypeAndPriority();
        Test.stopTest();
        System.assertNotEquals(0, mdts.size());
    }

    @isTest
    static void getPriorityAndDueDateDelay_Test() {
        Test.startTest();
        List<PriorityAndDueDate__mdt> mdts = CaseTranslationProcess.getPriorityAndDueDateDelay();
        Test.stopTest();
        System.assertNotEquals(0, mdts.size());
    }
    
    @isTest
    static void getProducts_Test() {
        Test.startTest();
        List<Product__c> products = CaseTranslationProcess.getProducts();
        Test.stopTest();
        System.assertNotEquals(0, products.size());
    }

    @isTest
    static void getShareClassesByFunds_Test() {
        Product__c product = [SELECT Id FROM Product__c LIMIT 1];
        Test.startTest();
        List<Share_Class__c> shareCls = CaseTranslationProcess.getShareClassesByFunds(new List<String>{product.Id});
        Test.stopTest();
        System.assertNotEquals(0, shareCls.size());
    }
}