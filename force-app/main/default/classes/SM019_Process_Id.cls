/** 
* @author: Briag Guemard
* @date : Creation 12/04/2017
* @date : Modification 12/04/2017
* @description : ---
*/


public class SM019_Process_Id {
    
     private static String  CLASS_NAME = SM019_Process_Id.class.getName();
    
     public static WSResponseWrapper getProcessStatus(WS006_EtouchesProcess.getProcessID wsProcess){
     	
        String methodName = 'getProcessStatus';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [wsProcess] : ' + wsProcess);
        
        WSResponseWrapper response = new WSResponseWrapper();
       
       List<Process_Id__c> listP = EM025_Process.getListByIndex(new Set<String> {wsProcess.ProcessID});
        
        
        Process_Id__c retounProcess = listP.get(0);
     	
     	
     	
     	  response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
            response.Message = retounProcess.Status__c;
            response.Data = listP;
     
     	return response;
     	
     }
    
}