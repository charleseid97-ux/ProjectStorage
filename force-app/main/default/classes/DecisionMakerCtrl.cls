global with sharing class DecisionMakerCtrl {

    Public static Integer tableBreak = 4;
    
    @AuraEnabled
    public static Map<String, String> returnSelectOptionsMap(sObject objObject, String fld) {
        List<String> values = getSelectOptions(objObject, fld);
        Map<String, String> valueMap = new Map<String, String>();
        Integer mapCounter = 1;
        for(String s : values) {
            valueMap.put(String.valueOf(mapCounter), s);
            if(mapCounter==tableBreak)mapCounter++;
            
            mapCounter++;
        }
        return valueMap;
    }

    @AuraEnabled
    public static List<Contact> returnContacts(String accId) {
        List<Contact> contacts = [SELECT FirstName, LastName, Level_of_Influence__c, Level_of_Support__c FROM Contact 
                                  WHERE AccountId =: accId AND Level_of_Influence__c <> '' AND Level_of_Support__c <> ''];
        return contacts;
    }
    
    @AuraEnabled
    public static List<Contact> returnAllContacts(List<Account> accHierarchyList) {
        List<Contact> contacts = [SELECT FirstName, LastName, Level_of_Influence__c, Level_of_Support__c FROM Contact 
                                  WHERE AccountId IN: accHierarchyList AND Level_of_Influence__c <> '' AND Level_of_Support__c <> ''];
        return contacts;
    }
    
    @AuraEnabled
    public static Map<String, String> returnContactTableMap(Map<String, String> influenceMap, Map<String, String> recommendMap, List<Contact> contacts) {
		Map<String, String> contactTableMap = new Map<String, String>();
        for(String s : influenceMap.keySet()) {
            contactTableMap.put('ct'+(tableBreak+1)+s, influenceMap.get(s));
        }
        for(String s : recommendMap.keySet()) {
            contactTableMap.put('ct'+s+(tableBreak+1), recommendMap.get(s));
        }
        
        for(Contact c : contacts) {
            String contactNames='';
            String contactKey = 'ct'+getKeyFromValue(recommendMap,c.Level_of_Support__c)+getKeyFromValue(influenceMap,c.Level_of_Influence__c);
            if(contactTableMap.get(contactKey)!= null)
	            contactNames += contactTableMap.get(contactKey)+'<br/>'; 
            contactNames += '<a href="/lightning/r/Contact/'+c.Id+'/view" style="color:black;font-weight:bold;">'+c.FirstName+' '+c.LastName+'</a>';
            contactTableMap.put(contactKey, contactNames);
        }
        return contactTableMap;
    }
    
    public static String getKeyFromValue(Map<String, String> hm, String value) {
        for (String o : hm.keySet()) {
            if (hm.get(o).equals(value)) {
                return o;
            }
        }
        return null;
    }
    
    private static List < String > getSelectOptions(sObject objObject, String fld) {
		List < String > allOpts = new list < String > ();
		Schema.sObjectType objType = objObject.getSObjectType();
 
      	Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
 
		map < String, Schema.SObjectField > fieldMap = objDescribe.fields.getMap();
 
        list < Schema.PicklistEntry > values =
        	fieldMap.get(fld).getDescribe().getPickListValues();
         
        for (Schema.PicklistEntry a: values) {
	        allOpts.add(a.getValue());
        }
        system.debug('allOpts ---->' + allOpts);
    	return allOpts;
	}
    
    @AuraEnabled
    public static List<Account> getAccountList(String UPId) {
        UPId = UPId.substring(0, 15);
        List<Account> returnAccounts = new List<Account>();
        Account UPAccount = [SELECT Name FROM Account WHERE Id=:UPId];
        returnAccounts.add(UPAccount);
        //Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        List<Account> accounts = [SELECT Name FROM Account WHERE Ultimate_Parent_Id__c =: UPId// AND RecordTypeId <>: devRecordTypeId 
                                 AND Id IN (SELECT AccountId FROM Contact WHERE Level_of_Influence__c <> '' AND Level_of_Support__c <> '')
                                 AND Id <> : UPId ORDER BY Name];
        returnAccounts.addAll(accounts);
        
        return returnAccounts;
    }
}