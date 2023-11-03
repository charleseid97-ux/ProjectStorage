@isTest
private class BATCH025_DataRecoveryProspaceTest {
    //Data Setup
    @testSetup static void setup() {
        List<AlertType__c> alertTypeList = new List<AlertType__c>();
        AlertType__c alertOne = new AlertType__c(
            Name = 'Daily Nav',
            isPublication__c = False,
            TECH_WebSiteID__c = '1'
        );
        alertTypeList.add(alertOne);
        AlertType__c alertTwo = new AlertType__c(
            Name = 'EC Letter',
            isPublication__c = True,
            TECH_WebSiteID__c = '76'
        );
        alertTypeList.add(alertTwo);
        insert alertTypeList;

        List<Web_Communication__c> webComList = new List<Web_Communication__c>();
        Web_Communication__c webOne = new Web_Communication__c(
            AlertType__c = '1',
            isActive__c = true
        );
        webComList.add(webOne);
        Web_Communication__c webTwo = new Web_Communication__c(
            AlertType__c = 'daily_nav',
            isActive__c = true
        );
        webComList.add(webTwo);
        Id alertLetter = [SELECT Id FROM AlertType__c WHERE isPublication__c = True LIMIT 1].Id;
        Web_Communication__c webThree = new Web_Communication__c(
            AlertTypeRecord__c = alertLetter,
            isActive__c = false
        );
        webComList.add(webThree);
        insert webComList;
    }
    
    @isTest
    static void testBatch() {
        BATCH025_DataRecoveryProspace batch = new BATCH025_DataRecoveryProspace();
        String cronExpr = '0 0 0 30 9 ? 2027';

        Test.startTest();
        System.schedule('Prospace Alerts Batch', cronExpr, batch);
        Test.stopTest();
    }
}