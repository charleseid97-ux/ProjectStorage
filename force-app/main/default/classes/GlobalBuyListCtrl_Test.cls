@isTest
public class GlobalBuyListCtrl_Test {
    
    @isTest
    static void testloadGlobalAndLocalBuyList() {
        Test.startTest();
        GlobalBuyListCtrl.loadGlobalAndLocalBuyList('Product_Status__c', 'Company__c', '0015800000l6ttGAAQ', 'Account', 'Ultimate_Parent_Id__c');
        Test.stopTest();
    }
        
    @isTest
    static void testLocalBuyListsCtrlt() {
        Test.startTest();
        GlobalBuyListCtrl.getLocalBuyListsCtrl('a1U1i000000I7xt');
        Test.stopTest();
    }
}