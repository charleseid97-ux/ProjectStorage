/** ──────────────────────────────────────
 * @description Tests the linked product check of the wtpProductSelector LWC, before and after a product is linked to the WTP.
 * @author Charles EID
 * @covers WTPProductSelectorController   100%   [25-11-26]
 ────────────────────────────────────── */
@isTest
private class WTPProductSelectorControllerTest {

    @isTest
    static void testHasLinkedProducts() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        Product__c fund = new Product__c(Name = 'TestWTPFund', ProductName__c = 'TestWTPFund', RecordTypeId = fundRecordTypeId, Validity__c = true);
        insert fund;
        Case wtp = new Case(Subject = 'Test WTP');
        insert wtp;

        Test.startTest();

        Boolean hasProductsBefore = WTPProductSelectorController.hasLinkedProducts(wtp.Id);
        insert new Work_Together_Process_Product__c(Work_Together_Process__c = wtp.Id, Product__c = fund.Id);
        Boolean hasProductsAfter = WTPProductSelectorController.hasLinkedProducts(wtp.Id);

        Test.stopTest();

        Assert.isFalse(hasProductsBefore, 'A WTP without linked product should open the product selector');
        Assert.isTrue(hasProductsAfter, 'A WTP with a linked product should not open the product selector');
    }
}