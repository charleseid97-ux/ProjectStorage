@isTest
public class ProductTriggerTest {

    static testMethod void doTest() {
        Id StrategyRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
        
		Product__c ac0 = new Product__c(Name='Equity', Product_Name__c='Equity', Record_Type_Name__c = 'Asset Class', Asset_Class_Code__c = 'EQTY');
		Product__c ac1 = new Product__c(Name='Alternative', Product_Name__c='Alternative', Record_Type_Name__c = 'Asset Class',Asset_Class_Code__c = 'ALVE');
		Product__c sac = new Product__c(Name='Global', Product_Name__c='Global', Record_Type_Name__c = 'Regional Focus', Sub_Asset_Class_Code__c = 'GLAL');
        
        insert ac0;
        insert ac1;
        insert sac;

		Product__c p0 = new Product__c(Name='PStrategy', Product_Name__c='Product Strategy', Record_Type_Name__c = 'Strategy', Asset_Class_Code__c = 'EQTY', Sub_Asset_Class_Code__c = 'GLAL');
        Product__c p1 = new Product__c(Name='PFund', Product_Name__c='Product Fund', Record_Type_Name__c = 'Fund', Strategy_Code__c = 'PStrategy');
        
        insert p0;
        insert p1;

        Share_Class__c sc = new Share_Class__c(Name='ShareClass', Fund_Code__c='PFund', Fund__c=p1.Id);
        insert sc;
        
        Fund_Manager__c fm = new Fund_Manager__c(Name='Fund Manager', SAM_Code__c='PFund');
        insert fm;
        
        test.startTest();
			Product__c productStrategyTest = [SELECT RecordTypeId from Product__c WHERE Id =: p0.Id];
			Product__c productFundTest = [SELECT RecordTypeId, Strategy__c from Product__c WHERE Id =: p1.Id];
			Share_Class__c scTest = [SELECT Fund__c from Share_Class__c WHERE Id =: sc.Id];
        	
            system.assertEquals(productStrategyTest.RecordTypeId, StrategyRecordTypeId);
            system.assertEquals(productFundTest.Strategy__c, productStrategyTest.Id);
            system.assertEquals(scTest.Fund__c, productFundTest.Id);
        	productStrategyTest.Asset_Class_Code__c = 'ALVE';
        	update productStrategyTest;
        test.stopTest();
    }
}