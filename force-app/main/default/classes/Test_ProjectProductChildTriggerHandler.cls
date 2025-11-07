@isTest
private class Test_ProjectProductChildTriggerHandler {
    @isTest(SeeAllData=true)
    static void test_beforeInsert_and_afterInsert() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        Id rtFundShareClassModification = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');

        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id, Status__c = 'Active');
        insert share;
      
        ProjectProduct__c proj = new ProjectProduct__c(
              Name = 'Test Project Full',
              RecordTypeId = rtFundShareClassModification,
              VehicleType__c = 'Funds',
              ProjectStartDate__c = Date.today() - 20,
              EndDate__c = Date.today(),
              RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
              InvestmentObjective__c = 'Sample Objective',
              InvestmentStrategy__c = 'Sample Strategy',
              DomiciledIn__c = 'FR',
              ProjectStatus__c = 'Closed',
              Product_Name__c = 'toto',
              Product__c = product.Id,
            TECH_FieldsToModify__c = 'InternalShortName__c'
          );
      insert proj;
  
      Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
      milestone.Status__c = 'Completed';
      update milestone;

      Test.startTest();
      ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode');
      ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];

      ShareclassNavigatorController.createAndLinkShareclass(child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False');
      child.InternalShortName__c = 'azfazefa';
      child.Status__c = 'Completed';

      child.TECH_TeamValidation__c = 'ProductStrategy';
      update child;

      Test.stopTest();
    }

}