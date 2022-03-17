/*************************************************************************************************************************
Class Name      :   UtilitiesSobject
Class Desc.     :   Utility Class  used for sobject operations     
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                           Client               None        
***************************************************************************************************************************/
public without sharing class UtilitiesSObject 
{

    public class RecordTypeException extends Exception {}
    
    /* cache global describe result so only have to call it once per exec
     */
    public static map <String, SObjectType> GlobalDescribeResult
    {
        get 
        {
            if (GlobalDescribeResult == null)           
            {
                GlobalDescribeResult = Schema.getGlobalDescribe();              
            }
            return GlobalDescribeResult;
        }
        private set;
    }
    /** we should be using developer name to reference record types
     * built in SFDC uses Labels
     */
   public static map<String, Id> getRecordTypeIdsByDeveloperName(String pSObjectType)
    {

            
        map<String,Id> rtIdsMap = new map<String,Id>();
        
        RecordType[] rts = Database.query('SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = \'' + pSObjectType + '\'');
        for(RecordType rt : rts) rtIdsMap.put(rt.DeveloperName, rt.Id);
        
        return rtIdsMap;         
    }

  public static map<String, String> getRecordTypeNamesByDeveloperName(String pSObjectType)
  {
    map<String,String> rtNamesMap = new map<String,String>();
    
    RecordType[] rts = Database.query('SELECT DeveloperName, Name FROM RecordType WHERE SObjectType = \'' + pSObjectType + '\'');
    for(RecordType rt : rts) rtNamesMap.put(rt.DeveloperName, rt.Name);
    
    return rtNamesMap;    
  }
    
    
    /** we should be using developer name to reference record types
     * built in SFDC uses Labels
     */
    public static map<String, Schema.RecordTypeInfo> getRecordTypeInfosByDeveloperName(String pSObjectType)
    {
        map<String,Schema.RecordTypeInfo> rtsMap = new map<String,Schema.RecordTypeInfo>();
        
        map<Id, Schema.RecordTypeInfo> rtis = GlobalDescribeResult.get(pSObjectType).getDescribe().getRecordTypeInfosById();
        
        map<String, Id> rtIds = getRecordTypeIdsByDeveloperName(pSObjectType);
        
        for (string n : rtIds.keyset()) rtsMap.put(n, rtis.get(rtIds.get(n)));
        
        return rtsMap;      
    }

    /**
    * @author Noor
    * @date 20/11/2020
    * @description Get recordTypeId from rt developerName
     *             Use the getDescribe instead of soql to retrieve record type
    *
    * @param sObjectType
    * @param recordTypeName
    *
    * @return
    */
    public static String getRecordTypeIdByDeveloperName(SObjectType sObjectType, String recordTypeName) {
        //Generate a map of tokens for all the Record Types for the desired object
        Map<String, Schema.RecordTypeInfo> recordTypeInfo = sObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (!recordTypeInfo.containsKey(recordTypeName)) throw new RecordTypeException('Record type "' + recordTypeName + '" does not exist.');

        //Retrieve the record type id by name
        return recordTypeInfo.get(recordTypeName).getRecordTypeId();
    }
}