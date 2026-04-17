@isTest
public class ProductTriggerTest {
	static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  

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
    
    @isTest
    static void auditHistory_Test() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        
        insert s0;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        Product__c p1 = new Product__c(Name='P1', FundStrategy__c=s0.Id, Product_Name__c='Product One', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true);
        Product__c p2 = new Product__c(Name='P2', FundStrategy__c=s0.Id, Product_Name__c='Product Inactif', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=false);
        
        insert p0;
        insert p1;
        insert p2;
        
        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Validity__c=true);
        Share_Class__c sc1 = new Share_Class__c(Name='ShareClass1 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P1', Fund__c=p1.Id, Validity__c=false);
        
        insert sc0;
        insert sc1;
        Test.startTest();
        p0.LegalForm__c = 'FCP';
        p1.LegalForm__c = 'SICAV';
        p2.LegalForm__c = 'SICAV';
        
        update p0;
        update p1;
        update p2;
        
        sc0.Name__c = 'old Name';
        update sc0;
        sc0.Name__c = 'new Name';
        update sc0;
        Test.stopTest();
        List<Fund_Field_ApplicabilityHistory__c> logsAllFields = [SELECT Id,Applicability__c FROM Fund_Field_ApplicabilityHistory__c WHERE Applicability__c = false];
        List<Fund_Field_ApplicabilityHistory__c> logsApplicability = [SELECT Id,Applicability__c FROM Fund_Field_ApplicabilityHistory__c WHERE Applicability__c = true];
        
        System.assertNotEquals(0, logsAllFields.size());
        System.assertNotEquals(0, logsApplicability.size());
    }
}