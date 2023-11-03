@isTest
private class ProspaceAlertsControllerTest {
    @TestSetup
    static void makeData(){
        Contact c = TestDataFactory.getContact();
        insert c;

        List<Web_Communication__c> prospaceAlerts = new List<Web_Communication__c>();
        for (ProspaceAlertType__mdt alertType : [SELECT WebsiteId__c FROM ProspaceAlertType__mdt WHERE Category__c = :'Publication' LIMIT 1]) {
            Web_Communication__c prospaceAlert = new Web_Communication__c(
                AlertType__c = alertType.WebsiteId__c,
                Contact__c = c.id,
                isActive__c = true
            );
            prospaceAlerts.add(prospaceAlert);
        }

        insert prospaceAlerts;
    }

    @isTest static void testGetTooglesValues() {
        Contact c = [SELECT id FROM Contact WHERE Id != null LIMIT 1];
        String res = ProspaceAlertsController.getTooglesValues((String) c.id);
        System.assert(res.length() > 0);
    }

    @isTest static void testSubscriptionAlertPublication() {
        Contact c = [SELECT id FROM Contact WHERE Id != null LIMIT 1];
        ProspaceAlertType__mdt alertType = [SELECT WebsiteId__c FROM ProspaceAlertType__mdt WHERE Category__c = :'Publication' LIMIT 1];
        System.assert(ProspaceAlertsController.subscriptionAlertPublication(c.id, alertType.websiteId__c, false));
        System.assert(ProspaceAlertsController.subscriptionAlertPublication(c.id, alertType.websiteId__c, true));
    }

    @isTest static void testDesactiveProspaceAlertType() {
        Contact c = [SELECT id FROM Contact WHERE Id != null LIMIT 1];
        ProspaceAlertType__mdt alertType = [SELECT WebsiteId__c FROM ProspaceAlertType__mdt WHERE Category__c = :'Publication' LIMIT 1];
        ProspaceAlertsController.desactiveProspaceAlertType(c.Id, alertType.websiteId__c);
    }
}