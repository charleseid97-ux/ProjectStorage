/**
 * Created by Noor Nabee on 4/17/2020.
 */

@IsTest
private class AccountTriggerHandler_TEST {
    @IsTest
    static void testBehavior() {
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        Account testAcc = TestFactory.getSimpleAccount();
        testAcc.Client_Tier__c = 'Titanium (Tier 0)';
        testAcc.BusinessDevelopmentRegion__c = 'BP_FR';
        testAcc.Distributor_Type__c = 'Bank';
        testAcc.Sub_Type__c = 'Retail Banking';
        testAcc.Billingcity='Chicago';
        testAcc.BillingStreet='asd123';
        testAcc.BillingPostalCode='60606';
        testAcc.BillingCountry='United States';
        testAcc.In__c = 'Retail';
        testAcc.Final_Distribution__c = 'Retail';
        insert testAcc;

        Grid__c franceGrid = new Grid__c(Name='France S5');
        insert franceGrid;

        insert(  new Convention__c(Name='tmpName', Grid__c = franceGrid.Id, Company__c = testAcc.Id,
                Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
                RecordTypeId = agmRtMap.get('Request_Agreement') ));

        try{
            delete testAcc;
        }catch (Exception e){
            System.debug(e.getMessage());
        }

    }
}