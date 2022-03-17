/*************************************************************************************************************************
Class Name      :   RecordTypeUtil
Class Desc.     :   Helper class to get the Recordtype ID's
Author          :   Alpha FMC

History
_______
v0.0   2016-09-30    Initial build of class
v0.1   2016-10-27    Added GetDefaultRecordTypeId to get default RT for running user
***************************************************************************************************************************/

public class RecordTypeUtil
{
 	/**
     * store all the RecordTypes out of the database so we only need to query once per execution
     * could become problematic if one day there are hundreds of record types
     * but for now reducing queries is better balance
     */
    public static List<RecordType> allRecordTypes {
        get{
            if (allRecordTypes == null)
                allRecordTypes = [select Id, Name, DeveloperName, SObjectType from RecordType];

            return allRecordTypes;
        }
        set;
    }

    //Map of Map to store the GetRecordTypeIdsByDeveloperName Maps requested previously in the same transaction
    public static map<Schema.SObjectType, map<String, Id>> GetRecordTypeIdsByDeveloperNameCache
    {
        get
        {
            if(GetRecordTypeIdsByDeveloperNameCache == null)
            {
                GetRecordTypeIdsByDeveloperNameCache = new map<Schema.SObjectType, map<String, Id>>();
            }
            return GetRecordTypeIdsByDeveloperNameCache;
        }
        set;
    }

    /**
     * Returns a map of RecordType DeveloperName to ID for a given sObjectName
     *  we should be using developer name to reference record types but built in SFDC uses Labels
     *  this method queries ALL record types up front and stores them so only one query per
     *  execution to retrieve any record type info. If SFDC included the Developer Name in the
     *  recordtypeinfo, we wouldn't have to do this
     */
    public static map<String, Id> GetRecordTypeIdsByDeveloperName(Schema.SObjectType sObjectName)
    {
        map<String, Id> rtMap;
        //Check if we have processes this sObjectName before
        if (GetRecordTypeIdsByDeveloperNameCache.get(sObjectName) != null)
        {
            rtMap = GetRecordTypeIdsByDeveloperNameCache.get(sObjectName);
        }
        //else let's add it in
        else
        {
            rtMap = new map<String, Id>();
            for (RecordType rt : allRecordTypes)
            {
                if (rt.sObjectType == String.valueOf(sObjectName)) rtMap.put(rt.DeveloperName, rt.Id);
            }
            GetRecordTypeIdsByDeveloperNameCache.put(sObjectName, rtMap);
        }

        return rtMap;


    }

    //returns the RecordType record given a record type ID
    public static RecordType getRecordTypeById(Id recordTypeId){
        for (RecordType rt : allRecordTypes) {
            if (rt.Id == recordTypeId) return rt;
        }
        return null;
     }

    //Returns the default recordTypeId for the running user for specified SObject
    public static Id GetDefaultRecordTypeId(Schema.SObjectType sObjectName )
    {
        list<Schema.RecordTypeInfo> rtInfos = sObjectName.getDescribe().getRecordTypeInfos();
        Id defaultRecordTypeId;
        //run through each to see which one is the the default
        for (Schema.RecordTypeInfo rtInfo : rtInfos)
        {
          if (rtInfo.DefaultRecordTypeMapping)
          {
            defaultRecordTypeId = rtInfo.RecordTypeId;
          }
        }

        return defaultRecordTypeId;
    }


}