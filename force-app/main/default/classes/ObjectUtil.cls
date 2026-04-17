/** 
* @author: Pape DIOUF
* @date : Creation 03/08/2016
* @date : Modification 03/08/2016
* @description : This class contains all the transverse utility methods .
*/
public class ObjectUtil {
    
    private static String CLASS_NAME = 'ObjectUtil';   
    private static String ACCOUNTSERVICE_PROFILENAME = 'Carmignac - Interface';
    public static final Map <String, Schema.SObjectType> schemaMap;
    
    public class Pair {
    	
        public String key {get; set;}
        public String val {get; set;}
    }

    static {
        SchemaMap = Schema.getGlobalDescribe();
    }
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016
     * @description : This method allows to return a list of fields for a given object.
     * @param : String sObjectName This parameter is the name of sObject.
     * @return : List<String> The returned item is a list of the fields sObject parameter.
     */
    public static List<String> getFieldsListFor(String sObjectName) {
        String methodName = 'getFieldsListFor';        
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [sObjectName] : ' + sObjectName);
        Map <String, Schema.SObjectField> fieldMap = schemaMap.get(sObjectName).getDescribe().fields.getMap();
        List<String> fieldsList = new List<String>();
        for (Schema.SObjectField sfield : fieldMap.Values()) {
            Schema.describefieldresult dfield = sfield.getDescribe();
            Pair field = new Pair();
            field.key = dfield.getname();
            fieldsList.add(field.key);
        }        
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [fieldsList] : ' + fieldsList);
        return fieldsList;        
    }
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016 
     * @description : This method allows to return a list of fields for a given object.
     * @param : String sObjectName This parameter is the name of sObject.
     * @return : String The returned item is a string of sObject the parameter fields.
     */
    public static String constructFieldListForQueryFrom(String sObjectName) {
        return constructFilteredFieldListForQueryFrom(sObjectName, '');
    }
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016 
     * @description : This method used to return all fields EXCEPT those ending with a specified extension.
     * @param : String sObjectName This parameter is the name of sObject.
     * @param : String notEndingFilter Ce paramètre spécifie l'extension du nom api des champs à omettre.
     * @return : String The returned item is a string of sObject the parameter fields.
     */
    public static String constructFilteredFieldListForQueryFrom(String sObjectName, String notEndingFilter) {
        String methodName = 'constructFilteredFieldListForQueryFrom';
        
        List<String> fieldsList = getFieldsListFor(sObjectName);
        String fieldsQuery = ' ';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [fieldsList] : ' + fieldsList);
        for (String field : fieldsList) {
            if (String.isEmpty(notEndingFilter) || !field.endsWith(notEndingFilter) ){
                fieldsQuery = fieldsQuery + '' + field + ',';
            }
        }

        return fieldsQuery.replace(fieldsQuery, fieldsQuery.substring(0, fieldsQuery.length() - 1) + ' ');
    }    
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016
     * @description : This method provides the debug log some information in early method.
     * @param : String className This parameter is the name of the Apex class.
     * @param : String methodName This parameter is the name of the Apex method.
     * @param : String message This parameter represents the information to appear in the debug log.
     * @return : N/A
     */
     public static void debugLogBegin(String className, String methodName, String message){
        system.debug('### >> BEGIN ['+className+'] ['+methodName+'] [MESSAGE] : ' + message);         
     }  
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016 
     * @description : This method provides the debug log on certain information to the method.
     * @param : String className This parameter is the name of the Apex class.
     * @param : String methodName This parameter is the name of the Apex method.
     * @param : String message This parameter represents the information to appear in the debug log.
     * @return : N/A
     */
     public static void debugLogEnd(String className, String methodName, String message){
        system.debug('### >> END ['+className+'] ['+methodName+'] [MESSAGE] : ' + message);
     }
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 16/08/2016
     * @date : Modification 16/08/2016
     * @description : This method provides the debug log some information in method.
     * @param : String className This parameter is the name of the Apex class.
     * @param : String methodName This parameter is the name of the Apex method.
     * @param : String message This parameter represents the information to appear in the debug log.
     * @return : N/A
     */
     public static void debugLog(String className, String methodName, String message){
        system.debug('### >> LOG ['+className+'] ['+methodName+'] [MESSAGE] : ' + message);
     }
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016 
     * @description : his method provides picklist values.
     * @param : String sObjectAPI This parameter is the API name of the object.
     * @param : String Field This parameter is the name of the picklist field of the object.
     * @return : List<String> The returned element is a character string list containing all the values of picklist.
     */     
     public static List<String> getPicklistValues(String sObjectAPI, String Field){ 
        
             List<String> lstPickvals=new List<String>();
             Schema.sObjectType sobject_type = Schema.getGlobalDescribe().get(sObjectAPI).newSObject().getSObjectType(); 
             Map<String, Schema.SObjectField> field_map = sobject_type.getDescribe().fields.getMap();
             List<Schema.PicklistEntry> pick_list_values = field_map.get(Field).getDescribe().getPickListValues(); 
             for (Schema.PicklistEntry a : pick_list_values) { 
                  lstPickvals.add(a.getValue());
             }
             return lstPickvals;
     } 
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 03/08/2016
     * @date : Modification 03/08/2016
     * @description : This method provides the id of the record type from the name of the record type.
     * @param : String objectName This parameter is the API name of the object.
     * @param : String recordtypeName This parameter is the name of the recording of the object type.
     * @return : Id The returned element is the identifier of the record type.
     */
    public static Id getRecordTypeId(String objectName, String recordtypeName){
        return schemaMap.get(objectName).getDescribe().getRecordTypeInfosByName().get(recordtypeName).getRecordTypeId();
    }
    
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 08/08/2016
     * @date : Modification 08/08/2016 
     * @description : This method checks if a string value is empty.
     * @param : sObject value This parameter is the value to evaluate.
     * @return : Boolean True if the value is empty or null
     */
     public static Boolean isEmpty(sObject value){
        return (value == null);
     }
    
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 08/08/2016
     * @date : Modification 08/08/2016 
     * @description : This method checks if a string value is empty.
     * @param : Boolean value This parameter is the value to evaluate.
     * @return : Boolean True if the value is empty or null
     */
     public static Boolean isEmpty(Boolean value){
        return (value == null);
     }
    
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 08/08/2016
     * @date : Modification 08/08/2016 
     * @description : This method checks if a string value is empty.
     * @param : String stringValue This parameter is the name of the Apex class.
     * @return : Boolean True if the string is empty or null
     */
     public static Boolean isEmpty(String stringValue){
        return (stringValue == null || stringValue == '');
     }
    
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 12/08/2016
     * @date : Modification 12/08/2016 
     * @description : This method insert records in Database.
     * @param : List<SObject> records This parameter is the records to insert.
     * @return : N/A
     */
     public static void insertRecords(List<SObject> records){
        insert records;
     }
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 12/08/2016
     * @date : Modification 12/08/2016 
     * @description : This method update existing records in Database.
     * @param : List<SObject> records This parameter is the records to update.
     * @return : N/A
     */
     public static void updateRecords(List<SObject> records){
        update records;
     }
    
    
    /**
     * @auteur : Pape DIOUF
     * @date : Creation 17/08/2016
     * @date : Modification 17/08/2016 
     * @description : This method delete existing records in Database.
     * @param : List<SObject> records This parameter is the records to delete.
     * @return : N/A
     */
     public static void deleteRecords(List<SObject> records){
        delete records;
     }
     
     
     /**
     * @auteur : Pape DIOUF
     * @date : Creation 09/09/2016
     * @date : Modification 09/09/2016 
     * @description : This method check if the current user is an service account user (Interface).
     * @return : Boolean (Yes or No)
     */
     public static Boolean isAccountServiceUser(){
        Boolean retValue;
        //Id profileId = UserInfos.;
        Profile prof = [SELECT Id, Name FROM Profile WHERE Id=:UserInfo.getProfileId()  LIMIT 1]; 
        return prof.Name == ACCOUNTSERVICE_PROFILENAME;
        //return retValue;
     }
     
