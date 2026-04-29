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
        
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c p0 = new Product__c(
            Name = 'P0',
            FundStrategy__c = s0.Id,
            Product_Name__c = 'Product Zero',
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRecordTypeId,
            Validity__c = true,
            LegalForm__c = 'SICAV',
            VehicleType__c = 'Funds'
        );
        insert p0;
        
        Product__c p1 = new Product__c(
            Name = 'P0',
            FundStrategy__c = s0.Id,
            Product_Name__c = 'Product Zero',
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRecordTypeId,
            Validity__c = true,
            LegalForm__c = 'OEIC',
            VehicleType__c = 'Funds'
        );
        insert p1;
        
        Share_Class__c sc0 = new Share_Class__c(
            Name = 'ShareClass0 A USD',
            Currency__c = 'USD',
            Country__c = 'AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL',
            Type__c = 'A',
            Fund_Code__c = 'P0',
            Fund__c = p0.Id,
            Validity__c = true
        );
        insert sc0;
        
        Share_Class__c sc1 = new Share_Class__c(
            Name = 'ShareClass0 A USD',
            Currency__c = 'USD',
            Country__c = 'AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL',
            Type__c = 'A',
            Fund_Code__c = 'P0',
            Fund__c = p1.Id,
            Validity__c = true
        );
        insert sc1;
        
        Test.startTest();
        
        // 1. Accumulating
        sc0.DividendPolicy__c = 'Accumulating';
        sc0.DividendFrequency__c = null;
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        
        Share_Class__c scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Acc', scUpdated.Name__c, 'Accumulating should generate A USD Acc');
        
        // 2. Accumulating + Hdg
        sc0.DividendPolicy__c = 'Accumulating';
        sc0.DividendFrequency__c = null;
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Acc Hdg', scUpdated.Name__c, 'Accumulating hedged should generate A USD Acc Hdg');
        
        // 3. Distributing Monthly
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Monthly';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Mdis', scUpdated.Name__c, 'Monthly distributing should generate A USD Mdis');
        
        // 4. Distributing Quarterly + Hdg
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Quarterly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Qdis Hdg', scUpdated.Name__c, 'Quarterly distributing hedged should generate A USD Qdis Hdg');
        
        // 5. Distributing Semi-Annually
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'SemiAnnually';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Sdis', scUpdated.Name__c, 'Semi-Annually distributing should generate A USD Sdis');
        
        // 6. Distributing Annually
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Annually';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Ydis', scUpdated.Name__c, 'Annually distributing should generate A USD Ydis');
        
        // 9. Income Monthly
        sc0.DividendPolicy__c = 'Income';
        sc0.DividendFrequency__c = 'Monthly';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Minc', scUpdated.Name__c, 'Monthly income should generate A USD Minc');
        
        // 10. Income Quarterly + Hdg
        sc0.DividendPolicy__c = 'Income';
        sc0.DividendFrequency__c = 'Quarterly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Qinc Hdg', scUpdated.Name__c, 'Quarterly income hedged should generate A USD Qinc Hdg');
        
        // 11. Income Semi-Annually
        sc0.DividendPolicy__c = 'Income';
        sc0.DividendFrequency__c = 'SemiAnnually';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD Sinc', scUpdated.Name__c, 'Semi-Annually income should generate A USD Sinc');
        
        // 12. Income Annually
        sc1.DividendPolicy__c = 'Income';
        sc1.DividendFrequency__c = 'Annually';
        sc1.CurrencyHedging__c = 'False';
        update sc1;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc1.Id
        ];
        System.assertEquals('A USD Inc', scUpdated.Name__c, 'Annually income should generate A USD Inc');
        
        // 15. Income without frequency
        sc0.DividendPolicy__c = 'Income';
        sc0.DividendFrequency__c = null;
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('A USD inc Hdg', scUpdated.Name__c, 'Income without frequency should generate A USD inc Hdg');
        
        // 16. MyInvestor special case
        sc0.Type__c = 'MyInvestor';
        sc0.DividendPolicy__c = 'Accumulating';
        sc0.DividendFrequency__c = 'Monthly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        
        scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];
        System.assertEquals('MyInvestor', scUpdated.Name__c, 'MyInvestor should ignore currency, dividend policy, frequency and hedging');
        
        Test.stopTest();
    }
    
    @isTest
    static void test_closeTaxDataOnShareClassClosure() {
        Strategy__c strategy = new Strategy__c(
            Name = 'S Close',
            AssetClass__c = 'Equity',
            SubAssetClass__c = 'Global',
            Code__c = 'SCLOSE'
        );
        insert strategy;
        
        Product__c fund = new Product__c(
            Name = 'FundCloseTax',
            FundStrategy__c = strategy.Id,
            Product_Name__c = 'Fund Close Tax',
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRecordTypeId,
            Validity__c = true,
            LegalForm__c = 'SICAV',
            VehicleType__c = 'Funds'
        );
        insert fund;
        
        Share_Class__c shareClass = new Share_Class__c(
            Name = 'Share Class Close Tax',
            Currency__c = 'USD',
            Type__c = 'A',
            Fund__c = fund.Id,
            Validity__c = true,
            Status__c = 'Active',
            ISIN__c = 'LU1234567890'
        );
        insert shareClass;
        
        TaxData__c taxData = new TaxData__c(
            ShareClass__c = shareClass.Id,
            Product__c = fund.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Yes',
            Source__c = 'Manual'
        );
        insert taxData;
        
        Date closeDate = Date.today();
        
        Test.startTest();
        shareClass.Status__c = 'Closed - Merged';
        shareClass.CloseDate__c = closeDate;
        update shareClass;
        Test.stopTest();
        
        TaxData__c updatedTaxData = [
            SELECT Status__c, EndDate__c
            FROM TaxData__c
            WHERE Id = :taxData.Id
        ];
        
        System.assertEquals('No', updatedTaxData.Status__c);
        System.assertEquals(closeDate, updatedTaxData.EndDate__c);
    }
    
    @isTest
    static void test_sendATMergerLiquidationEmails_path() {
        Strategy__c strategy = new Strategy__c(
            Name = 'S Email',
            AssetClass__c = 'Equity',
            SubAssetClass__c = 'Global',
            Code__c = 'SEMAIL'
        );
        insert strategy;
        
        Product__c fund = new Product__c(
            Name = 'FundEmailTax',
            FundStrategy__c = strategy.Id,
            Product_Name__c = 'Fund Email Tax',
            ProductName__c = 'Fund Email Tax',
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRecordTypeId,
            Validity__c = true,
            LegalForm__c = 'SICAV',
            VehicleType__c = 'Funds'
        );
        insert fund;
        
        Share_Class__c shareClass = new Share_Class__c(
            Name = 'Share Class Email Tax',
            Name__c = 'Share Class Email Tax',
            Currency__c = 'USD',
            Type__c = 'A',
            Fund__c = fund.Id,
            Validity__c = true,
            Status__c = 'Active',
            ISIN__c = 'LU1234567890'
        );
        insert shareClass;
        
        insert new TaxData__c(
            ShareClass__c = shareClass.Id,
            Product__c = fund.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Yes',
            Source__c = 'Manual'
        );
        
        Test.startTest();
        shareClass.Status__c = 'Closed - liquidated';
        shareClass.CloseDate__c = Date.today();
        update shareClass;
        Test.stopTest();
        
        Share_Class__c updatedShareClass = [
            SELECT Status__c
            FROM Share_Class__c
            WHERE Id = :shareClass.Id
        ];
        
        System.assertEquals(
            'Closed - liquidated',
            updatedShareClass.Status__c,
            'Le changement de statut doit déclencher le chemin email Merger/Liquidation'
        );
    }
}