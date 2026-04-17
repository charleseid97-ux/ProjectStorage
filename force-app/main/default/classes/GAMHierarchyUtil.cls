public class GAMHierarchyUtil {

    @AuraEnabled
    public static Account returnGAMAccount(String accId) {
        return queryAccount('SELECT Name, Id FROM Account WHERE Id = \'' + accId + '\'');
    }
    
    private static Account queryAccount(String soqlQuery) {
        Account acc = Database.query(soqlQuery);
        return acc;
    }

    @AuraEnabled
    public static Map<String, Id> buildGroups(String GAMId) {
        Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        Id devRecordTypeIdGAM = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Account_GlobalAccount').getRecordTypeId();
		
        //Retrieve labels for the BD Region and Sub-Type pickList values
        Schema.DescribeFieldResult regionFieldResult = Account.BusinessDevelopmentRegion__c.getDescribe();
        Map<String, String> regionPickLabels = getPickListValues(regionFieldResult);
        Schema.DescribeFieldResult subTypeFieldResult = Account.Sub_Type__c.getDescribe();
        Map<String, String> subTypePickLabels = getPickListValues(subTypeFieldResult);

        Boolean KAM = false;
        
        //Lists to store all new Grouping Entities
        List<Account> countryGroups = new List<Account>();
        List<Account> subTypeGroups = new List<Account>();
        Set<String> countryAccountNames = new Set<String>();
        Set<String> subTypeAccountNames = new Set<String>();
        Map<String, Id> GAMAccountIdMap = new Map<String, Id>();
        
        //Return the actual GAM Account
        Account GAMAccount = queryAccount('SELECT Name, Id, RecordTypeId FROM Account where Id = \'' + GAMId + '\'');

		String GAMIdOrig = GAMId;
        if(GAMAccount.RecordTypeId != devRecordTypeIdGAM) {
            KAM = true;
	        GAMId = GAMId.substring(0,15);
	    }
        List<Account> subAccounts;
        if(!KAM) {
            subAccounts = [SELECT Name, Id, BusinessDevelopmentRegion__c, Distributor_Type__c, Sub_Type__c, RecordTypeId FROM Account where GAM__c =: GAMIdOrig];
        } else {
            subAccounts = [SELECT Name, Id, BusinessDevelopmentRegion__c, Distributor_Type__c, Sub_Type__c, RecordTypeId FROM Account where Ultimate_Parent_ID__c =: GAMId];
        }

        //Loop through all Accounts under this GAM
        for(Account accountToCategorise : subAccounts) {
            Account BDRegionGroup, subTypeGroup = null;
            //Check if BD Region Group Exists
            String countryAccName = GAMAccount.Name + ' ' + regionPickLabels.get(accountToCategorise.BusinessDevelopmentRegion__c);
            if(!countryAccountNames.contains(countryAccName)) {
                for(Account BDR : [SELECT Name, Id FROM Account WHERE GAM__c =: GAMIdOrig AND BusinessDevelopmentRegion__c =: accountToCategorise.BusinessDevelopmentRegion__c AND Sub_Type__c = '' AND RecordTypeId =: devRecordTypeId LIMIT 1 ]) {
                    BDRegionGroup = BDR;
                    GAMAccountIdMap.put(BDRegionGroup.Name, BDRegionGroup.Id);
                }
            }
            //If no Region Account create one and add to insert list
            if(BDRegionGroup == null && !countryAccountNames.contains(countryAccName)) {
                BDRegionGroup = new Account(Name=countryAccName, parentId=GAMAccount.Id, BusinessDevelopmentRegion__c=accountToCategorise.BusinessDevelopmentRegion__c, RecordTypeId = devRecordTypeId);
                if(!KAM) {
                    BDRegionGroup.GAM__c=GAMAccount.Id;
                }
                countryGroups.add(BDRegionGroup);
                countryAccountNames.add(countryAccName);
            }
            
            String subTypeAccName = GAMAccount.Name + ' ' + regionPickLabels.get(accountToCategorise.BusinessDevelopmentRegion__c) + ' - ' + subTypePickLabels.get(accountToCategorise.Sub_Type__c);
            //Check if region and sub-type Group exists
            if(!subTypeAccountNames.contains(subTypeAccName)) {
                for(Account STA : [SELECT Name, Id FROM Account WHERE GAM__c =: GAMIdOrig AND BusinessDevelopmentRegion__c =: accountToCategorise.BusinessDevelopmentRegion__c AND Sub_Type__c =: accountToCategorise.Sub_Type__c AND RecordTypeId =: devRecordTypeId LIMIT 1 ]) {
                    subTypeGroup = STA;
                }
            }
            //If one doesnt exists create it and add to insert list
            if(subTypeGroup == null && !subTypeAccountNames.contains(subTypeAccName)&&subTypePickLabels.get(accountToCategorise.Sub_Type__c)!=null) {
                subTypeGroup = new Account(Name=subTypeAccName, BusinessDevelopmentRegion__c=accountToCategorise.BusinessDevelopmentRegion__c, Distributor_Type__c = accountToCategorise.Distributor_Type__c, Sub_Type__c=accountToCategorise.Sub_Type__c, RecordTypeId=devRecordTypeId);
                if(!KAM) {
                    subTypeGroup.GAM__c=GAMAccount.Id;
                }
                subTypeGroups.add(subTypeGroup);
                subTypeAccountNames.add(subTypeAccName);
            }
        }

		//insert the country groups and retrieve again 
        insert countryGroups;
        
        List<Account> countryGroupsResult;
        if(!KAM) {
            countryGroupsResult = [SELECT Name, Id, BusinessDevelopmentRegion__c FROM Account WHERE GAM__c =: GAMIdOrig AND parentId =: GAMId AND RecordTypeId =: devRecordTypeId];
        } else {
            countryGroupsResult = [SELECT Name, Id, BusinessDevelopmentRegion__c FROM Account WHERE Ultimate_Parent_ID__c =: GAMId AND parentId =: GAMId AND RecordTypeId =: devRecordTypeId];
        }
        for(Account cG : countryGroupsResult) {
            //add Name, Id to MAP for setting to sub Accounts
            GAMAccountIdMap.put(cG.Name, cG.Id);
        }
        
        //Loop pre-saved sub-type accounts and set the correct country parentId pulled from MAP
        for(Account stG : subTypeGroups) {
            stG.parentId = GAMAccountIdMap.get(GAMAccount.Name + ' ' + regionPickLabels.get(stG.BusinessDevelopmentRegion__c));
        }
        insert subTypeGroups;

        List<Account> subTypeGroupsResult;
        if(!KAM) {
            subTypeGroupsResult = [SELECT Name, Id, BusinessDevelopmentRegion__c, Distributor_Type__c, Sub_Type__c, RecordTypeId FROM Account where GAM__c =: GAMIdOrig AND RecordTypeId =: devRecordTypeId];
        } else {
            subTypeGroupsResult = [SELECT Name, Id, BusinessDevelopmentRegion__c, Distributor_Type__c, Sub_Type__c, RecordTypeId FROM Account where Ultimate_Parent_ID__c =: GAMId AND RecordTypeId =: devRecordTypeId];
        }
        for(Account stGR : subTypeGroupsResult) {
            GAMAccountIdMap.put(stGR.Name, stGR.Id);
        }
        
        return GAMAccountIdMap;
    }
    
    @AuraEnabled
    public static List<String> deleteGroups(Map<String, Id> groupsToDelete) {
        List<String> groupIdsToDelete = groupsToDelete.values();
        Set<String> groupNameSet = groupsToDelete.keySet();
        List<String> groupNames = new List<String>();
        groupNames.addAll(groupNameSet);
        
        List<Account> accountsToDelete = [SELECT Name, Id FROM Account WHERE Id IN:groupIdsToDelete];

        delete accountsToDelete;
        return groupNames;
    }
    
    @AuraEnabled
    public static void overrideDeleteGroups(String GAMId) {
        Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        //Return the actual GAM Account
        Account GAMAccount = queryAccount('SELECT Name, Id, RecordTypeId FROM Account where Id = \'' + GAMId + '\'');

        Boolean KAM = false;
		String GAMIdOrig = GAMId;        
        if(GAMAccount.RecordTypeId != devRecordTypeId) {
            KAM = true;
	        GAMId = GAMId.substring(0,15);
	    }
        
        List<Account> accountsToDelete;
        if(!KAM) {
            accountsToDelete = [SELECT Name, Id FROM Account WHERE GAM__c =:GAMIdOrig AND RecordTypeId =: devRecordTypeId];
        } else {
            accountsToDelete = [SELECT Name, Id FROM Account WHERE Ultimate_Parent_ID__c =:GAMId AND RecordTypeId =: devRecordTypeId];
        }

        delete accountsToDelete;
    }
    
    @AuraEnabled
    public static void buildHierarchy(String GAMId, Map<String, Id> GroupMap) {
        Id devRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Grouping_Entity').getRecordTypeId();
        Id devRecordTypeIdGAM = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Account_GlobalAccount').getRecordTypeId();
        Schema.DescribeFieldResult regionFieldResult = Account.BusinessDevelopmentRegion__c.getDescribe();
        Map<String, String> regionPickLabels = getPickListValues(regionFieldResult);
        Schema.DescribeFieldResult subTypeFieldResult = Account.Sub_Type__c.getDescribe();
        Map<String, String> subTypePickLabels = getPickListValues(subTypeFieldResult);
        Account GAMAccount = queryAccount('SELECT Name, Id, RecordTypeId FROM Account where Id = \'' + GAMId + '\'');
		Boolean KAM = false;
        String GAMIdOrig = GAMId;
		if(GAMAccount.RecordTypeId != devRecordTypeIdGAM) {
            KAM = true;
	        GAMId = GAMId.substring(0,15);
	    }
        List<Account> subAccounts;
        if(!KAM) {
            subAccounts = [SELECT Name, Id, BusinessDevelopmentRegion__c, Distributor_Type__c, Sub_Type__c, RecordTypeId FROM Account where GAM__c =: GAMIdOrig AND RecordTypeId <> : devRecordTypeId];
        } else {
            subAccounts = [SELECT Name, Id, BusinessDevelopmentRegion__c, Distributor_Type__c, Sub_Type__c, RecordTypeId FROM Account where Ultimate_Parent_ID__c =: GAMId AND RecordTypeId <> : devRecordTypeId AND Id <> : GAMIdOrig];
        }
        
        List<Account> accountsToUpdate = new List<Account>();
        
        for(Account accountToCategorise : subAccounts) {
            String accName = GAMAccount.Name + ' ' + regionPickLabels.get(accountToCategorise.BusinessDevelopmentRegion__c);
            if(accountToCategorise.Sub_Type__c!=null&&accountToCategorise.Sub_Type__c!='')accName+= ' - ' + subTypePickLabels.get(accountToCategorise.Sub_Type__c);

            accountToCategorise.parentId = GroupMap.get(accName);

            accountsToUpdate.add(accountToCategorise);
        }

        update accountsToUpdate;
    }
    
    private static Map<String, String> getPickListValues(Schema.DescribeFieldResult fieldResult) {
        Map<String, String> pickLabels = new Map<String, String>();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry f : ple){
            pickLabels.put(f.getValue(), f.getLabel());
        }
        return pickLabels;
    }    
}