@isTest
public class ShareclassTriggerTest {

    static final Id fundRecordTypeId =
        Schema.SObjectType.Product__c
            .getRecordTypeInfosByDeveloperName()
            .get('Fund')
            .getRecordTypeId();

    // ✅ Constants Sonar
    private static final String PRODUCT_ZERO = 'Product Zero';
    private static final String SHARE_CLASS_A_USD = 'ShareClass0 A USD';
    private static final String COUNTRIES_ALL =
        'AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL';

    @isTest
    static void updateFormattedNameTypeChange_Test() {

        Strategy__c s0 = new Strategy__c(
            Name = 'S0',
            AssetClass__c = 'Equity',
            SubAssetClass__c = 'Global',
            Code__c = 'S01'
        );
        insert s0;

        Product__c p0 = new Product__c(
            Name = 'P0',
            FundStrategy__c = s0.Id,
            Product_Name__c = PRODUCT_ZERO,
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRecordTypeId,
            Validity__c = true,
            LegalForm__c = 'SICAV',
            VehicleType__c = 'Funds'
        );
        insert p0;

        Share_Class__c sc0 = new Share_Class__c(
            Name = SHARE_CLASS_A_USD,
            Currency__c = 'USD',
            Country__c = COUNTRIES_ALL,
            Type__c = 'A',
            Fund_Code__c = 'P0',
            Fund__c = p0.Id,
            Validity__c = true
        );
        insert sc0;

        Test.startTest();
        sc0.Type__c = 'X';
        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Monthly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        Test.stopTest();

        Share_Class__c scUpdated = [
            SELECT Id, Name__c
            FROM Share_Class__c
            WHERE Id = :sc0.Id
        ];

        System.assertEquals(true, scUpdated.Name__c.contains('X'));
    }

    @isTest
    static void updateFormattedNameDividendP_Test() {

        Strategy__c s0 = new Strategy__c(
            Name = 'S0',
            AssetClass__c = 'Equity',
            SubAssetClass__c = 'Global',
            Code__c = 'S01'
        );
        insert s0;

        Product__c p0 = new Product__c(
            Name = 'P0',
            FundStrategy__c = s0.Id,
            Product_Name__c = PRODUCT_ZERO,
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
            Product_Name__c = PRODUCT_ZERO,
            Record_Type_Name__c = 'Fund',
            RecordTypeId = fundRecordTypeId,
            Validity__c = true,
            LegalForm__c = 'OEIC',
            VehicleType__c = 'Funds'
        );
        insert p1;

        Share_Class__c sc0 = new Share_Class__c(
            Name = SHARE_CLASS_A_USD,
            Currency__c = 'USD',
            Country__c = COUNTRIES_ALL,
            Type__c = 'A',
            Fund_Code__c = 'P0',
            Fund__c = p0.Id,
            Validity__c = true
        );
        insert sc0;

        Share_Class__c sc1 = new Share_Class__c(
            Name = SHARE_CLASS_A_USD,
            Currency__c = 'USD',
            Country__c = COUNTRIES_ALL,
            Type__c = 'A',
            Fund_Code__c = 'P0',
            Fund__c = p1.Id,
            Validity__c = true
        );
        insert sc1;

        Test.startTest();

        sc0.DividendPolicy__c = 'Accumulating';
        update sc0;
        System.assertEquals('A USD Acc',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.CurrencyHedging__c = 'True';
        update sc0;
        System.assertEquals('A USD Acc Hdg',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendPolicy__c = 'Distributing';
        sc0.DividendFrequency__c = 'Monthly';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        System.assertEquals('A USD Mdis',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendFrequency__c = 'Quarterly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        System.assertEquals('A USD Qdis Hdg',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendFrequency__c = 'SemiAnnually';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        System.assertEquals('A USD Sdis',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendFrequency__c = 'Annually';
        update sc0;
        System.assertEquals('A USD Ydis',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendPolicy__c = 'Income';
        sc0.DividendFrequency__c = 'Monthly';
        update sc0;
        System.assertEquals('A USD Minc',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendFrequency__c = 'Quarterly';
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        System.assertEquals('A USD Qinc Hdg',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.DividendFrequency__c = 'SemiAnnually';
        sc0.CurrencyHedging__c = 'False';
        update sc0;
        System.assertEquals('A USD Sinc',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc1.DividendPolicy__c = 'Income';
        sc1.DividendFrequency__c = 'Annually';
        update sc1;
        System.assertEquals('A USD Inc',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc1.Id].Name__c);

        sc0.DividendFrequency__c = null;
        sc0.CurrencyHedging__c = 'True';
        update sc0;
        System.assertEquals('A USD inc Hdg',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        sc0.Type__c = 'MyInvestor';
        update sc0;
        System.assertEquals('MyInvestor',
            [SELECT Name__c FROM Share_Class__c WHERE Id=:sc0.Id].Name__c);

        Test.stopTest();
    }

    @isTest
    static void test_closeTaxDataOnShareClassClosure() {

        Strategy__c s = new Strategy__c(Name='S', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c='S1');
        insert s;

        Product__c fund = new Product__c(
            Name='FundClose',
            FundStrategy__c=s.Id,
            Product_Name__c='FundClose',
            Record_Type_Name__c='Fund',
            RecordTypeId=fundRecordTypeId,
            Validity__c=true,
            LegalForm__c='SICAV',
            VehicleType__c='Funds'
        );
        insert fund;

        Share_Class__c sc = new Share_Class__c(
            Name='SC Close',
            Currency__c='USD',
            Type__c='A',
            Fund__c=fund.Id,
            Validity__c=true,
            Status__c='Active'
        );
        insert sc;

        TaxData__c td = new TaxData__c(
            ShareClass__c=sc.Id,
            Product__c=fund.Id,
            Country__c='AT',
            Type__c='Transparency',
            Status__c='Yes',
            Source__c='Manual'
        );
        insert td;

        Date closeDate = Date.today();

        Test.startTest();
        sc.Status__c = 'Closed - merged';
        sc.CloseDate__c = closeDate;
        update sc;
        Test.stopTest();

        td = [SELECT Status__c, EndDate__c FROM TaxData__c WHERE Id=:td.Id];

        System.assertEquals('No', td.Status__c);
        System.assertEquals(closeDate, td.EndDate__c);
    }

    @isTest
    static void test_sendATMergerLiquidationEmails_path() {

        Strategy__c s = new Strategy__c(Name='S', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c='S1');
        insert s;

        Product__c fund = new Product__c(
            Name='FundEmail',
            FundStrategy__c=s.Id,
            Product_Name__c='FundEmail',
            ProductName__c='FundEmail',
            Record_Type_Name__c='Fund',
            RecordTypeId=fundRecordTypeId,
            Validity__c=true,
            LegalForm__c='SICAV',
            VehicleType__c='Funds'
        );
        insert fund;

        Share_Class__c sc = new Share_Class__c(
            Name='SC Email',
            Name__c='SC Email',
            Currency__c='USD',
            Type__c='A',
            Fund__c=fund.Id,
            Validity__c=true,
            Status__c='Active'
        );
        insert sc;

        insert new TaxData__c(
            ShareClass__c=sc.Id,
            Product__c=fund.Id,
            Country__c='AT',
            Type__c='Transparency',
            Status__c='Yes',
            Source__c='Manual'
        );

        Test.startTest();
        sc.Status__c = 'Closed - liquidated'; 
        sc.CloseDate__c = Date.today();
        update sc;
        Test.stopTest();

        System.assertEquals('Closed - liquidated',
            [SELECT Status__c FROM Share_Class__c WHERE Id=:sc.Id].Status__c);
    }
}