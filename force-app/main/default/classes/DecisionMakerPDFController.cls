public with sharing class DecisionMakerPDFController {
	private final String myDomainName;
    private final String accountName;
    private final String viewFull;
    Public static Integer tableBreak = 4;
	private String matrixTable;
    private List<Contact> contacts; 
    private Map<String, String> levelOfInfluence;
    private Map<String, String> levelOfSupport;
    private Map<String, String> contactsTableMap;
    
    public DecisionMakerPDFController() 
    {
        myDomainName= URL.getSalesforceBaseUrl().toExternalForm().substringBefore('--c');
        viewFull = ApexPages.currentPage().getParameters().get('viewFull');
        levelOfInfluence = returnSelectOptionsMap(new Contact(), 'Level_of_Influence__c');
        levelOfSupport = returnSelectOptionsMap(new Contact(), 'Level_of_Support__c');
        
        if(ApexPages.currentPage().getParameters().get('viewFull') == 'true') {
            List<Account> hierarchyAccounts = getAccountList(ApexPages.currentPage().getParameters().get('id'));
            contacts = returnAllContacts(hierarchyAccounts);
        } else {
	        contacts = returnContacts(ApexPages.currentPage().getParameters().get('id'));
        }
        contactsTableMap = returnContactTableMap(levelOfInfluence, levelOfSupport, contacts);
        accountName = decisionMakerFileName(ApexPages.currentPage().getParameters().get('id'));
        matrixTable = buildTable(levelOfInfluence, levelOfSupport, contactsTableMap);
        
    }
    
    @AuraEnabled
    public static String decisionMakerFileName(String accId) {
        Account acc = [SELECT Name FROM Account WHERE Id=:accId];
        
        return acc.Name;
    }
    
    private static String buildTable(Map<String, String> levelOfInfluence, Map<String, String> levelOfSupport, Map<String, String> contactTableMap) {
        String tableString = '<table ><thead><tr>';

        Integer influenceSize = levelOfInfluence.size()+2;
        Integer supportSize = levelOfSupport.size()+2;
        
        for(Integer r = 1; r < supportSize; r++){
            for(Integer i = 1; i < influenceSize; i++){
                tableString+='<td class="matrixCell matrixColour'+r+''+i+'">';
                String thisValue = contactTableMap.get('ct'+r+i);
                if(thisValue!=null)
	                tableString+=thisValue+'</br>';
                tableString+='</td>';
            }
            tableString+='</tr><tr>';
        }
        
        
        tableString += '<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr></thead></table>';

        return tableString;
    }
    
    public static List<Contact> returnContacts(String accId) {
        List<Contact> contacts = [SELECT FirstName, LastName, Level_of_Influence__c, Level_of_Support__c FROM Contact 
                                  WHERE AccountId =: accId AND Level_of_Influence__c <> '' AND Level_of_Support__c <> ''];
        return contacts;
    }
    
    public static List<Contact> returnAllContacts(List<Account> accHierarchyList) {
        List<Contact> contacts = [SELECT FirstName, LastName, Level_of_Influence__c, Level_of_Support__c FROM Contact 
                                  WHERE AccountId IN: accHierarchyList AND Level_of_Influence__c <> '' AND Level_of_Support__c <> ''];
        return contacts;
    }
    
    public static List<Account> getAccountList(String accId) {
        Account thisAcc = [SELECT Ultimate_Parent_ID__c FROM Account WHERE Id =: accId];
        String UPId = thisAcc.Ultimate_Parent_ID__c.substring(0, 15);
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
    
    public static String getKeyFromValue(Map<String, String> hm, String value) {
        for (String o : hm.keySet()) {
            if (hm.get(o).equals(value)) {
                return o;
            }
        }
        return null;
    }
    
    public String getMyDomainName()
    {
        return myDomainName;
    }

	public String getAccountName()
    {
        return accountName;
    }

	public String getViewFull()
    {
        return viewFull;
    }

	public String getMatrixTable()
    {
        return matrixTable;
    }
    
    @AuraEnabled
    public static String downloadDecisionMaker(String url)
    { 
        PageReference pr = new PageReference(url); 
        String pdfStr;
        try {
            pdfStr = EncodingUtil.base64Encode(pr.getContentAsPDF());
        } catch(Exception ex) {
            System.debug(ex.getStackTraceString());
        }
        
        return pdfStr;  
    }


}