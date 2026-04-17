/**
* ---------------------------------------------------------------------------------------------------------------------------------------------------
* @Name			GenericRalatedListDisplayCtr	
* @Author		Slimene BELHAJ ALI
* @Version		v1.0
* @CreatedDate	26/03/2018
* @UsedBy		Lightning component GenericRelatedList
* @TestClass    GenericRalatedListDisplayCtr_Test	
* ---------------------------------------------------------------------------------------------------------------------------------------------------	
* @Description
* Generate data table with the columns
* ---------------------------------------------------------------------------------------------------------------------------------------------------	
**/
public without sharing class GenericRalatedListCtrl {
    
    /**
	* @Method: loadDataFromConfig
	* @Description: This method load data and columns and data
	* @param fieldSetName: field Set Name
	* @param whereClause: wher eClause
	* @param objectName: object Name
	* @param parentName: parent Name
	* @param recordId: parent Id
	* @return Map: contains data and columns list
	*/
    
    @AuraEnabled 
    public static Map<String, Object> loadDataFromConfig(String fieldSetName, String typeFieldSource, String whereClause, String objectName, String parentName, String recordId, String sObjectType, String recordIdOverride, String sortBy) {
        
		System.debug('CTS Variables 1' + fieldSetName + ' 2' + typeFieldSource + ' 3' + whereClause + ' 4' + objectName + ' 5' + parentName + ' 6' + recordId + ' 7' + sObjectType + ' 8' + recordIdOverride);

        Object recordIdOverrideVal = '';
        if(recordIdOverride!=''&&recordIdOverride!=null) {
            List<SObject> data = Database.query(buildQuery(recordIdOverride, typeFieldSource, '', sObjectType, 'Id', recordId, sortBy, true));
            for(SObject record : data) {
                recordIdOverrideVal = record.get(recordIdOverride);
                recordId = recordIdOverrideVal.toString();
            }
        }

        Map<String, Object> globalResult = new Map<String, Object>(); 
        //load data by generic query
        List<SObject> data = Database.query(buildQuery(fieldSetName, typeFieldSource, whereClause, objectName, parentName, recordId, sortBy, false));
        List<SObject> allData = Database.query(buildQuery(fieldSetName, typeFieldSource, whereClause, objectName, parentName, recordId, sortBy, false));
        List<Id> dataIdList = extractIdFromSObject(data);
        List<Id> allDataIdList = extractIdFromSObject(allData);
        globalResult.put('editAccess', loadPermissionRecord(dataIdList, 'HasEditAccess'));
        globalResult.put('deleteAccess', loadPermissionRecord(dataIdList, 'HasDeleteAccess'));
        globalResult.put('allEditAccess', loadPermissionRecord(allDataIdList, 'HasEditAccess'));
        globalResult.put('allDeleteAccess', loadPermissionRecord(allDataIdList, 'HasDeleteAccess'));
        globalResult.put('data', data);
        globalResult.put('allData', allData);
        
        if(sObjectType=='Account_Plan__c') {
	        globalResult.put('hasSubs', loadSubItems(allDataIdList));
        } else {
	        globalResult.put('hasSubs', false);
        }
        
        //load columns
        globalResult.put('columns', getColumnsFormat(fieldSetName, typeFieldSource, ObjectName));
        //retun map data + column
        return globalResult;
    }
    
    
    /**
	* @Method: buildQuery
	* @Description: This method build query
	* @param fieldSetName: field Set Name
	* @param whereClause: wher eClause
	* @param objectName: object Name
	* @param parentName: parent Name
	* @param recordId: parent Id
	* @return String: return query
	*/
    private static string buildQuery(String fieldSetName, String typeFieldSource, String whereClause, String objectName, String parentName, String recordId, String sortBy, Boolean noNameReturn){
        //generate query from method parameters.
        String query = 'select ';
        if(noNameReturn) {
            query = query + fieldSetName;
        } else {
	        query = query + readFieldSet(fieldSetName,typeFieldSource, objectName);
        }
        query = query + ' from  ' + objectName + ' where '+((whereClause == null ||  whereClause.trim() == '' )? '' : ('(' + whereClause + ') and ')) + parentName + ' = \'' + recordId + '\'';
		if(sortBy != null && sortBy != '')
	        query = query + ' ORDER BY ' + sortBy;
	
        System.debug('@@@ Query ' +query);
    	return query;
    }
    
    
    /**
	* @Method: readFieldSet
	* @Description: This method read field set
	* @param fieldSetName: field Set Name
	* @param ObjectName: Object Name
	* @return String: return fild list
	*/
    private static String readFieldSet(String fieldSetName,String typeFieldSource, String ObjectName) {
        String resultField = '';
        //load all SObject fields
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(ObjectName).getDescribe().fields.getMap();
         if(typeFieldSource == 'Field Set') {
        //load all field set members by object name and field set name
            for(Schema.FieldSetMember item : Schema.getGlobalDescribe().get(ObjectName).getDescribe().FieldSets.getMap().get(fieldSetName).getFields()) {
                //if field is a relationsip field
                if(fieldMap.get(item.getFieldPath()).getDescribe().getRelationshipName() != null) {
                    //load relationship name
                    resultField +=fieldMap.get(item.getFieldPath()).getDescribe().getRelationshipName() + '.Name,';
                    continue;
                }
                //Load field set member
                resultField +=item.getFieldPath() + ',';
            }
         }else {
         	fieldMap = toLowerCaseMapFields(fieldMap);
            for(String item : fieldSetName.split(',')){
            	item = item.trim().toLowerCase();
            	System.debug('@@ item ' + item);
                 if(fieldMap.get(item).getDescribe().getRelationshipName() != null) {
                    //load relationship name
                    resultField +=fieldMap.get(item).getDescribe().getRelationshipName() + '.Name,';
                    continue;
                }
                //Load field set member
                resultField +=item + ',';
            }
        }
        return resultField.removeEnd(',');
    } 
    
    /**
	* @Method: getColumnsFormat
	* @Description: This method generate columns list
	* @param fieldSetName: field Set Name
	* @param ObjectName: Object Name
	* @return String: return column list
	*/
    private static List<ColumnWrapper> getColumnsFormat(String fieldSetName, String typeFieldSource, String ObjectName) {
        List<ColumnWrapper> columnList = new List<ColumnWrapper>();
        //load all SObject fields
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(ObjectName).getDescribe().fields.getMap();
       
        if(typeFieldSource == 'Field Set') {
            //load all field set members by object name and field set name
            for(Schema.FieldSetMember item : Schema.getGlobalDescribe().get(ObjectName).getDescribe().FieldSets.getMap().get(fieldSetName).getFields()) {
                //build columnWrapper and add if in result value
                columnList.add(new ColumnWrapper(item.getLabel(), item.getFieldPath(), getType(item.getType()), fieldMap.get(item.getFieldPath()).getDescribe()));
            }
        } else {
        	fieldMap = toLowerCaseMapFields(fieldMap);
            for(String item : fieldSetName.split(',')){
            	item = item.trim().toLowerCase();
                Schema.DescribeFieldResult currentDesc = fieldMap.get(item).getDescribe();
                 columnList.add(new ColumnWrapper(currentDesc.getLabel(), currentDesc.getName(),getType(currentDesc.getType()),currentDesc));
            }
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
    
    /**
	* @Method: getType
	* @Description: This method return string type
	* @param fielddataType: display type
	* @return String: retun string type
	*/
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
    
    /**
	* @Method: loadPermissionRecord
	* @Description: This method return permission for current user
	* @param recordIdList: record Id List
	* @param permissionField: permission edit or delete
	* @return List<Id>: retun list Id for records that we have access
	*/
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
    
    private static List<String> loadSubItems(List<Id> recordIdList) {
        List<String> result = new List<String>();
        List<Task> allTasks = [SELECT Status, WhatId FROM Task WHERE WhatId IN: recordIdList];
        Map<Id, List<Task>> taskMap = new Map<Id, List<Task>>();
        for(Task t : allTasks) {
            if (taskMap.containsKey(t.WhatId)){
                taskMap.get(t.WhatId).add(t);
            }
            else{
                taskMap.put(t.WhatId, new List <Task>{ t });
            }
        }
        for(Id recordId : recordIdList) {
            String thisResult;
            if(taskMap.get(recordId)!=null){
                thisResult = 'Done';
                for(Task t : taskMap.get(recordId)){
                    if(t.Status != 'Done') {
                        thisResult = 'Not Done';
                    }
                }
            } else {
                thisResult = 'Empty';
            }
            result.add(thisResult);
        }
        return result;
    }
    
    /**
	* @Method: extractIdFromSObject
	* @Description: This method extract list Id from objectList
	* @param sobjectList: list sobject
	* @return List<Id>: retun list Id for records
	*/
    private static List<Id> extractIdFromSObject(List<SObject> sobjectList) {
        List<Id> listId = new List<Id>();
        if(sobjectList == null ||sobjectList.size() == 0) {
            return listId;
        }
        
        for(SObject item : sobjectList) {
            listId.add(item.Id);
        }
        
        return listId;
    }
    
    /**
	* @Method: deleteRecord
	* @Description: This method delete record
	* @param recordId: record Id
	* @param objectName: object name
	*/
    @AuraEnabled 
    public static void deleteRecord(String recordId, String objectName) {
        
    	SObject currentObject = Database.query('select Id from ' + objectName + ' where Id = :recordId');

		if(objectName=='AccountPartner')
			 currentObject = Database.query('select Id from ' + 'Partner' + ' where Id = :recordId');

        if(objectName=='Product_Status__c') {
            Product_Status__c buyListItem = [SELECT Company__c, Fund_Selector__c FROM Product_Status__c WHERE Id =: recordId];
            List<Product_Status__c> buyList = [SELECT Company__c, Fund_Selector__c FROM Product_Status__c WHERE Company__c =: buyListItem.Company__c AND Fund_Selector__c =: buyListItem.Fund_Selector__c];
            if(buyList.size() == 1) {
                for(RelatedCompany__c rC : [SELECT Name FROM RelatedCompany__c WHERE Company__c =: buyListItem.Company__c AND ThirdParty__c =: buyListItem.Fund_Selector__c]) {
                    delete rC;
                }
            }
        }
        delete currentObject;
    	
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
        /**
	* @Constructor: ColumnWrapper
	* @Description: This Constructor initialize data.
	* @param label: label
	* @param fieldName:fiel dName
	* @param type: type
	* @param fieldDescription: field Description
	*/
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
}