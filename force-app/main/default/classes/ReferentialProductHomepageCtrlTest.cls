@isTest
public class ReferentialProductHomepageCtrlTest {
     static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  

    @testSetup static void setup() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        Strategy__c s1 = new Strategy__c(Name='S1', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S02');
        
        insert s0;
        insert s1;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        Product__c p1 = new Product__c(Name='P1', FundStrategy__c=s1.Id, Product_Name__c='Product One', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true);
        Product__c p2 = new Product__c(Name='P2', FundStrategy__c=s1.Id, Product_Name__c='Product Inactif', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=false);
        
        insert p0;
        insert p1;
        insert p2;

        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', Currency__c='USD', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Status__c='Active');
        Share_Class__c sc1 = new Share_Class__c(Name='ShareClass1 A USD', Currency__c='USD', Type__c='A', Fund_Code__c='P1', Fund__c=p1.Id, Status__c='Active');
        
        insert sc0;
        insert sc1;
        
        Country__c c = new Country__c(Country__c = 'FR', ShareClass__c = sc0.Id, ISINCountryKey__c='SC0KEY');
        insert c;
        
    }
    
    @isTest
    static void getAllProducts_Test() {
        Test.startTest();
        //ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, 'FR', NULL,NULL, NULL, NULL, NULL, NULL, true, false);
        String filteredProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, 'Equity', 'A',NULL, 'SICAV', 'Funds', 'USD', NULL, true, NULL);
        String allProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL);
        String inactifProducts = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL);
        String p0Product = ReferentialProductHomepageCtrl.getAllProducts(NULL, NULL, NULL, 'FR', NULL, NULL, NULL, NULL, NULL, NULL, 'P0', true, NULL);
        Test.stopTest();
        System.assertNotEquals(null, allProducts);
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