     public static Profile getProfile(){
        Profile prof = [SELECT Id, Name FROM Profile WHERE UserType='Standard' LIMIT 1]; 
        return prof;
     }    
    
     public static Profile getSimpleCarmignacProfile(){
        Profile prof = [SELECT Id FROM Profile WHERE Name='Carmignac - Standard User' LIMIT 1]; 
        return prof;
    }
    
    public static Profile getSimpleCarmignacCRMProfile(){
        Profile prof = [SELECT Id FROM Profile WHERE Name='Carmignac - CRM' LIMIT 1]; 
        return prof;
    }
    
    public static Profile getSimpleCarmignacContributorProfile(){
        Profile prof = [SELECT Id FROM Profile WHERE Name='Carmignac - Contributor' LIMIT 1]; 
        return prof;
    }
	
    public static Profile getSimpleCarmignacCampaignAutomationProfile(){
        Profile prof = [SELECT Id FROM Profile WHERE Name='Carmignac - Campaign Automation' LIMIT 1]; 
        return prof;
    }
    
    public static Profile getSimpleCarmignacBusinessDeveloperProfile(){
        Profile prof = [SELECT Id FROM Profile WHERE Name='Carmignac - Business Developer' LIMIT 1]; 
        return prof;
    }
    
     /**
     * @auteur : Pape DIOUF
     * @date : Creation 09/09/2016
     * @date : Modification 09/09/2016 
     * @description : This method return the Webservice Parameters By Name.
     * @param : String paramName This parameter is the Name of the Custom setting.
     * @return : Boolean (Yes or No)
     */
     public static WebserviceParameters__c getWebserviceParametersByName(String paramName){
     	return WebserviceParameters__c.getAll().get(paramName);
     }
    
