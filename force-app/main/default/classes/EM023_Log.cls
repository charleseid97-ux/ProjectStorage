/** 
* @author: Briag GUEMARD
* @date : Creation 05/04/2017
* @date : Modification 05/04/2017
* @description : this Class allow to manage Log entity data preparation .
*/

public class EM023_Log {
	
	
	private static String CLASS_NAME = 'EM023_Log';

	
	public class errorToLog{
    	public datetime dateCreate;
    	public String interfaceName;
    	public String Data;
    	public String error;
    }
    
    public static void insertLogError(list<EM023_Log.errorToLog> listToInsert){
		
		
		String methodName = 'insertLogError';
		list<Interface_Log__c> newListLog = new list<Interface_Log__c>();
		
		for (EM023_Log.errorToLog inputItem :listToInsert ){
			
			
			Interface_Log__c temp = new Interface_Log__c();
			
			 temp.Interface_Name__c = inputItem.interfaceName;
			 temp.Error__c = inputItem.error;
			 temp.Data__c = inputItem.Data;
			 temp.Date_Log__c = inputItem.dateCreate;
			 
			 newListLog.add(temp);
			
			
		}
		
		if (newListLog != null && newListLog.size()>0)
		{
			insert newListLog;
		}
		
		
		
		ObjectUtil.debugLog(CLASS_NAME, methodName, '[listToInsert]' +  listToInsert );
		
		//insert newLog;
		
		
	}
     public static void insertLogErrorScan(list<EM023_Log.errorToLog> listToInsert,String processID){
		
		
		String methodName = 'insertLogErrorScan';
		list<Interface_Log__c> newListLog = new list<Interface_Log__c>();
		
		for (EM023_Log.errorToLog inputItem :listToInsert ){
			
			
			
			Interface_Log__c temp = new Interface_Log__c();
			
			 temp.Interface_Name__c = inputItem.interfaceName;
			 temp.Error__c = inputItem.error;
			 temp.Data__c = inputItem.Data;
			 temp.Date_Log__c = inputItem.dateCreate;
			 temp.Process_Id__c= processID;
			 newListLog.add(temp);
			
			
		}
		
		if (newListLog != null && newListLog.size()>0)
		{
			insert newListLog;
		}
		
		
		
		ObjectUtil.debugLog(CLASS_NAME, methodName, '[listToInsert]' +  listToInsert );
		
		//insert newLog;
		
		
	}
	
	public static List<Interface_Log__c> getAllErrorLogFromProcess(String processID){
		
		
		String methodName = 'insertLogErrorScan';
		list<Interface_Log__c> 	returnList = new list<Interface_Log__c>();
		
		returnList = DM027_InterfaceLog.getListByProcessId( new Set<String>  {processID});
		
		
		return 	returnList;
		
	}
	
	
		
    
}