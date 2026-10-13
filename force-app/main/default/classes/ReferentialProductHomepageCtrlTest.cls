@isTest
public class ReferentialProductHomepageCtrlTest {
     static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  

    @testSetup static void setup() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        Strategy__c s1 = new Strategy__c(Name='S1', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S02');
        
        insert s0;
        insert s1;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, ProductName__c='Product Zero', InternalShortName__c='CC27', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds', InvestSolutionScope__c=true);
        Product__c p1 = new Product__c(Name='P1', FundStrategy__c=s1.Id, ProductName__c='Product One', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, InvestSolutionScope__c=true);
        Product__c p2 = new Product__c(Name='P2', FundStrategy__c=s1.Id, ProductName__c='Product Inactif', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=false);

        insert p0;
        insert p1;
        insert p2;

        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', Currency__c='USD', Type__c='A', Fund_Code__c='P0', ISIN__c='FR0000000001', Fund__c=p0.Id, Status__c='Active');
        Share_Class__c sc1 = new Share_Class__c(Name='ShareClass1 A USD', Currency__c='USD', Type__c='A', Fund_Code__c='P1', ISIN__c='LU0000000002', Fund__c=p1.Id, Status__c='Active');
        
        insert sc0;
        insert sc1;
        
        Country__c c = new Country__c(Country__c = 'FR', ShareClass__c = sc0.Id, ISINCountryKey__c='SC0KEY');
        insert c;
        
    }

    @isTest
    static void getAllProducts_Test() {
        Test.startTest();

        String filteredProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, 'Equity', 'A',NULL, 'SICAV', 'Funds', 'USD', NULL, true, false, NULL);
        String allProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, false, NULL);
        String inactifProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, false, false, NULL);
        String p0Product = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, 'FR', NULL, NULL, NULL, NULL, NULL, NULL, 'P0', true, false, NULL);
        String isinProduct = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'FR0000000001', true, false, NULL);
        String shortNameProduct = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'CC27', true, false, NULL);
        String noTextMatch = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'NoSuchFund', true, false, NULL);
        String noCountryMatch = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, 'DE', NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, false, NULL);
        String isProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, true, NULL);

        Test.stopTest();
    }
    
    @isTest
    static void logClick_Test() {
        Test.startTest();
        ReferentialProductHomepageCtrl.logClick('Product');
        Test.stopTest();
        List<UserInteractionLog__c> logs = [SELECT Id FROM UserInteractionLog__c]; 
        System.assertNotEquals(0, logs.size());
    }
}