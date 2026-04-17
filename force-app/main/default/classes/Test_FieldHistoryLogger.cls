@isTest
public class Test_FieldHistoryLogger {
    	
    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  

    @isTest
    static void auditHistory_Test() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        
        insert s0;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        Product__c p1 = new Product__c(Name='P1', FundStrategy__c=s0.Id, Product_Name__c='Product One', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true);
        Product__c p2 = new Product__c(Name='P2', FundStrategy__c=s0.Id, Product_Name__c='Product Inactif', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=false);
        
        Test.startTest();
        insert p0;
        insert p1;
        insert p2;
        
        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Validity__c=true);
        Share_Class__c sc1 = new Share_Class__c(Name='ShareClass1 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P1', Fund__c=p1.Id, Validity__c=false);
        
        insert sc0;
        insert sc1;
        
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