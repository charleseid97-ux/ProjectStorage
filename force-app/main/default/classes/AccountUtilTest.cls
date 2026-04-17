/***
*	Test class for AccountUtil class
*	15/02/2019 BP created
*
***/
@isTest
public with sharing class AccountUtilTest {
    public static Account testAcc;
    
	public static void insertData() {
        testAcc = TestFactory.getSimpleAccount();
        testAcc.Client_Tier__c = 'Titanium (Tier 0)';
        insert testAcc;
    }
    
    @isTest static void testTaskManagement(){
        insertData();
        Test.startTest();
        	Account tierAcc = AccountUtil.confirmClientTier(testAcc.Id);
        	System.assertEquals(true, tierAcc.Client_Tier__c=='Titanium (Tier 0)', 'Client Tier returned correctly');
        	Account retAcc = AccountUtil.returnGAMAccount(testAcc.Id);
            System.assertEquals(true, retAcc.Id==testAcc.Id, 'Correct Account Returned');

        Test.stopTest();
    }
}