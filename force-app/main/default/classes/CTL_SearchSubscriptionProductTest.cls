/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 03-18-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
private class CTL_SearchSubscriptionProductTest {
    @TestSetup
    static void makeData(){
        Contact c = TestDataFactory.getContact();
        insert c;
    }

    @isTest static void testBehavior() {
        Contact c = [SELECT id FROM Contact Limit 1];
        CTL_SearchSubscriptionProduct.getShareClasses();
        CTL_SearchSubscriptionProduct.getFundWithShareClasses();
        CTL_SearchSubscriptionProduct.getShareClassesByCountry('AA');
        CTL_SearchSubscriptionProduct.getShareClassesByCountry('');
        CTL_SearchSubscriptionProduct.saveProspaceAlerts(new List<Web_Communication__c>());
        CTL_SearchSubscriptionProduct.getAlertTypes('Publication');
        CTL_SearchSubscriptionProduct.getShareClassesByCountryWithSub('FR', 'Report', c.id, 0);
        CTL_SearchSubscriptionProduct.getFundsWithSub('Report', c.id, 0);
        CTL_SearchSubscriptionProduct.getDistinctValues();

    }
}