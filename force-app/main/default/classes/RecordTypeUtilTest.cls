/**
 * tests for recordtypeUtil
 */

@isTest
public class RecordTypeUtilTest 
{
	/**
	 * return all record types including developername and sobjecttype
	 */
    public static testmethod void testRecordTypes()
    {
    	Test.startTest();
    	list<RecordType> RecordTypes = RecordTypeUtil.allRecordTypes;
    	Test.stopTest();
    	
    	for (RecordType rt : RecordTypes)
    	{
            system.assertNotEquals(rt.DeveloperName, null);
            system.assertNotEquals(rt.SObjectType, null);
    	}
        
    }
    
    /**
     * should build the map of recordtypeinfos and store results in the map
     */
    public static testmethod void testgetRecordTypeInfosByDeveloperName()
    {
    	Test.startTest();
    	map<String, Id> rtisMap =  RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
    	Id defaultId = RecordTypeUtil.GetDefaultRecordTypeId(Account.SObjectType);
    	Test.stopTest();
    	
    	// check so that it has returned the all the right number of values for the given sObjectType
    	list<RecordType> rtAccount = [SELECT Id, Developername FROM RecordType WHERE SObjectType = 'Account'];
    	system.assertEquals(rtisMap.size(), rtAccount.size());
        
     
        
    }
    
    
    
}