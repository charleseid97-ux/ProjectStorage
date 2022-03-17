/**
* ---------------------------------------------------------------------------------------------------------------------------------------------------
* @Name			GenericRalatedListDisplayCtr_Test	
* @Author		Slimene BELHAJ ALI
* @Version		v1.0
* @CreatedDate	19/04/2018
* @UsedBy		
* @TestClass	
* ---------------------------------------------------------------------------------------------------------------------------------------------------	
* @Description
* Testing GenericRalatedListDisplayCtr
* ---------------------------------------------------------------------------------------------------------------------------------------------------	
**/
@isTest
private class GenericRalatedListCtrl_Test {
    
    static testMethod void testLoadDataFromConfig() {
        Account acc = TestFactory.getSimpleAccount();
        insert acc;
        
        Opportunity opp = TestFactory.getSimpleOpportunity();
        opp.AccountId = acc.Id;
        insert opp;
        
        
        Test.startTest();
            Map<String, Object> result = GenericRalatedListCtrl.loadDataFromConfig('Name,OwnerId,Amount,CloseDate,TotalOpportunityQuantity','Fields', '', 'Opportunity', 'AccountId', acc.Id ,'' ,'' ,'');
    
            System.assertEquals(1, ((List<Object>)result.get('data')).size());
            System.assertEquals(5, ((List<Object>)result.get('columns')).size());
            
            Map<String, Object> result1 = GenericRalatedListCtrl.loadDataFromConfig('Name','Fields', '', 'OpportunityLineItem', 'OpportunityId' , opp.Id, '', '', '');
            System.assertEquals(0, ((List<Object>)result1.get('data')).size());
            System.assertEquals(1, ((List<Object>)result1.get('columns')).size());
        Test.stopTest();
        
    }
    
    static testMethod void testdeleteRecord() {
        Account acc = TestFactory.getSimpleAccount();
        insert acc;
        Id accountId = acc.Id;
        Test.startTest();
        GenericRalatedListCtrl.deleteRecord(accountId, 'Account');
        Integer count = [select count() from Account where Id = :accountId];
        
        System.assertEquals(0 , count);
        Test.stopTest();
    }
}