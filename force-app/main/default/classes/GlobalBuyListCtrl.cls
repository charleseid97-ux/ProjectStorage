public without sharing class GlobalBuyListCtrl {
    
    @AuraEnabled 
    public static Map<String, Object> loadGlobalBuyList(String objectName, String parentName, String recordId, String sObjectType) {
        System.debug('CTS Variables 1'  + objectName + ' 2' + parentName + ' 3' + recordId + ' 4' + sObjectType);
        Map<String, Object> globalResult = new Map<String, Object>();
        //load data by generic query
        List<Product_Status__c> data = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', 'Local_Buy_List_Items__c = true', objectName, parentName, recordId, 'Status__c', false));
        List<Product_Status__c> allData = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', '', objectName, parentName, recordId, 'Status__c', false));

        List<Id> dataIdList = extractIdFromSObject(data);
        List<Id> allDataIdList = extractIdFromSObject(allData);
        globalResult.put('editAccess', loadPermissionRecord(dataIdList, 'HasEditAccess'));
        globalResult.put('deleteAccess', loadPermissionRecord(dataIdList, 'HasDeleteAccess'));
        globalResult.put('allEditAccess', loadPermissionRecord(allDataIdList, 'HasEditAccess'));
        globalResult.put('allDeleteAccess', loadPermissionRecord(allDataIdList, 'HasDeleteAccess'));
        globalResult.put('data', data);
        globalResult.put('allData', allData);
        //load columns
        globalResult.put('columns', getColumnsFormat('Product__c, Fund_Selector__c, Status__c, Comment__c', ObjectName));
        globalResult.put('columnsAll', getColumnsFormat('Product__c, Fund_Selector__c, Status__c, Comment__c, Local_Buy_List_Items__c', ObjectName));
        //retun map data + column
        return globalResult;
    }
    
    @AuraEnabled 
    public static Map<String, Object> loadGlobalAndLocalBuyList(String objectName, String parentName, String recordId, String sObjectType, String recordIdOverride) {
        
		String originalRecordId = recordId;
        System.debug('CTS Variables 1'  + objectName + ' 2' + parentName + ' 3' + recordId + ' 4' + sObjectType + ' 5'+recordIdOverride);

        Object recordIdOverrideVal = '';
        if(recordIdOverride!=''&&recordIdOverride!=null) {
            List<SObject> data = Database.query(buildQuery(recordIdOverride, '', sObjectType, 'Id', recordId, '', true));
            for(SObject record : data) {
                recordIdOverrideVal = record.get(recordIdOverride);
                recordId = recordIdOverrideVal.toString();
            }
        }

        Map<String, Object> globalResult = new Map<String, Object>();
        //load data by generic query
        List<Product_Status__c> data = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', 'Status__c != \'-\' AND Status__c != \'N/A\'', objectName, parentName, recordId, 'Status__c', false));
        List<Product_Status__c> independantData = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', 'Status__c = \'N/A\'', objectName, parentName, originalRecordId, 'Status__c', false));
        List<Product_Status__c> allData = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', '', objectName, parentName, recordId, 'Status__c', false));


        Map<Id, Product_Status__c> global_Product_Status_Map = new Map<Id, Product_Status__c>();
        Map<Id, Product_Status__c> globalAll_Product_Status_Map = new Map<Id, Product_Status__c>();

        for(Product_Status__c productStatus :[SELECT Local_Status__c, Comment__c, Global_Product_Status__c FROM Product_Status__c WHERE Company__c =: originalRecordId AND Global_Product_Status__c in : data])
            global_Product_Status_Map.put(productStatus.Global_Product_Status__c, productStatus);

        for(Product_Status__c productStatus :[SELECT Local_Status__c, Comment__c, Global_Product_Status__c FROM Product_Status__c WHERE Company__c =: originalRecordId AND Global_Product_Status__c in : allData])
            globalAll_Product_Status_Map.put(productStatus.Global_Product_Status__c, productStatus);

        for(Product_Status__c dataItem : data) {
            dataItem.Comment__c = '';
            if(dataItem.Local_Buy_List_Items__c) {
                try {
                    //needs optimising
                    //Product_Status__c localStatus = [SELECT Local_Status__c, Comment__c FROM Product_Status__c WHERE Company__c =: originalRecordId AND Global_Product_Status__c =: dataItem.Id];
                    if(global_Product_Status_Map.containsKey(dataItem.Id)) {
                        Product_Status__c localStatus = global_Product_Status_Map.get(dataItem.Id);
                        dataItem.Local_Status__c = localStatus.Local_Status__c;
                        dataItem.Comment__c = localStatus.Comment__c;
                    }
                } catch (Exception e) {
                    System.debug('No local Buy List for this Account');
                }
            }
        }
        
        data.addall(independantData);
        
        for(Product_Status__c dataItem : allData) {
            dataItem.Comment__c = '';
            if(dataItem.Local_Buy_List_Items__c) {
                try {
                    //needs optimising
                    //Product_Status__c localStatus = [SELECT Local_Status__c, Comment__c FROM Product_Status__c WHERE Company__c =: originalRecordId AND Global_Product_Status__c =: dataItem.Id];
                    if(globalAll_Product_Status_Map.containsKey(dataItem.Id)) {
                        Product_Status__c localStatus = globalAll_Product_Status_Map.get(dataItem.Id);
                        dataItem.Local_Status__c = localStatus.Local_Status__c;
                        dataItem.Comment__c = localStatus.Comment__c;
                        if(dataItem.Status__c == '-' && localStatus.Local_Status__c != '-') {
	                        data.add(dataItem);
                        }
                    }
                } catch (Exception e) {
                    System.debug('No local Buy List for this Account');
                }
            }
        }
        
        if(allData.size() == 0) {
        	allData.addall(independantData);
        }

        
        List<Id> dataIdList = extractIdFromSObject(data);
        List<Id> allDataIdList = extractIdFromSObject(allData);
        globalResult.put('editAccess', loadPermissionRecord(dataIdList, 'HasEditAccess'));
        globalResult.put('deleteAccess', loadPermissionRecord(dataIdList, 'HasDeleteAccess'));
        globalResult.put('allEditAccess', loadPermissionRecord(allDataIdList, 'HasEditAccess'));
        globalResult.put('allDeleteAccess', loadPermissionRecord(allDataIdList, 'HasDeleteAccess'));
        globalResult.put('data', data);
        globalResult.put('allData', allData);
        if(independantData.size()==0 && allData.size() > 0) {
    	    globalResult.put('noGBL', false);
        } else {
	        globalResult.put('noGBL', true);
        } 
        //load columns
        globalResult.put('columns', getColumnsFormat('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Comment__c', ObjectName));
        //retun map data + column
        return globalResult;
    }
    
    @AuraEnabled 
    public static Map<String, Object> loadIndependentBuyList(String objectName, String parentName, String recordId, String sObjectType, String recordIdOverride) {
	
        List<Account> accountIds = new List<Account>();
        String accountIdString = '(';
        accountIds = AccountPlanCtrl.getChildAccountsInHierarchy(recordId);
        for(Account a : accountIds) {
            accountIdString = accountIdString + '\'' + a.Id + '\',';
        }
        accountIdString = accountIdString.substring(0, accountIdString.length() -1);
        accountIdString = accountIdString + ')';
        
        system.debug('ACC ID ' + accountIdString);
        List<Product_Status__c> data = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', 'Company__c IN '+accountIdString, objectName, null, recordId, 'Status__c', false));
        List<Product_Status__c> allData = Database.query(buildQuery('Product__c, Fund_Selector__c, Status__c, Local_Status__c, Local_Buy_List_Items__c, Comment__c', 'Company__c IN '+accountIdString, objectName, null, recordId, 'Status__c', false));

        system.debug('BP ' + data);
        Map<String, Object> globalResult = new Map<String, Object>();

        List<Id> dataIdList = extractIdFromSObject(data);
        List<Id> allDataIdList = extractIdFromSObject(allData);
        globalResult.put('editAccess', loadPermissionRecord(dataIdList, 'HasEditAccess'));
        globalResult.put('deleteAccess', loadPermissionRecord(dataIdList, 'HasDeleteAccess'));
        globalResult.put('allEditAccess', loadPermissionRecord(allDataIdList, 'HasEditAccess'));
        globalResult.put('allDeleteAccess', loadPermissionRecord(allDataIdList, 'HasDeleteAccess'));
        globalResult.put('data', data);
        globalResult.put('allData', allData);

        globalResult.put('columns', getColumnsFormat('Product__c, Fund_Selector__c, Status__c, Comment__c', ObjectName));
        globalResult.put('columnsAll', getColumnsFormat('Product__c, Fund_Selector__c, Status__c, Comment__c, Local_Buy_List_Items__c', ObjectName));
        
        return globalResult;
    }
    
    private static string buildQuery(String fields, String whereClause, String objectName, String parentName, String recordId, String sortBy, Boolean noNameReturn){
        String query = 'select ';
        if(noNameReturn) {
            query = query + fields;
        } else {
	        query = query + readFields(fields, objectName);
        }
        if(parentName != null) {
	        query = query + ' from  ' + objectName + ' where '+((whereClause == null || whereClause.trim() == '' )? '' : ('(' + whereClause + ') and ')) + parentName + ' = \'' + recordId + '\'';
        } else {
            query = query + ' from  ' + objectName + ' where '+((whereClause == null || whereClause.trim() == '' )? '' : ('(' + whereClause + ')'));
        }
		if(sortBy != null && sortBy != '')
	        query = query + ' ORDER BY ' + sortBy;

        system.debug('BPQ : ' + query);
        return query;
    }
    
    private static String readFields(String fields, String ObjectName) {
        String resultField = '';
        //load all SObject fields
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(ObjectName).getDescribe().fields.getMap();
        fieldMap = toLowerCaseMapFields(fieldMap);
        for(String item : fields.split(',')){
            item = item.trim().toLowerCase();
            if(fieldMap.get(item).getDescribe().getRelationshipName() != null) {
                //load relationship name
                resultField +=fieldMap.get(item).getDescribe().getRelationshipName() + '.Name,';
                continue;
            }
            //Load field set member
            resultField +=item + ',';
        }
        return resultField.removeEnd(',');
    } 

    private static List<ColumnWrapper> getColumnsFormat(String fields, String ObjectName) {
        List<ColumnWrapper> columnList = new List<ColumnWrapper>();
        //load all SObject fields
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(ObjectName).getDescribe().fields.getMap();
       
        fieldMap = toLowerCaseMapFields(fieldMap);
        for(String item : fields.split(',')){
            item = item.trim().toLowerCase();
            Schema.DescribeFieldResult currentDesc = fieldMap.get(item).getDescribe();
            columnList.add(new ColumnWrapper(currentDesc.getLabel(), currentDesc.getName(),getType(currentDesc.getType()),currentDesc));
        }
       
        return columnList;
    }
    
    private static Map<String, Schema.SObjectField> toLowerCaseMapFields(Map<String, Schema.SObjectField> mapField){
    	Map<String, Schema.SObjectField> result = new Map<String, Schema.SObjectField>();
    	
    	for(String key : mapField.KeySet()) {
    		result.put(key.toLowerCase(), mapField.get(key));
    	}
    	return result;
    }
    

    private static String getType(schema.displaytype fielddataType) {
        //test if filed is number
        if(fielddataType == Schema.DisplayType.Integer || fielddataType == Schema.DisplayType.Double || fielddataType == Schema.DisplayType.Percent) {
            return 'number';
        }
        //test if filed is data or data type
        if(fielddataType == Schema.DisplayType.DateTime || fielddataType == Schema.DisplayType.Date) {
            return 'date';
        }
        //test if filed is boolean
        if(fielddataType == Schema.DisplayType.Boolean) {
            return 'boolean';
        }
		//test if filed is currency
        if(fielddataType == Schema.DisplayType.Currency) {
            return 'currency';
        }
        
        return 'text';
    }
   
    private static List<Id> loadPermissionRecord(List<Id> recordIdList, String permissionField) {
    	Id userId = UserInfo.getUserId();
        String query = 'SELECT RecordId FROM UserRecordAccess WHERE UserId= :userId AND '+permissionField+' = true AND RecordId IN :recordIdList LIMIT 200';
        List<UserRecordAccess> resultAccess = Database.query(query);
        List<String> result = new List<String>();
        for(UserRecordAccess item : resultAccess) {
        	result.add(item.RecordId);
        }
        return result;
    }
    
    private static List<Id> extractIdFromSObject(List<Product_Status__c> sobjectList) {
        List<Id> listId = new List<Id>();
        if(sobjectList == null ||sobjectList.size() == 0) {
            return listId;
        }
        
        for(Product_Status__c item : sobjectList) {
            listId.add(item.Id);
        }
        
        return listId;
    }
    
    /**
	* @Class: ColumnWrapper
	* @Description: This class contain all infromations about column (label, type, filedName...)
	*/
    public class ColumnWrapper {
        @AuraEnabled  
        public String label {get;set;}
        @AuraEnabled 
        public String fieldName {get;set;}
        @AuraEnabled 
        public String type {get;set;}
        @AuraEnabled 
        public Boolean sortable {get;set;}
        @AuraEnabled
        public Map<String, Object> typeAttributes {get;set;}
   
        public ColumnWrapper(String label, String fieldName, String type, Schema.DescribeFieldResult fieldDescription) {
           //init data
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;
            this.sortable = true;
            typeAttributes = new Map<String, Object>();
            //if field is a relationsip field
            if(fieldDescription.getRelationshipName() != null) {
                //change label field
                this.label = fieldDescription.getLabel().replace(' ID', '');
       
                //change field name 
                this.fieldName = fieldDescription.getRelationshipName() + 'Name';
                this.type = 'url';
                Map<String, String> labels = new Map<String, String>();
                labels.put('fieldName',  this.fieldName + 'Label');
                typeAttributes.put('label', labels);
                
            }
             	
            //if type is currency
            if(type == 'currency') {
              
                //set static currency
                typeAttributes.put('currencyCode','EUR');
            }
        }
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
    
    @AuraEnabled
    public static Product_Status__c getGlobalBuyListItemCtrl(String buyListId) {
        Product_Status__c BS = [SELECT Name, Product__c, Product__r.Name, Fund_Selector__c, Status__c, Company__c, Comment__c, Local_Status__c FROM Product_Status__c WHERE ID =: buyListId];
        return BS;
    }

    @AuraEnabled
    public static Product_Status__c getLocalBuyListItemCtrl(String globalBuyListId, String accountId) {
        try {
            Product_Status__c localStatus = [SELECT Local_Status__c, Comment__c, Product__r.Name FROM Product_Status__c WHERE Company__c =: accountId AND Global_Product_Status__c =: globalBuyListId];
            return localStatus;
        } catch (Exception e) {
            return null;
        }
    }
    
    @AuraEnabled
    public static List<Product_Status__c> getLocalBuyListsCtrl(String buyListId) {
        Schema.DescribeFieldResult regionFieldResult = Account.BusinessDevelopmentRegion__c.getDescribe();
        Map<String, String> regionPickLabels = getPickListValues(regionFieldResult);
        
        List<Product_Status__c> buyList = [SELECT Company__c, Company__r.Name, Company__r.BusinessDevelopmentRegion__c, Local_Status__c, Comment__c FROM Product_Status__c WHERE Global_Product_Status__c =: buyListId];
        for(Product_Status__c buyItem : buyList) {
            buyItem.Company__r.BusinessDevelopmentRegion__c = regionPickLabels.get(buyItem.Company__r.BusinessDevelopmentRegion__c);
        }
        return buyList;
    }

    //Save Global Buy List
    @AuraEnabled
    public static Product_Status__c saveGlobalBuyListCtrl(String globalStatus, String product, String fundSelector, String comment, String accountId, String buyListDisplayId) {
        Product_Status__c processPS = new Product_Status__c();
        String fundSelectorName = ' - BUY LIST';
        if(buyListDisplayId != null && buyListDisplayId != '') {
            processPS = [SELECT Company__c, Product__c, Fund_Selector__c, Status__c, Comment__c FROM Product_Status__c WHERE Id=: buyListDisplayId];
            String psOLDFundSelector = processPS.Fund_Selector__c;
            String psOLDCompany =  processPS.Company__c;

            processPS.Status__c = globalStatus;
            processPS.Product__c = product;
            processPS.Fund_Selector__c = fundSelector;
            processPS.Comment__c = comment;
            update processPS;
            
            manageThirdPartyDelete(psOLDCompany, psOLDFundSelector);
        } else {
            if(fundSelector != null) {
                Account IFSU = [SELECT Id, Name FROM Account WHERE Id =:fundSelector];
                fundSelectorName = IFSU.Name+fundSelectorName;
            }
            processPS = new Product_Status__c(Name = fundSelectorName, 
                                              Product__c = product, 
                                              Status__c = globalStatus, 
                                              Company__c = accountId, 
                                              Fund_Selector__c = fundSelector, 
                                              Comment__c = comment);
            insert processPS;
        }

        //If the FSU doesnt belong to the current heirarchy then add a Related Company record
        Account FSU = [SELECT Ultimate_Parent_Id__c FROM Account WHERE Id =: fundSelector];
        Account FSUUltimateParent = [SELECT Id FROM Account WHERE Id =: FSU.Ultimate_Parent_Id__c];
        System.debug(FSUUltimateParent.Id+' - '+accountId);
        if(FSUUltimateParent.Id != accountId) {
            List<RelatedCompany__c> relComps = [SELECT Name FROM RelatedCompany__c WHERE Company__c =: accountId AND ThirdParty__c =: fundSelector];
            if(relComps.size() == 0) {
                RelatedCompany__c newRelComp = new RelatedCompany__c(Company__c = accountId, ThirdParty__c = fundSelector, Role__c = 'External FSU');
                insert newRelComp;
            }
        }

        return processPS;
    }
    
    //Save Local Buy List
    @AuraEnabled
    public static Product_Status__c saveLocalBuyListCtrl(String globalStatusId, String globalStatus, String localStatus, String product, String fundSelector, String comment, String accountId, String localId) {
        Product_Status__c processPS = new Product_Status__c();
		String fundSelectorName = ' - BUY LIST';
        if(fundSelector == null) {
            Account IFSU = [SELECT Id, Name FROM Account WHERE Primary_Local_FSU__c = true AND RecordType.Name = 'Fund Selection Unit'];
            fundSelector = IFSU.Id;
            fundSelectorName = IFSU.Name+fundSelectorName;
        }
        
        if(localId != null && localId != '') {
            processPS = [SELECT Local_Status__c, Product__c, Comment__c FROM Product_Status__c WHERE Id=: localId];
            processPS.Local_Status__c = localStatus;
            processPS.Product__c = product;
            processPS.Comment__c = comment;
            update processPS;
        } else {
            processPS = new Product_Status__c(Name = fundSelectorName, 
                                              Product__c = product, 
                                              Status__c = globalStatus, 
                                              Company__c = accountId, 
                                              Fund_Selector__c = fundSelector, 
                                              Local_Status__c = localStatus, 
                                              Comment__c = comment, 
                                              Global_Product_Status__c = globalStatusId);
            insert processPS;
        }
        
        if(globalStatusId != '' && globalStatusId != null) {
            Product_Status__c globalStatusUpdate = [SELECT Local_Buy_List_Items__c FROM Product_Status__c WHERE Id =: globalStatusId];
            globalStatusUpdate.Local_Buy_List_Items__c = true;
            update globalStatusUpdate;
        }
        
        return processPS;
    }
    
    //Save Independant Buy List
    @AuraEnabled
    public static Product_Status__c saveIndepenantBuyListCtrl(String localStatus, String comment, String localId) {
        Product_Status__c processPS = new Product_Status__c();

        if(localId != null && localId != '') {
            processPS = [SELECT Local_Status__c, Product__c, Comment__c FROM Product_Status__c WHERE Id=: localId];
            processPS.Local_Status__c = localStatus;
            processPS.Comment__c = comment;
            update processPS;
        }
        
        return processPS;
    }
    
    //Delete Global Buy List
    @AuraEnabled 
    public static void deleteGlobalCtrl(String recordId) {
    	Product_Status__c delGlobal = [SELECT Company__c, Fund_Selector__c FROM Product_Status__c WHERE Id =: recordId];

        delete delGlobal;
        manageThirdPartyDelete(delGlobal.Company__c, delGlobal.Fund_Selector__c);
    }
    
    //Delete Local Buy List
    @AuraEnabled
    public static void deleteLocalCtrl(String delId, String globalStatusId) {
        Product_Status__c delStatus = [SELECT Name FROM Product_Status__c WHERE Id =: delId];
        delete delStatus;
        
        Product_Status__c globalStatus = [SELECT Company__c, Local_Buy_List_Items__c FROM Product_Status__c WHERE Id =: globalStatusId];
        
        List<Product_Status__c> localStatusList = [SELECT Name FROM Product_Status__c WHERE Global_Product_Status__c =: globalStatus.Id];
        if(localStatusList.size() == 0) {
            globalStatus.Local_Buy_List_Items__c = false;
            update globalStatus;
        }
    }

    //Delete Independant Buy List
    @AuraEnabled
    public static void deleteIndependantCtrl(String delId) {
        Product_Status__c delStatus = [SELECT Name FROM Product_Status__c WHERE Id =: delId];
        delete delStatus;
    }

    public static void manageThirdPartyDelete(String company, String fundSelector) {
        List<Product_Status__c> buyList = [SELECT Company__c, Fund_Selector__c FROM Product_Status__c WHERE Company__c =: company AND Fund_Selector__c =: fundSelector];
        if(buyList.size() == 0) {
            for(RelatedCompany__c rC : [SELECT Name FROM RelatedCompany__c WHERE Company__c =: company AND ThirdParty__c =: fundSelector]) {
                delete rC;
            }
        }
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