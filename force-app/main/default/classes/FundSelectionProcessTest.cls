/***
*	Test class for FundSelectionUtil and GlobalBuyListCtrl classes
*	15/02/2019 BP created
*
***/
@isTest
public with sharing class FundSelectionProcessTest {
    
    public static Account UPAccount, subAccount;
    public static List<Account> FSUAccounts;
    public static List<Product__c> strategyProducts;
    public static List<Product_Status__c> FSUBuyListItems;
    public static Product_Status__c localBuyListItem;
    
    public static void insertData() {
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Map<String, Id> prodRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Product__c.SObjectType);
        
        UPAccount = new Account(Name='Ultimate Parent Test', RecordTypeId = accRtMap.get('Account_GlobalAccount'), BusinessDevelopmentRegion__c='BP_FR');
        insert UPAccount;
        subAccount = new Account(Name='Sub Account Test', RecordTypeId = accRtMap.get('Account_Distributor'), BusinessDevelopmentRegion__c='BP_FR', BillingCountry='France');
        insert subAccount;
        
        FSUAccounts = new List<Account>{
            new Account(Name='FSU Internal Test', parentId=UPAccount.Id, RecordTypeId = accRtMap.get('Fund_Selection_Unit'), BusinessDevelopmentRegion__c='BP_FR'),
            new Account(Name='FSU External Test', RecordTypeId = accRtMap.get('Fund_Selection_Unit'), BusinessDevelopmentRegion__c='BP_FR')
        };
      	insert FSUAccounts;
        
        strategyProducts = new List<Product__c>{
            new Product__c(Name='Strategy Test 1', Product_Name__c='Strategy Test 1', Validity__c=true, RecordTypeId=prodRtMap.get('Strategy')),
            new Product__c(Name='Strategy Test 2', Product_Name__c='Strategy Test 2', Validity__c=true, RecordTypeId=prodRtMap.get('Strategy'))
        };
        insert strategyProducts;
        
        FSUBuyListItems = new List<Product_Status__c>{
            new Product_Status__c(Name='Test Internal BuyList', Fund_Selector__c=FSUAccounts[0].Id, Product__c=strategyProducts[0].Id, Status__c='Buy', Company__c=UPAccount.Id),
            new Product_Status__c(Name='Test External BuyList', Fund_Selector__c=FSUAccounts[1].Id, Product__c=strategyProducts[1].Id, Status__c='Buy', Company__c=UPAccount.Id)
        };
            
        insert FSUBuyListItems;

        localBuyListItem = new Product_Status__c(Name='Test Local BuyList', Local_Status__c='Sell', Global_Product_Status__c=FSUBuyListItems[0].Id, Company__c=subAccount.Id, Fund_Selector__c=FSUAccounts[1].Id, Product__c=strategyProducts[1].Id, Status__c='On Hold');
        insert localBuyListItem;
    }
    
    @isTest static void testFSUReport(){
		insertData();
        Test.startTest();
            FundSelectionUtil.getFSUForReport(UPAccount.Id);
        	
        	//test all strategies are returned for the report
        	List<Product__c> strategyList = FundSelectionUtil.getStrategyListForReport();
        	System.assertEquals(true, strategyList.size() > 0, 'Strategies are returned correctly');
        
        	//test strategies are covered in the report and their FSUs are marked as internal or external based on Heirarchy availability
            List<String> isCoveredList = FundSelectionUtil.isCoveredList(UPAccount.Id);
        	System.assertEquals(true, isCoveredList.size() > 0, 'isCovered List is returned correctly');
        	System.assertEquals(true, isCoveredList[0].endsWith('(int)'), 'Internal FSU Available');
        	System.assertEquals(true, isCoveredList[1].endsWith('(ext)'), 'External FSU Available');

        Test.stopTest();
    }
    
    @isTest static void testGlobalAndLocalBuyLists() {
		insertData();
        Test.startTest();
        	Map<String, Object> globalData = GlobalBuyListCtrl.loadGlobalBuyList('Product_Status__c', 'Company__c', UPAccount.Id, 'Account');
        	System.assertEquals(true, globalData.size() > 0, 'Global Data is returned correctly');
        
        	Map<String, Object> localData = GlobalBuyListCtrl.loadGlobalAndLocalBuyList('Product_Status__c', 'Company__c', UPAccount.Id, 'Account', 'Ultimate_Parent_Id__c');
	        System.assertEquals(true, localData.size() > 0, 'Local Data is returned correctly');
        
        	List<String> statuses = GlobalBuyListCtrl.getselectOptions(Schema.getGlobalDescribe().get('Product_Status__c').newSObject(), 'Status__c');
	        System.assertEquals(true, statuses.size() > 0, 'Buy List Statuses are returned correctly');
        
        	System.debug('BP1 ' + FSUBuyListItems[0].Status__c + ' - ' + FSUBuyListItems[0].Product__c + ' - ' + FSUBuyListItems[0].Fund_Selector__c);
        	FSUBuyListItems[0].Fund_Selector__c = FSUAccounts[1].Id;
        
        	Product_Status__c updGlobal = GlobalBuyListCtrl.saveGlobalBuyListCtrl(FSUBuyListItems[0].Status__c, 
                                                    FSUBuyListItems[0].Product__c, 
                                                    FSUBuyListItems[0].Fund_Selector__c, 
                                                    'comment', 
                                                    UPAccount.Id, 
                                                    FSUBuyListItems[0].Id);
	        System.assertEquals(true, updGlobal.Fund_Selector__c == FSUAccounts[1].Id, 'FSU on Global item has been updated');

        	GlobalBuyListCtrl.saveGlobalBuyListCtrl(FSUBuyListItems[0].Status__c, 
                                                    FSUBuyListItems[0].Product__c, 
                                                    FSUBuyListItems[0].Fund_Selector__c, 
                                                    'comment', 
                                                    UPAccount.Id, 
                                                    '');

	        localBuyListItem.Local_Status__c = 'On Hold';
        	Product_Status__c updLocal = GlobalBuyListCtrl.saveLocalBuyListCtrl(FSUBuyListItems[0].Id, 
                                                   localBuyListItem.Status__c, 
                                                   localBuyListItem.Local_Status__c, 
                                                   localBuyListItem.Product__c, 
                                                   localBuyListItem.Fund_Selector__c, 
                                                   localBuyListItem.Comment__c, 
                                                   UPAccount.Id, 
                                                   localBuyListItem.Id);
	        System.assertEquals(true, updLocal.Local_Status__c == 'On Hold', 'Local Status on Local Buy List item has been updated');

        	GlobalBuyListCtrl.saveLocalBuyListCtrl(FSUBuyListItems[0].Id, 
                                                   localBuyListItem.Status__c, 
                                                   localBuyListItem.Local_Status__c, 
                                                   localBuyListItem.Product__c, 
                                                   localBuyListItem.Fund_Selector__c, 
                                                   localBuyListItem.Comment__c, 
                                                   UPAccount.Id, 
                                                   '');

        	GlobalBuyListCtrl.deleteLocalCtrl(localBuyListItem.Id, FSUBuyListItems[0].Id);
        Test.stopTest();
    }
}