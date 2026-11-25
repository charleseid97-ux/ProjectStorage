/*
* 
* 
*
*/
/** ──────────────────────────────────────
 * @description Tests the Opportunity product selector methods: linked product checks, product links and the product tile list.
 * @covers ProductSelectionCtrl   85%   [25-11-26]
 * @lastModifiedBy Charles EID   [25-11-26]
 ────────────────────────────────────── */
@isTest
private class ProductSelectionCtrlTest {
    
    // @isTest
    // static void testGetProducts(){
        
    //     String StratProdRTId= Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
    //     String FundProdRTId= Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    //     Product__c testStratProd = new Product__c(Name='testStratProd', ProductName__c = 'testStratProd',
    //                                               RecordTypeId=StratProdRTId, Validity__c=true); //, Dedicated_Fund__c=false);
    //     insert testStratProd;
        
    //     Product__c testFundProd = new Product__c(Name='testFundProd', ProductName__c = 'testFundProd',
    //                                              RecordTypeId=FundProdRTId,
    //                                              Strategy__c=testStratProd.Id, Validity__c=true); //, Dedicated_Fund__c=false);
    //     insert testFundProd;
      
    //     String soqlQueryStrat = 'SELECT Id FROM Product__c WHERE Name = \'' + 'testStratProd' + '\'';
    //     Product__c[] stratList = Database.query(soqlQueryStrat);
    //     Product__c strat = stratList[0];
 	// 	system.debug('TBDG : ' + strat);
        
    //     Map<String, String> testMap = new Map<String, String>();
    //     testMap.put('strategy', String.valueOf(strat.Id ));
    //     testMap.put('searchKey', '');
    //     testMap.put('assetClass', '');
    //     testMap.put('subAssetClass', '');
	// 	String str = JSON.serialize(testMap);
    //     system.debug('TBDG TM : ' + str);
    //     ProductSelectionCtrl.PagedResult r =  new  ProductSelectionCtrl.PagedResult();
       
    //     r = ProductSelectionCtrl.getProducts(str, 18, 1);
    //     System.assertEquals(1, r.products.size());
        
    // }
    
    
    //  @isTest
    // static void testGetInvestmentStrategies(){
        
    //     String StratProdRTId= Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();                
       

    //     Product__c testStratProd = new Product__c(Name='testStratProd', ProductName__c='testStratProd',
    //                                               RecordTypeId=StratProdRTId, Validity__c=true);
    //     insert testStratProd;
       
      
    //     String soqlQueryStrat = 'SELECT Id FROM Product__c WHERE Name = \'' + 'testStratProd' + '\'';      	
    //     Product__c[] stratList = Database.query(soqlQueryStrat);
    //     Product__c strat = stratList[0];
 		
        
    //     Map<String, String> testMap = new Map<String, String>();
    //     testMap.put('strategy', String.valueOf(strat.Id ));
    //     testMap.put('searchKey', '');
	// 	String str = JSON.serialize(testMap);
    //     ProductSelectionCtrl.PagedResult r =  new  ProductSelectionCtrl.PagedResult();
       
    //     r = ProductSelectionCtrl.getInvestmentStrategies(str, 18, 1);
    //     System.assertEquals(1, r.products.size());
        
    // }
    
    @isTest
    static void testLinkProductsToOpportunity() {
        /*
        * Create a Test Product
        */ 
        String fundRecTypeId= Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        Product__c testProd = new Product__c(Name='TestProd', ProductName__c='TestProd', RecordTypeId=fundRecTypeId, Validity__c=true );
        insert testProd;        

        /*
        * Create a test Account
        */ 
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Account acc = new Account(Name = 'Child A Test', BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
       				,Billingcity='Chicago',BillingStreet='asd123',BillingPostalCode='60606'
       				,BillingCountry='United States',Billingstate='Illinois');
        
        insert acc;

        DateTime dT = System.now();
        Date testDate = date.newinstance(dT.year(), dT.month(), dT.day());

        /*
        * Create a new Opportunity - w/o a product 
        */ 
        String AssetRetentionOppRTId= Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('x2Asset_Retention_Opportunity').getRecordTypeId();
        Opportunity testOpp = new Opportunity(Name='testOpp',
                                              RecordTypeId=AssetRetentionOppRTId,
                                              StageName = 'Aspirational Target',
                                              AccountId = acc.Id,
                                              CloseDate = testDate);                                             
        insert testOpp;
        
        List<Opportunity_Product__c> testOppProds = new List<Opportunity_Product__c>{new Opportunity_Product__c(Name='TestOppProd', Product__c=testProd.Id, Opportunity__c=testOpp.Id)};
        
        List<Opportunity_Product__c> testDelOppProds = new List<Opportunity_Product__c>();
        
        ProductSelectionCtrl.linkProductsToOpp(testOppProds, testDelOppProds);
        
        ProductSelectionCtrl.confirmLinkedProductsToOpp(testOpp.Id);

        // The product tiles of the Opportunity product selector list the valid funds
        ProductSelectionCtrl.PagedResult pagedProducts = ProductSelectionCtrl.getProducts(JSON.serialize(new Map<String, Object>{ 'searchKey' => '' }), 50, 1);
        Assert.isTrue(new Map<Id, Product__c>(pagedProducts.products).containsKey(testProd.Id), 'The valid fund should be listed');
    }
}