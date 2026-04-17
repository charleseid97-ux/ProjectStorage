global with sharing class FundSelectionUtil {

    @AuraEnabled 
    public static List<ColWrapper> getFSUForReport(String GAMId) {
        Map<String, ColWrapper> FSUCols = new Map<String, ColWrapper>();
        List<Product_Status__c> prodStats = [SELECT Name, Fund_Selector__r.Id, Fund_Selector__r.GAM__c, Fund_Selector__r.Ultimate_Parent_Id__c, Fund_Selector__c, Fund_Selector__r.Name FROM Product_Status__c WHERE Company__c =: GAMId];
        for(Product_Status__c ps : prodStats) {
            String FSUName = ps.Fund_Selector__r.Name;
            if(ps.Fund_Selector__r.Ultimate_Parent_Id__c==null) {
                FSUName = FSUName + ' (ext)';
            } else {
                if(ps.Fund_Selector__r.Ultimate_Parent_Id__c==GAMId.substring(0,15)) {
	                FSUName = FSUName + ' (int)';
                } else {
    	            FSUName = FSUName + ' (ext)';
                }
            }
            ColWrapper ColWrap = new ColWrapper(FSUName, ps.Fund_Selector__r.Id);
            FSUCols.put(FSUName, ColWrap);
        }
        return FSUCols.values();
    }

    @AuraEnabled 
    public static Product__c[] getStrategyListForReport() {
        Id strategyRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        return [SELECT Name, Product_Name__c FROM Product__c WHERE (RecordTypeId =: strategyRecordTypeId OR (RecordTypeId =: fundRecordTypeId AND Legal_Status__c = 'OEIC')) AND validity__c = true AND Dedicated_Fund__c = false];
    }

    @AuraEnabled
    public static List<String> isCoveredList(String GAMId) {
        List<Product_Status__c> psList = [SELECT Name, Product__r.Name, Fund_Selector__r.Name, Fund_Selector__r.GAM__c, Fund_Selector__r.Ultimate_Parent_Id__c FROM Product_Status__c WHERE Company__c =: GAMId];
        List<String> isCovered = new List<String>();
        for(Product_Status__c ps:psList) {
            String FSUName = ps.Fund_Selector__r.Name;
            if(ps.Fund_Selector__r.Ultimate_Parent_Id__c==null) {
                FSUName = FSUName + ' (ext)';
            } else {
                if(ps.Fund_Selector__r.Ultimate_Parent_Id__c==GAMId.substring(0,15)) {
	                FSUName = FSUName + ' (int)';
                } else {
                    FSUName = FSUName + ' (ext)';
                }
            }

            isCovered.add(ps.Product__r.Name+'-'+FSUName);
        }
        return isCovered;
    }

    public class ColWrapper {
        @AuraEnabled  
        public String cLabel {get;set;}
        @AuraEnabled 
        public String cId {get;set;}
        
        public ColWrapper(String cLabel, String cId) {
            this.cLabel = cLabel;
            this.cId = cId;
        }
    }
    
    //New FSU Setup
    @AuraEnabled
    public static String checkRegionForFSU(String parentRecordId, String regionStr) {
        String gId = null;

        Account UPAccount = [SELECT Name from Account WHERE Id=: parentRecordId];
        String chkOne = UPAccount.Name+' '+regionStr+' - Fund Selection Unit';
        String chkTwo = UPAccount.Name+' '+regionStr+' - FSU'; 

        Account[] FSUGAccount = [SELECT Id FROM Account WHERE Name LIKE : chkOne OR Name LIKE : chkTwo LIMIT 1];
        if(FSUGAccount.size() > 0){
            gId = FSUGAccount[0].Id;
        }
        return gId;
    }
    
    @AuraEnabled
    public static Account saveFSUCtrl(String Name, String parentId, String BusinessDevelopmentRegion, Boolean autoCategory, String parentRecordId) {
        
        Schema.DescribeFieldResult regionFieldResult = Account.BusinessDevelopmentRegion__c.getDescribe();
        Map<String, String> regionPickLabels = getPickListValues(regionFieldResult);
		String regionAPIStr = getKeyFromValue(regionPickLabels, BusinessDevelopmentRegion);
        
        if(autoCategory)
            parentId = createCategory(parentRecordId, BusinessDevelopmentRegion, regionAPIStr);

        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Account newFSU = new Account(Name = Name.toUpperCase(),
                                    parentId = parentId,
                                    BusinessDevelopmentRegion__c = regionAPIStr,
                                    RecordTypeId = accRtMap.get('Fund_Selection_Unit'),
                                    CompanyStatus__c = 'Active');
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.SaveResult sr = Database.insert(newFSU, dml); 
        
        return newFSU;
    }
    
    public static String createCategory(String parentRecordId, String BusinessDevelopmentRegion, String regionAPIStr) {
        Account UPAccount = [SELECT Name from Account WHERE Id=: parentRecordId];
        String UPRegionAccountName = UPAccount.Name+' '+BusinessDevelopmentRegion;
        Account UPRegionAccount = [SELECT Id FROM Account WHERE Name =: UPRegionAccountName];
        
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Account newFSUGroup = new Account(Name=UPRegionAccountName+' - Fund Selection Unit', 
                                          parentId = UPRegionAccount.Id,
                                          BusinessDevelopmentRegion__c = regionAPIStr,
                                          RecordTypeId=accRtMap.get('Grouping_Entity'),
                                          CompanyStatus__c = 'Active');
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.SaveResult sr = Database.insert(newFSUGroup, dml);
        
        return newFSUGroup.Id;
    }
        
    @AuraEnabled
    public static void createBuyListCtrl(String parentId, String FSUId, List<String> productIds) {
        List<Product_Status__c> newBLItems = new List<Product_Status__c>();
        for(String pId : productIds) {
            Product_Status__c newBL = new Product_Status__c(Name = '' + FSUId+' '+pId, 
                                              Product__c = pId, 
                                              Status__c = '-', 
                                              Company__c = parentId, 
                                              Fund_Selector__c = FSUId);
            newBLItems.add(newBL);
        }
        insert newBLItems;
    }
    
    public static String getKeyFromValue(Map<String, String> hm, String value) {
        for (String o : hm.keySet()) {
            if (hm.get(o).equals(value)) {
                return o;
            }
        }
        return null;
    }
    
    @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
		List < String > allOpts = new list < String > ();
		Schema.sObjectType objType = objObject.getSObjectType();
 
      	Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
 
		map < String, Schema.SObjectField > fieldMap = objDescribe.fields.getMap();
 
        list < Schema.PicklistEntry > values =
        	fieldMap.get(fld).getDescribe().getPickListValues();
         
        for (Schema.PicklistEntry a: values) {
	        allOpts.add(a.getLabel());
        }
        system.debug('allOpts ---->' + allOpts);
        allOpts.sort();
    	return allOpts;
	}

    private static Map<String, String> getPickListValues(Schema.DescribeFieldResult fieldResult) {
        Map<String, String> pickLabels = new Map<String, String>();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry f : ple){
            pickLabels.put(f.getValue(), f.getLabel());
        }
        return pickLabels;
    }

    /*
    @AuraEnabled
    public static List<Account> getGroupingListForReport(String GAMId) {
        Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        List<Account> groupingAccounts = [SELECT Name FROM Account WHERE GAM__c =: GAMId AND RecordTypeId =: devRecordTypeId AND Sub_Type__c != null ORDER BY Name];
        return groupingAccounts;
    }

    @AuraEnabled
    public static List<String> countryCoverageListPartial(String GAMId) {
        Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        List<Account> groupingAccounts = [SELECT Name FROM Account WHERE GAM__c =: GAMId AND RecordTypeId =: devRecordTypeId AND Sub_Type__c != null ORDER BY Name];
        List<String> isCovered = new List<String>();
        
        for(Account a : groupingAccounts) {
            boolean setPartial = false;
            boolean setNone = false;
            boolean setFull = false;
            List<Account> sAList = [SELECT Name, Fund_Selector_Influence_Level__c FROM Account WHERE parentId =: a.Id ];
            if(sAList.size() > 0) {
                for(Account sA : sAList) {
                    if(sA.Fund_Selector_Influence_Level__c == 'Partial') {
                        setPartial = true;
                    }
                    if(sA.Fund_Selector_Influence_Level__c == 'None') {
                        setNone = true;
                    }
                    if(sA.Fund_Selector_Influence_Level__c == 'Full' || sA.Fund_Selector_Influence_Level__c == '' || sA.Fund_Selector_Influence_Level__c == null) {
                        setFull = true;
                    }
                }
                if(setFull && (setPartial || setNone)) {
                    isCovered.add(a.Name);
                }
            }
        }
        return isCovered;
    }

    @AuraEnabled
    public static List<String> countryCoverageListNone(String GAMId) {
        Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        List<Account> groupingAccounts = [SELECT Name FROM Account WHERE GAM__c =: GAMId AND RecordTypeId =: devRecordTypeId AND Sub_Type__c != null ORDER BY Name];
        List<String> isCovered = new List<String>();
        
        for(Account a : groupingAccounts) {
            boolean setPartial = false;
            boolean setNone = false;
            boolean setFull = false;
            List<Account> sAList = [SELECT Name, Fund_Selector_Influence_Level__c FROM Account WHERE parentId =: a.Id];
            if(sAList.size() > 0) {
                for(Account sA : sAList) {
                    if(sA.Fund_Selector_Influence_Level__c == 'Partial') {
                        setPartial = true;
                    }
                    if(sA.Fund_Selector_Influence_Level__c == 'None') {
                        setNone = true;
                    }
                    if(sA.Fund_Selector_Influence_Level__c == 'Full' || sA.Fund_Selector_Influence_Level__c == '' || sA.Fund_Selector_Influence_Level__c == null) {
                        setFull = true;
                    }
                }
                if(setNone && !setPartial && !setFull) {
                    isCovered.add(a.Name);
                }
            }
        }
        return isCovered;
    }

    @AuraEnabled
    public static List<Product_Status__c> getGlobalBuyListCtrl(String orgId) {
        Account GAMAccount = [SELECT GAM__c FROM Account WHERE Id =: orgId];
        List<Product_Status__c> globalList = new List<Product_Status__c>();
        if(GAMAccount != null) {
	        globalList = [SELECT Fund_Selector__c, Product__c, Status__c, Comment__c FROM Product_Status__c WHERE Company__c =: GAMAccount.GAM__c];
        }
        return globalList;
    }
    
    @AuraEnabled 
    public static Account initializeFSUPartial(String accId) {  
        String soqlQuery = 'SELECT Name, Id, FSU_Partial_Description__c FROM Account WHERE Id = \'' + accId + '\'';
        Account acc = Database.query(soqlQuery);
        return acc;
    }
    
    @AuraEnabled
    public static void  saveFSUPartial(String accId, String fsuPartialVal){        
        Account acc = new Account(Id = accId);
        acc.FSU_Partial_Description__c = fsuPartialVal;
        try{
            update acc;
        }
        catch(DMLException ex){
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            throw e;
        }
    }
    */
    /*
    @AuraEnabled
    public static Account getCurrentSubAccount(String AccountId) {
        return [SELECT Name FROM Account WHERE Id =: AccountId];
    }

    @AuraEnabled
    public static List<Account> getAllSubAccounts(String AccountId) {
        return [SELECT Name, Fund_Selector_Influence_Level__c FROM Account WHERE parentId =: AccountId];
    }
    */

}