    public static EM023_Log.errorToLog GetErrorToLog(HttpResponse response, HttpRequest request,String recordData,String className,String methodName){
        //Interface Log        	 	
    		String fullResp = ' - Response: ' + response + 
    		' / Response body: ' + response.getBody()+
    		' / Response getStatus: ' + response.getStatus()+
    		' / Response getStatusCode: ' + response.getStatusCode();        	
        	
        	String fullReq ='';
        
        	if(request!= null)
        	{
            	fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
        		' / Request header accept   : ' + request.getHeader('accept')+
        		' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
        		' / Request string   : ' + request + 
        		' / Request  body: ' + request.getBody();  
        	}
        	
        	String data = 'Class name :' + className + ' Methodname : '
        	 + methodName + recordData
        	+ fullReq ;          	
        	
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName = className + ' ' + methodName;
        	newErro.Data = data;
        	newErro.error = fullResp;
        
        return newErro;
    }

	/**
     * @auteur : Fabien BRACONNIER
     * @date : Creation 05/02/2019
     * @date : Modification 05/02/2019 
     * @description : This method return a list of value for the field TECH_WhichWebService__c in Contact.
     * @return : List<String>
     */
    public static String getTECH_WhichWebService_Values(){
		String listValues;
        return listValues = '(\''+'OnBeforeUpdate_CallCreate'+'\', ' + '\''+'OnBeforeInsert_CallCreate'+'\', ' + '\''+'OnBeforeUpdate_CallDesactivate'+'\', ' + '\''+'OnBeforeUpdate_CallUpdate'+'\', ' + '\''+'OnBeforeDelete_CallDelete'+'\')';
    }
    
   /**
    * @author Abderrahmane TRIA
    * @date Creation 21/04/2020
    * @description bypass Trigger
    */
    public static string bypassTrigger;
    static{
        Set<Id> usersIds = new Set<Id>{UserInfo.getUserId()};
            Map<Id,User> mapUsers = EM030_User.getUsers(usersIds);
        user u =mapUsers.get(UserInfo.getUserId());
        bypassTrigger = ';' + u.BypassApexTriggers__c + ';';
    }
    
   /**
    * @author Abderrahmane TRIA
    * @date Creation 08/04/2020
    * @description Get Picklist Map of Labels by Value (API NAME)
    */
    public static Map<String,String> getPickListMapValues(String objectName, String fieldName){
        system.debug(objectName+'  '+fieldName);
        Map<String,String> pickListValuesMap= new Map<String,String>();
        Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            pickListValuesMap.put(pickListVal.getValue(),pickListVal.getLabel());
        }
        return pickListValuesMap;
    }
}