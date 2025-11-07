@isTest
public class ShareclassTriggerTest {
    
    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  

    
    @isTest
    static void updateFormattedNameTypeChange_Test() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        insert s0;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        insert p0;

        
        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', Currency__c='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Validity__c=true);
        insert sc0;
        
        Test.startTest();
        sc0.Type__c = 'X';
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Monthly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        Test.stopTest();
        Share_Class__c scUpdated = [SELECT Id,Name__c FROM Share_Class__c WHERE Id=:sc0.Id];
		System.assertEquals(true, scUpdated.Name__c.contains('X'));
    }

    @isTest
    static void updateFormattedNameDividendP_Test() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        insert s0;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        insert p0;

        
        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', Currency__c='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Validity__c=true);
        insert sc0;
        
        Test.startTest();
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Quarterly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        Test.stopTest();
        Share_Class__c scUpdated = [SELECT Id,Name__c FROM Share_Class__c WHERE Id=:sc0.Id];
		System.assertEquals(true, scUpdated.Name__c.contains('Qdis'));
    }

}