/*
* Created By : Noor Goolamnabee 
* Description : Controller for the Lightning Web Component lwc_lookupfield_filtercriteria
* Date Created : 05/08/2022
* Test Class : LookUpFilterCriteriaController_TEST
*/
public with sharing class LookUpFilterCriteriaController {
    //- Description: This method returns values of the lookup field
    //- Parameters : 
    //  - objectName : The API name of either the Standard or Custom Object of the Lookup field
    //  - lookUpField : The API name of the Lookup field
    //  - filterCriteriaJSON : The Lookup's filter criteria in the format JSON
    @AuraEnabled(cacheable=true)
    public static List<sObject> getLookUpFieldValues(String lookupObjectAPI, String lookupSearchKey, String additionalField, String dependentFieldQuery, String dependentFieldValue, String contactIdParam){
        //Object list to return
        List<sObject> sObjectRecordList = new List<sObject>(); 
        String initialQuery = '';
        String websiteCountry = '';
        try {
            if(String.isNotBlank(lookupObjectAPI) && String.isNotBlank(lookupSearchKey) && String.isNotBlank(dependentFieldQuery)){
               
                if(String.isNotBlank(additionalField)){
                    initialQuery = 'SELECT Id, Name, ' + additionalField;
                } else {
                    initialQuery = 'SELECT Id, Name';
                }
                if(String.isNotBlank(contactIdParam)){
                    websiteCountry = [SELECT Id, WebsiteCountry__c FROM Contact WHERE Id =: Id.valueOf(contactIdParam)][0].WebsiteCountry__c;
                }
                ///SELECT Id, Fund__c, Fund__r.Id, ISIN_Code__c FROM Share_Class__c WHERE Validity__c = true AND Country__c INCLUDES (:aContactRecord.WebsiteCountry__c)
                String finalQueryBuilt = initialQuery + ' FROM ' + lookupObjectAPI + ' WHERE Name LIKE \'' + String.escapeSingleQuotes('%' + lookupSearchKey + '%') + '\'' + ' ' + dependentFieldQuery +  '\'' + String.escapeSingleQuotes(dependentFieldValue) + '\'' + ' AND Country__c INCLUDES (\'' + websiteCountry + '\')';
                System.debug('//NGO getLookUpFieldValues initialQuery : '+finalQueryBuilt);
                sObjectRecordList = Database.query(finalQueryBuilt);
            } else {
                System.debug('TEST : Parameters : objectName and lookUpField may be BLANK.'); 
            }
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'getLookUpFieldValues');
        }
        return sObjectRecordList;
    }
    
    @AuraEnabled
    public static Map<String, String> getFieldAndObjectPluralLabels(String referencedObjectAPI, String fieldAPI, String lookUpOriginObjectAPI){
        Map<String, String> fieldToObjectPluralLabelsMap = new Map<String, String>();
        try {
            if(String.isNotBlank(referencedObjectAPI) && String.isNotBlank(fieldAPI) && String.isNotBlank(lookUpOriginObjectAPI)){
                //Getting the Lookup Field's label
                Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
                Schema.SObjectType leadSchema = schemaMap.get(referencedObjectAPI);
                Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();
                //Getting the Lookup's Object's Plural label
                List<Schema.DescribeSObjectResult> describeSobjectsResult = Schema.describeSObjects(new List<String>{lookUpOriginObjectAPI});
                //Setting the Map	
                fieldToObjectPluralLabelsMap.put(fieldMap.get(fieldAPI).getDescribe().getLabel(), describeSobjectsResult[0].getLabelPlural());  
            } else {
                System.debug('TEST : getFieldAndObjectPluralLabels : One of the Parameters may be BLANK.');
            }
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'getFieldAndObjectPluralLabels');
        }
        return fieldToObjectPluralLabelsMap;
    }
    
    //START : Utility Methods
    //- Description : This method prints out the error messages from the catch part of the try and catch statement in the above methods
    public static void debugForCatchExceptions(Exception exceptionHandlerParam, String methodName){
        System.debug(methodName + ' : Exception type caught: ' + exceptionHandlerParam.getTypeName());    
        System.debug(methodName + ' : Message: ' + exceptionHandlerParam.getMessage());    
        System.debug(methodName + ' : Line number: ' + exceptionHandlerParam.getLineNumber());    
        System.debug(methodName + ' : Stack trace: ' + exceptionHandlerParam.getStackTraceString());
    }
    //END : Utility Methods
}