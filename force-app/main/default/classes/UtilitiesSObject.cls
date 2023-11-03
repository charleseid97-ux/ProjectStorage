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

    //Set Client Managed Preferences for the Preference Center on new Lead and Contact Record
    //If the record is OPT IN and all the fields Client Managed Preferences are OFF, they should be defined as ON
    //Theses fields are represented on the Custom Metadata Type Preference Center Category, with the Category 'Communication Type'
    public static void initPreferenceCenter(List<SObject> newRecords) {
        List<String> clientManagedPreference = new List<String>{'Events__c', 'Fund_Update__c', 'Monthly_Newsletter__c'};
        Boolean allFalse = true;
        for (SObject record : newRecords) {
            if (record.get('HasOptedOutOfEmail') == false) {
                allFalse = true;
                for (String field : clientManagedPreference) {
                    if (record.get(field) == true) {
                        allFalse = false;
                        break;
                    }
                }
                if (allFalse) {
                    for (String field : clientManagedPreference) {
                        record.put(field, true);
                    }
                }
            }
            System.debug('HasOptedOutOfEmail' + record.get('HasOptedOutOfEmail'));
                for (String field : clientManagedPreference) {
                    System.debug('Field: ' + field + ' value: ' + record.get(field));
                }
        }
    }

    public static void checkCommunicationTypes(Sobject record, Sobject oldRecord, List<String> communicationTypes) {
        if (record.get('HasOptedOutOfEmail') == true) {
            //If a contact/lead opt out of email, all communication types fields must be set to false
            if (oldRecord.get('HasOptedOutOfEmail') == false) {
                for (String category : communicationTypes) {
                    record.put(category, false);
                  }
            }
            //If a contact/lead is opted out of email, and a communication type is set to true then the contact/lead should be opt in
            else if (oldRecord.get('Events__c') == false && oldRecord.get('Fund_Update__c') == false && oldRecord.get('Monthly_Newsletter__c') == false) {
                if (record.get('Events__c') == true || record.get('Fund_Update__c') == true || record.get('Monthly_Newsletter__c') == true) {
                    record.put('HasOptedOutOfEmail', false);
                }
            }
        }
        //If a contact/lead is opt in for email, but all communication types fields are set to false, then the contact/lead must be opt out of email
        else if (record.get('HasOptedOutOfEmail') == false) {
            Boolean allFalse = true;
            Boolean newFalse = false;
            for (String category : communicationTypes) {
                if (record.get(category) == true) {
                    allFalse = false;
                    break;
                }
                else if (record.get(category) != oldRecord.get(category)) {
                    newFalse = true;
                }
            }
            if (newFalse && allFalse) {
              record.put('HasOptedOutOfEmail', true);
            }
        }
    }

    public static void checkPreferencesFields(SObject record, SObject oldRecord, Map<String, List<String>> preferences) {
        for (String interest : preferences.keySet()) {
            if (record.get(interest) != oldRecord.get(interest)) {
                if (record.get(interest) == false) {
                    for (String subInterest : preferences.get(interest)) {
                        record.put(subInterest, false);
                    }
                }
                else {
                    Boolean allFalse = true;
                    for (String subInterest : preferences.get(interest)) {
                        if (record.get(subInterest) == true) {
                            allFalse = false;
                        }
                    }
                    if (allFalse) {
                        record.put(interest, false);
                    }
                }
            }
            else {
                Boolean oneTrue = false;
                for (String subInterest : preferences.get(interest)) {
                    if (record.get(subInterest) == true) {
                        oneTrue = true;
                        break;
                    }
                }
                if (oneTrue && record.get(interest) == false) {
                    record.put(interest, true);
                }
                else if (!oneTrue && record.get(interest) == true) {
                    record.put(interest, false);
                }
            }
        }
    }

    public static void checkPreferenceCenterFields(List<SObject> newRecords, Map<Id, SObject> oldRecords) {
        List<String> communicationTypes = new List<String>{'Events__c', 'Fund_Update__c', 'Monthly_Newsletter__c'};
        Map<String, List<String>> preferences = new Map<String, List<String>>();
        
        for (Preference_Center_Category__mdt prefCenterCat : [SELECT DeveloperName, category__c, Childs__c FROM Preference_Center_Category__mdt WHERE category__c in ('Preference')]) {
            List<String> childs = new List<String>();
            for (String str : prefCenterCat.Childs__c.split(';')) {
                childs.add(str.split(':')[0]);
            }
            preferences.put(prefCenterCat.DeveloperName + '__c', childs);
        }

        for (SObject newRecord : newRecords) {
            SObject oldRecord = oldRecords.get(newRecord.id);
            checkCommunicationTypes(newRecord, oldRecord, communicationTypes);
            checkPreferencesFields(newRecord, oldRecord, preferences);
        }   
    }
}